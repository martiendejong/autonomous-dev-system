#!/usr/bin/env node
/**
 * Get detailed email information by UID from specific folder
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

const folder = process.argv[2];
const uid = process.argv[3];

if (!folder || !uid) {
  console.error('Usage: node email-details-folder.js <folder> <uid>');
  process.exit(1);
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

imap.once('ready', () => {
  imap.openBox(folder, true, (err, box) => {
    if (err) {
      console.error('Error opening folder:', err.message);
      imap.end();
      return;
    }

    const fetch = imap.fetch(uid, {
      bodies: ['HEADER.FIELDS (FROM TO SUBJECT DATE)', 'TEXT'],
      struct: true
    });

    fetch.on('message', (msg) => {
      let headers = {};
      let body = '';

      msg.on('body', (stream, info) => {
        let buffer = '';
        stream.on('data', (chunk) => {
          buffer += chunk.toString('utf8');
        });
        stream.once('end', () => {
          if (info.which.includes('HEADER')) {
            const lines = buffer.split('\r\n');
            lines.forEach(line => {
              const match = line.match(/^([^:]+):\s*(.+)$/);
              if (match) {
                const key = match[1].toLowerCase();
                const value = decodeStr(match[2]);
                headers[key] = value;
              }
            });
          } else {
            body = buffer;
          }
        });
      });

      msg.once('end', () => {
        console.log('\n=== EMAIL DETAILS ===\n');
        console.log('Folder:', folder);
        console.log('UID:', uid);
        console.log('From:', headers.from || 'N/A');
        console.log('To:', headers.to || 'N/A');
        console.log('Subject:', headers.subject || 'N/A');
        console.log('Date:', headers.date || 'N/A');
        console.log('\n=== BODY ===\n');
        console.log(body.substring(0, 5000)); // First 5000 chars
        if (body.length > 5000) {
          console.log('\n... (truncated, total length:', body.length, 'chars)');
        }
      });
    });

    fetch.once('error', (err) => {
      console.error('Fetch error:', err);
      imap.end();
    });

    fetch.once('end', () => {
      imap.end();
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
