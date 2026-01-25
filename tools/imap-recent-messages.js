#!/usr/bin/env node
/**
 * IMAP Recent Messages - Show most recent emails
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

const imap = new Imap(config);

function openBox(boxName) {
  return new Promise((resolve, reject) => {
    imap.openBox(boxName, true, (err, box) => {
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
  // Basic decode of =?UTF-8?B?...?= and =?UTF-8?Q?...?=
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
        const box = await openBox('INBOX');
        console.log(`INBOX: ${box.messages.total} total messages\n`);

        // Get all UIDs and take the last 5
        const allUids = await search(['ALL']);
        const recentUids = allUids.slice(-5).reverse(); // Last 5, newest first

        console.log('='.repeat(80));
        console.log('5 MOST RECENT MESSAGES');
        console.log('='.repeat(80));

        const messages = await fetchMessages(recentUids);

        // Sort by UID descending (newest first)
        messages.sort((a, b) => b.uid - a.uid);

        let count = 1;
        for (const msg of messages) {
          const headers = parseHeaders(msg.headers);
          const subject = decodeSubject(headers.subject);
          const from = headers.from || '(Unknown)';
          const date = headers.date || '(No Date)';

          console.log(`\n${count}. ${date}`);
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
