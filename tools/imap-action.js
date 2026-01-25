#!/usr/bin/env node
const Imap = require('imap');

const config = {
  user: 'info@martiendejong.nl',
  password: 'hLPFy6MdUnfEDbYTwXps',
  host: 'mail.zxcs.nl',
  port: 993,
  tls: true,
  tlsOptions: { rejectUnauthorized: false },
  authTimeout: 30000,
  connTimeout: 30000
};

// Parse arguments
const spamUids = [];
const archiveUids = [];
let offset = 15;

for (let i = 2; i < process.argv.length; i++) {
  const arg = process.argv[i];
  if (arg.startsWith('--spam=')) {
    spamUids.push(...arg.split('=')[1].split(',').map(Number));
  } else if (arg.startsWith('--archive=')) {
    archiveUids.push(...arg.split('=')[1].split(',').map(Number));
  } else if (arg.startsWith('--offset=')) {
    offset = parseInt(arg.split('=')[1]);
  }
}

const imap = new Imap(config);

function decodeStr(str) {
  if (!str) return '';
  return str.replace(/=\?([^?]+)\?([BQ])\?([^?]+)\?=/gi, (match, charset, encoding, text) => {
    try {
      if (encoding.toUpperCase() === 'B') {
        return Buffer.from(text, 'base64').toString('utf8');
      } else if (encoding.toUpperCase() === 'Q') {
        return text.replace(/_/g, ' ').replace(/=([0-9A-F]{2})/gi, (m, hex) =>
          String.fromCharCode(parseInt(hex, 16))
        );
      }
    } catch (e) { return text; }
    return text;
  });
}

function move(uids, folder) {
  return new Promise((resolve, reject) => {
    if (!uids || uids.length === 0) return resolve(0);
    imap.move(uids, folder, (err) => {
      if (err) reject(err);
      else resolve(uids.length);
    });
  });
}

imap.once('ready', async () => {
  imap.openBox('INBOX', false, async (err, box) => {
    if (err) throw err;

    try {
      if (spamUids.length > 0) {
        console.log(`Moving to Spam: ${spamUids.join(', ')}`);
        await move(spamUids, 'Spam');
        console.log('Done.');
      }

      if (archiveUids.length > 0) {
        console.log(`Moving to Archive: ${archiveUids.join(', ')}`);
        await move(archiveUids, 'Archive');
        console.log('Done.');
      }

      // Show next 5
      imap.search(['ALL'], (err, uids) => {
        if (err) throw err;

        const start = offset + 5;
        const end = offset;
        const next5 = uids.slice(-(start), -(end) || undefined).reverse();

        console.log('\n' + '='.repeat(70));
        console.log(`MESSAGES ${offset + 1}-${offset + 5}`);
        console.log('='.repeat(70));

        if (next5.length === 0) {
          console.log('No more messages.');
          imap.end();
          return;
        }

        const fetch = imap.fetch(next5, { bodies: 'HEADER.FIELDS (FROM SUBJECT DATE)' });
        const messages = [];

        fetch.on('message', (msg) => {
          let uid, headers = '';
          msg.on('body', (stream) => {
            stream.on('data', (chunk) => { headers += chunk.toString(); });
          });
          msg.once('attributes', (attrs) => { uid = attrs.uid; });
          msg.once('end', () => { messages.push({ uid, headers }); });
        });

        fetch.once('end', () => {
          messages.sort((a, b) => b.uid - a.uid);
          let count = offset + 1;
          for (const msg of messages) {
            const from = decodeStr(msg.headers.match(/From: (.+)/i)?.[1] || '(Unknown)');
            const subject = decodeStr(msg.headers.match(/Subject: (.+)/i)?.[1] || '(No Subject)');
            const date = msg.headers.match(/Date: (.+)/i)?.[1] || '(No Date)';
            console.log(`\n${count}. [UID:${msg.uid}] ${date}`);
            console.log(`   From: ${from}`);
            console.log(`   Subject: ${subject}`);
            console.log('-'.repeat(60));
            count++;
          }
          imap.end();
        });
      });
    } catch (e) {
      console.error('Error:', e.message);
      imap.end();
    }
  });
});

imap.once('error', (err) => console.error(err));
imap.once('end', () => console.log('\nConnection closed.'));
imap.connect();
