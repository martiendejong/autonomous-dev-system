#!/usr/bin/env node
/**
 * IMAP Manager - Move messages and show more
 */

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

// UIDs to move to spam (from previous query - LinkedIn, ov-chipkaart, 2x Coinbase phishing)
const uidsToSpam = process.argv.slice(2).map(Number).filter(n => n > 0);

const imap = new Imap(config);

function openBox(boxName, readOnly = false) {
  return new Promise((resolve, reject) => {
    imap.openBox(boxName, readOnly, (err, box) => {
      if (err) reject(err);
      else resolve(box);
    });
  });
}

function search(criteria) {
  return new Promise((resolve, reject) => {
    imap.search(criteria, (err, results) => {
      if (err) reject(err);
      else resolve(results);
    });
  });
}

function moveMessages(uids, folder) {
  return new Promise((resolve, reject) => {
    if (!uids || uids.length === 0) {
      resolve(0);
      return;
    }
    imap.move(uids, folder, (err) => {
      if (err) reject(err);
      else resolve(uids.length);
    });
  });
}

function fetchMessages(uids) {
  return new Promise((resolve, reject) => {
    if (!uids || uids.length === 0) {
      resolve([]);
      return;
    }

    const messages = [];
    const fetch = imap.fetch(uids, { bodies: 'HEADER.FIELDS (FROM TO SUBJECT DATE)', struct: true });

    fetch.on('message', (msg, seqno) => {
      let uid = null;
      let headers = '';

      msg.on('body', (stream) => {
        stream.on('data', (chunk) => {
          headers += chunk.toString('utf8');
        });
      });

      msg.once('attributes', (attrs) => {
        uid = attrs.uid;
      });

      msg.once('end', () => {
        messages.push({ uid, headers });
      });
    });

    fetch.once('error', reject);
    fetch.once('end', () => resolve(messages));
  });
}

function parseHeaders(headerStr) {
  const result = {};
  const lines = headerStr.split(/\r?\n/);
  let currentHeader = '';
  let currentValue = '';

  for (const line of lines) {
    if (line.match(/^\s+/)) {
      currentValue += ' ' + line.trim();
    } else {
      if (currentHeader) {
        result[currentHeader.toLowerCase()] = currentValue;
      }
      const match = line.match(/^([^:]+):\s*(.*)$/);
      if (match) {
        currentHeader = match[1];
        currentValue = match[2];
      }
    }
  }
  if (currentHeader) {
    result[currentHeader.toLowerCase()] = currentValue;
  }

  return result;
}

function decodeSubject(subject) {
  if (!subject) return '(No Subject)';

  return subject.replace(/=\?([^?]+)\?([BQ])\?([^?]+)\?=/gi, (match, charset, encoding, text) => {
    try {
      if (encoding.toUpperCase() === 'B') {
        return Buffer.from(text, 'base64').toString('utf8');
      } else if (encoding.toUpperCase() === 'Q') {
        return text.replace(/_/g, ' ').replace(/=([0-9A-F]{2})/gi, (m, hex) =>
          String.fromCharCode(parseInt(hex, 16))
        );
      }
    } catch (e) {
      return text;
    }
    return text;
  });
}

async function main() {
  console.log('Connecting to IMAP server...');

  return new Promise((resolve, reject) => {
    imap.once('ready', async () => {
      console.log('Connected!\n');
      try {
        // Open INBOX with write access
        const box = await openBox('INBOX', false);

        // Move messages to spam if specified
        if (uidsToSpam.length > 0) {
          console.log(`Moving ${uidsToSpam.length} messages to Spam...`);
          console.log(`UIDs: ${uidsToSpam.join(', ')}`);
          const moved = await moveMessages(uidsToSpam, 'Spam');
          console.log(`Moved ${moved} messages to Spam.\n`);
        }

        // Get messages 6-10 (next 5 after the first 5)
        const allUids = await search(['ALL']);
        // Skip last 5, take next 5
        const nextUids = allUids.slice(-10, -5).reverse();

        console.log('='.repeat(80));
        console.log('MESSAGES 6-10 (Next 5)');
        console.log('='.repeat(80));

        const messages = await fetchMessages(nextUids);
        messages.sort((a, b) => b.uid - a.uid);

        let count = 6;
        for (const msg of messages) {
          const headers = parseHeaders(msg.headers);
          const subject = decodeSubject(headers.subject);
          const from = headers.from || '(Unknown)';
          const date = headers.date || '(No Date)';

          console.log(`\n${count}. [UID:${msg.uid}] ${date}`);
          console.log(`   From: ${from}`);
          console.log(`   Subject: ${subject}`);
          console.log('-'.repeat(60));
          count++;
        }

        imap.end();
        resolve();
      } catch (err) {
        console.error('Error:', err.message);
        imap.end();
        reject(err);
      }
    });

    imap.once('error', (err) => {
      console.error('Connection error:', err.message);
      reject(err);
    });

    imap.once('end', () => {
      console.log('\nConnection closed.');
    });

    imap.connect();
  });
}

main().catch(console.error);
