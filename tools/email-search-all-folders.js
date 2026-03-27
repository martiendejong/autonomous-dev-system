#!/usr/bin/env node
/**
 * Search for emails across all folders
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

const searchTerms = process.argv.slice(2);
if (searchTerms.length === 0) {
  console.error('Usage: node email-search-all-folders.js <search-term1> [search-term2] ...');
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

const foldersToSearch = [
  'INBOX',
  'Spam',
  'Prullenbak',
  'Archive',
  'Trash',
  'Mailspring',
  'Mailspring.Snoozed',
  'INBOX.spam'
];

let currentFolderIndex = 0;
let allResults = [];

function searchNextFolder() {
  if (currentFolderIndex >= foldersToSearch.length) {
    // All folders searched
    console.log('\n=== SEARCH RESULTS ===\n');
    console.log(`Total matches: ${allResults.length}`);
    console.log('');

    allResults.forEach(result => {
      console.log(`[${result.folder}] [UID:${result.uid}]`);
      console.log(`  From: ${result.from}`);
      console.log(`  Subject: ${result.subject}`);
      console.log(`  Date: ${result.date}`);
      console.log('');
    });

    imap.end();
    return;
  }

  const folder = foldersToSearch[currentFolderIndex];

  imap.openBox(folder, true, (err, box) => {
    if (err) {
      console.error(`Error opening folder ${folder}:`, err.message);
      currentFolderIndex++;
      searchNextFolder();
      return;
    }

    // Search for messages in the last 7 days
    const since = new Date();
    since.setDate(since.getDate() - 7);

    const criteria = [
      ['SINCE', since]
    ];

    imap.search(criteria, (err, results) => {
      if (err) {
        console.error(`Error searching ${folder}:`, err.message);
        currentFolderIndex++;
        searchNextFolder();
        return;
      }

      if (!results || results.length === 0) {
        currentFolderIndex++;
        searchNextFolder();
        return;
      }

      const fetch = imap.fetch(results, {
        bodies: ['HEADER.FIELDS (FROM TO SUBJECT DATE)', 'TEXT'],
        struct: true
      });

      let processed = 0;

      fetch.on('message', (msg, seqno) => {
        let uid = null;
        let headers = {};
        let body = '';

        msg.on('attributes', (attrs) => {
          uid = attrs.uid;
        });

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
          // Check if any search term matches
          const searchableText = [
            headers.from || '',
            headers.subject || '',
            body
          ].join(' ').toLowerCase();

          const matches = searchTerms.some(term =>
            searchableText.includes(term.toLowerCase())
          );

          if (matches) {
            allResults.push({
              folder: folder,
              uid: uid,
              from: headers.from || 'N/A',
              subject: headers.subject || 'N/A',
              date: headers.date || 'N/A'
            });
          }

          processed++;
          if (processed === results.length) {
            currentFolderIndex++;
            searchNextFolder();
          }
        });
      });

      fetch.once('error', (err) => {
        console.error(`Fetch error in ${folder}:`, err.message);
        currentFolderIndex++;
        searchNextFolder();
      });

      fetch.once('end', () => {
        if (processed === 0) {
          currentFolderIndex++;
          searchNextFolder();
        }
      });
    });
  });
}

imap.once('ready', () => {
  searchNextFolder();
});

imap.once('error', (err) => {
  console.error('IMAP error:', err);
});

imap.once('end', () => {
  // Connection ended
});

imap.connect();
