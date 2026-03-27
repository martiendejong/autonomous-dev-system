#!/usr/bin/env node
/**
 * Email Cleanup - Batch spam detection and cleanup
 *
 * Usage:
 *   node email-cleanup.js [--dry-run] [--count=50]
 *
 * Scans inbox for known spam patterns and offers to clean up
 */

const Imap = require('imap');
const readline = require('readline');

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

// Spam patterns
const SPAM_DOMAINS = [
  'neooudh.store', 'rimhasi.com', 'ekvira.in', 'firebaseapp.com',
  'autoserve1.com', 'ilovepdf.lat', 'moochmarod.ae', 'khouchona.com',
  'refinhajoune.com', 'wpengine.com', 'mipequemola.es', 'washrocks.com',
  'brainito.com', 'whitepress.com'
];

const SPAM_SUBJECT_PATTERNS = [
  /claim.*\$?pengu/i,
  /coinbase.*verificat/i,
  /eherkenning.*verificat/i,
  /chatgpt.*subscription/i,
  /terugbetaling/i,
  /energietarieven.*besparen/i,
  /alarmsysteem/i,
  /mystery.?box/i
];

// LinkedIn is configurable - default to spam
const LINKEDIN_IS_SPAM = true;

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

function extractDomain(from) {
  const match = from.match(/@([^\s>]+)/);
  return match ? match[1].toLowerCase() : '';
}

function isSpam(from, subject) {
  const domain = extractDomain(from);
  const decodedSubject = decodeStr(subject);

  // Check domain
  if (SPAM_DOMAINS.some(d => domain.includes(d))) return true;

  // Check LinkedIn
  if (LINKEDIN_IS_SPAM && domain.includes('linkedin.com')) return true;

  // Check subject patterns
  if (SPAM_SUBJECT_PATTERNS.some(p => p.test(decodedSubject))) return true;

  return false;
}

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

function move(uids, folder) {
  return new Promise((resolve, reject) => {
    if (!uids || uids.length === 0) return resolve(0);
    imap.move(uids, folder, (err) => {
      if (err) reject(err);
      else resolve(uids.length);
    });
  });
}

function fetchMessages(uids) {
  return new Promise((resolve, reject) => {
    if (!uids || uids.length === 0) return resolve([]);

    const messages = [];
    const fetch = imap.fetch(uids, { bodies: 'HEADER.FIELDS (FROM SUBJECT DATE)' });

    fetch.on('message', (msg) => {
      let uid, headers = '';
      msg.on('body', (stream) => {
        stream.on('data', (chunk) => { headers += chunk.toString(); });
      });
      msg.once('attributes', (attrs) => { uid = attrs.uid; });
      msg.once('end', () => { messages.push({ uid, headers }); });
    });

    fetch.once('error', reject);
    fetch.once('end', () => resolve(messages));
  });
}

function ask(question) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  return new Promise(resolve => {
    rl.question(question, answer => {
      rl.close();
      resolve(answer.toLowerCase());
    });
  });
}

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const countArg = args.find(a => a.startsWith('--count='));
  const count = countArg ? parseInt(countArg.split('=')[1]) : 50;

  console.log('Email Cleanup Tool');
  console.log('==================');
  if (dryRun) console.log('[DRY RUN - No changes will be made]\n');

  return new Promise((resolve, reject) => {
    imap.once('ready', async () => {
      try {
        const box = await openBox('INBOX', dryRun);
        console.log(`Scanning last ${count} messages in INBOX (${box.messages.total} total)...\n`);

        const allUids = await search(['ALL']);
        const uidsToScan = allUids.slice(-count);

        const messages = await fetchMessages(uidsToScan);

        const spamMessages = [];

        for (const msg of messages) {
          const from = msg.headers.match(/From: (.+)/i)?.[1] || '';
          const subject = msg.headers.match(/Subject: (.+)/i)?.[1] || '';

          if (isSpam(from, subject)) {
            spamMessages.push({
              uid: msg.uid,
              from: decodeStr(from),
              subject: decodeStr(subject)
            });
          }
        }

        if (spamMessages.length === 0) {
          console.log('No spam detected in the scanned messages.');
          imap.end();
          resolve();
          return;
        }

        console.log(`Found ${spamMessages.length} potential spam messages:\n`);
        console.log('-'.repeat(70));

        for (const msg of spamMessages) {
          console.log(`UID ${msg.uid}: ${msg.from.substring(0, 40)}`);
          console.log(`  Subject: ${msg.subject.substring(0, 50)}`);
        }

        console.log('-'.repeat(70));
        console.log(`\nUIDs: ${spamMessages.map(m => m.uid).join(',')}`);

        if (dryRun) {
          console.log('\n[DRY RUN] Would move these to Spam folder.');
          imap.end();
          resolve();
          return;
        }

        const answer = await ask('\nMove all to Spam? (y/n): ');

        if (answer === 'y' || answer === 'yes') {
          const uids = spamMessages.map(m => m.uid);
          console.log(`\nMoving ${uids.length} messages to Spam...`);
          await move(uids, 'Spam');
          console.log('Done!');
        } else {
          console.log('Cancelled.');
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

    imap.connect();
  });
}

main().catch(() => process.exit(1));
