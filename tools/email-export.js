#!/usr/bin/env node
/**
 * Email Export Tool - Download and save emails from multiple accounts
 *
 * Usage:
 *   node email-export.js --query "gemeente meppel" --output "C:\\gemeente_emails"
 */

const Imap = require('imap');
const { simpleParser } = require('mailparser');
const fs = require('fs');
const path = require('path');

// Parse command line arguments
const args = process.argv.slice(2);
const query = args.find(a => a.startsWith('--query='))?.split('=')[1] || 'gemeente meppel';
const outputDir = args.find(a => a.startsWith('--output='))?.split('=')[1] || 'C:\\gemeente_emails';

// Email account configurations
const accounts = [
  {
    name: 'info@martiendejong.nl',
    config: {
      user: 'info@martiendejong.nl',
      password: 'hLPFy6MdUnfEDbYTwXps',
      host: 'mail.zxcs.nl',
      port: 993,
      tls: true,
      tlsOptions: { rejectUnauthorized: false },
      authTimeout: 30000,
      connTimeout: 30000
    }
  },
  {
    name: 'martiendejong2008@gmail.com',
    config: {
      user: 'martiendejong2008@gmail.com',
      password: process.env.GMAIL_APP_PASSWORD || '', // Needs app-specific password
      host: 'imap.gmail.com',
      port: 993,
      tls: true,
      tlsOptions: {
        rejectUnauthorized: false,
        servername: 'imap.gmail.com'
      },
      authTimeout: 30000,
      connTimeout: 30000
    }
  }
];

// Ensure output directory exists
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
  console.log(`Created output directory: ${outputDir}`);
}

// Helper functions
function search(imap, criteria) {
  return new Promise((resolve, reject) => {
    imap.search(criteria, (err, results) => {
      if (err) reject(err);
      else resolve(results || []);
    });
  });
}

function fetchMessage(imap, uid) {
  return new Promise((resolve, reject) => {
    const fetch = imap.fetch(uid, { bodies: '', markSeen: false });
    let buffer = '';

    fetch.on('message', (msg) => {
      msg.on('body', (stream) => {
        stream.on('data', (chunk) => { buffer += chunk.toString('utf8'); });
      });
      msg.once('end', () => {
        simpleParser(buffer)
          .then(parsed => resolve(parsed))
          .catch(reject);
      });
    });

    fetch.once('error', reject);
  });
}

function openBox(imap, boxName) {
  return new Promise((resolve, reject) => {
    imap.openBox(boxName, true, (err, box) => {
      if (err) reject(err);
      else resolve(box);
    });
  });
}

function sanitizeFilename(str) {
  return str.replace(/[<>:"/\\|?*\x00-\x1F]/g, '_').substring(0, 100);
}

async function processAccount(accountInfo) {
  const { name, config } = accountInfo;

  // Skip if no password configured
  if (!config.password) {
    console.log(`\n⚠️  Skipping ${name} - no password configured`);
    console.log(`   For Gmail, set GMAIL_APP_PASSWORD environment variable`);
    return [];
  }

  console.log(`\n📧 Processing account: ${name}`);
  console.log(`   Searching for: "${query}"`);

  const imap = new Imap(config);
  const emails = [];

  return new Promise((resolve, reject) => {
    imap.once('ready', async () => {
      try {
        await openBox(imap, 'INBOX');

        // Fetch ALL emails and filter manually (more reliable than IMAP search)
        console.log(`   Fetching all emails from INBOX...`);
        const allUids = await search(imap, ['ALL']);
        console.log(`   Total emails in INBOX: ${allUids.length}`);

        // Fetch headers for all emails
        console.log(`   Fetching headers to filter by "${query}"...`);
        const fetch = imap.fetch(allUids, { bodies: 'HEADER.FIELDS (FROM TO SUBJECT)' });
        const matchingUids = [];

        await new Promise((resolve, reject) => {
          fetch.on('message', (msg) => {
            let uid, headers = '';
            msg.on('body', (stream) => {
              stream.on('data', (chunk) => { headers += chunk.toString(); });
            });
            msg.once('attributes', (attrs) => { uid = attrs.uid; });
            msg.once('end', () => {
              // Check if headers contain the query (case-insensitive)
              if (headers.toLowerCase().includes(query.toLowerCase())) {
                matchingUids.push(uid);
              }
            });
          });

          fetch.once('error', reject);
          fetch.once('end', resolve);
        });

        const uids = matchingUids;
        console.log(`   Found ${uids.length} matching emails`);

        if (uids.length === 0) {
          imap.end();
          return resolve(emails);
        }

        // Fetch and save each email
        for (let i = 0; i < uids.length; i++) {
          const uid = uids[i];
          console.log(`   Downloading ${i + 1}/${uids.length} (UID: ${uid})...`);

          try {
            const parsed = await fetchMessage(imap, uid);

            // Create filename from date, sender, and subject
            const date = parsed.date ? parsed.date.toISOString().split('T')[0] : 'no-date';
            const from = parsed.from?.text || 'unknown';
            const subject = parsed.subject || 'no-subject';
            const filename = `${date}_${sanitizeFilename(from)}_${sanitizeFilename(subject)}.eml`;
            const filepath = path.join(outputDir, `${name}_${filename}`);

            // Save original email in .eml format
            fs.writeFileSync(filepath, parsed.text || parsed.html || '(No content)', 'utf8');

            // Also save metadata
            const metadata = {
              account: name,
              uid: uid,
              from: parsed.from?.text,
              to: parsed.to?.text,
              cc: parsed.cc?.text,
              subject: parsed.subject,
              date: parsed.date,
              hasAttachments: (parsed.attachments?.length || 0) > 0,
              attachments: parsed.attachments?.map(a => a.filename) || []
            };

            fs.writeFileSync(
              filepath.replace('.eml', '.json'),
              JSON.stringify(metadata, null, 2),
              'utf8'
            );

            emails.push({
              account: name,
              subject: subject,
              from: from,
              date: date,
              file: filepath
            });

          } catch (err) {
            console.error(`   Error processing UID ${uid}: ${err.message}`);
          }
        }

        imap.end();
        resolve(emails);

      } catch (err) {
        console.error(`   Error: ${err.message}`);
        imap.end();
        reject(err);
      }
    });

    imap.once('error', (err) => {
      console.error(`   Connection error for ${name}: ${err.message}`);
      resolve([]); // Continue with other accounts
    });

    imap.connect();
  });
}

// Main execution
async function main() {
  console.log('='.repeat(80));
  console.log('EMAIL EXPORT TOOL');
  console.log('='.repeat(80));
  console.log(`Search query: "${query}"`);
  console.log(`Output directory: ${outputDir}`);
  console.log(`Processing ${accounts.length} accounts...`);

  let allEmails = [];

  for (const account of accounts) {
    try {
      const emails = await processAccount(account);
      allEmails = allEmails.concat(emails);
    } catch (err) {
      console.error(`Failed to process ${account.name}: ${err.message}`);
    }
  }

  // Generate summary report
  console.log('\n' + '='.repeat(80));
  console.log('EXPORT COMPLETE');
  console.log('='.repeat(80));
  console.log(`Total emails exported: ${allEmails.length}`);
  console.log(`Saved to: ${outputDir}`);

  if (allEmails.length > 0) {
    console.log('\nExported emails:');
    allEmails.forEach((email, i) => {
      console.log(`  ${i + 1}. [${email.account}] ${email.date} - ${email.from}`);
      console.log(`     Subject: ${email.subject}`);
      console.log(`     File: ${email.file}`);
    });

    // Save summary
    const summaryPath = path.join(outputDir, '_export_summary.json');
    fs.writeFileSync(summaryPath, JSON.stringify({
      exportDate: new Date().toISOString(),
      query: query,
      totalEmails: allEmails.length,
      emails: allEmails
    }, null, 2));
    console.log(`\nSummary saved to: ${summaryPath}`);
  }
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
