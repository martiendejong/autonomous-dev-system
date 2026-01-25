#!/usr/bin/env node
/**
 * List recent emails from a specific folder
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

const folder = process.argv[2] || 'INBOX';
const count = parseInt(process.argv[3]) || 20;

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

imap.once('ready', () => {
  imap.openBox(folder, true, (err, box) => {
    if (err) {
      console.error('Error opening folder:', err.message);
      imap.end();
      return;
    }

    console.log(`\n=== ${folder} (${box.messages.total} total messages) ===\n`);

    if (box.messages.total === 0) {
      console.log('No messages in folder');
      imap.end();
      return;
    }

    // Get recent messages
    const since = new Date();
    since.setDate(since.getDate() - 7);

    imap.search([['SINCE', since]], (err, results) => {
      if (err) {
        console.error('Search error:', err.message);
        imap.end();
        return;
      }

      if (!results || results.length === 0) {
        console.log('No messages in the last 7 days');
        imap.end();
        return;
      }

      // Get most recent N messages
      const messagesToFetch = results.slice(-count);

      const fetch = imap.fetch(messagesToFetch, {
        bodies: 'HEADER.FIELDS (FROM TO SUBJECT DATE)',
        struct: true
      });

      let messages = [];

      fetch.on('message', (msg, seqno) => {
        let uid = null;
        let headers = {};

        msg.on('attributes', (attrs) => {
          uid = attrs.uid;
        });

        msg.on('body', (stream, info) => {
          let buffer = '';
          stream.on('data', (chunk) => {
            buffer += chunk.toString('utf8');
          });
          stream.once('end', () => {
            const lines = buffer.split('\r\n');
            lines.forEach(line => {
              const match = line.match(/^([^:]+):\s*(.+)$/);
              if (match) {
                const key = match[1].toLowerCase();
                const value = decodeStr(match[2]);
                headers[key] = value;
              }
            });
          });
        });

        msg.once('end', () => {
          messages.push({
            uid: uid,
            from: headers.from || 'N/A',
            subject: headers.subject || 'N/A',
            date: headers.date || 'N/A'
          });
        });
      });

      fetch.once('error', (err) => {
        console.error('Fetch error:', err);
        imap.end();
      });

      fetch.once('end', () => {
        // Sort by UID (newest first)
        messages.sort((a, b) => b.uid - a.uid);

        messages.forEach(msg => {
          console.log(`[UID:${msg.uid}]`);
          console.log(`  From: ${msg.from}`);
          console.log(`  Subject: ${msg.subject}`);
          console.log(`  Date: ${msg.date}`);
          console.log('');
        });

        imap.end();
      });
    });
  });
});

imap.once('error', (err) => {
  console.error('IMAP error:', err);
});

imap.once('end', () => {
  // Connection ended
});

imap.connect();
