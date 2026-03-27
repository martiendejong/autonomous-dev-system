#!/usr/bin/env node
/**
 * Email Manager - Unified IMAP email management tool
 *
 * Usage:
 *   node email-manager.js list [--count=10] [--offset=0]
 *   node email-manager.js spam <uid1,uid2,...>
 *   node email-manager.js archive <uid1,uid2,...>
 *   node email-manager.js trash <uid1,uid2,...>
 *   node email-manager.js folders
 *   node email-manager.js search <query>
 */

const Imap = require('imap');
const fs = require('fs');

// Load credentials
const credsPath = 'C:\\scripts\\_machine\\credentials.md';
let imapPassword = 'hLPFy6MdUnfEDbYTwXps'; // fallback

const config = {
  user: 'info@martiendejong.nl',
  password: imapPassword,
  host: 'mail.zxcs.nl',
  port: 993,
  tls: true,
  tlsOptions: { rejectUnauthorized: false },
  authTimeout: 30000,
  connTimeout: 30000
};

// Known spam domains for auto-detection
const SPAM_DOMAINS = [
  'neooudh.store', 'rimhasi.com', 'ekvira.in', 'firebaseapp.com',
  'autoserve1.com', 'ilovepdf.lat', 'moochmarod.ae', 'khouchona.com',
  'refinhajoune.com', 'wpengine.com', 'mipequemola.es', 'washrocks.com'
];

const ARCHIVE_DOMAINS = ['lovable.dev', 'surveymonkey.com'];

const imap = new Imap(config);

// Helper functions
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

function isSpamDomain(from) {
  const domain = extractDomain(from);
  return SPAM_DOMAINS.some(d => domain.includes(d));
}

function isArchiveDomain(from) {
  const domain = extractDomain(from);
  return ARCHIVE_DOMAINS.some(d => domain.includes(d));
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

function getBoxes() {
  return new Promise((resolve, reject) => {
    imap.getBoxes((err, boxes) => {
      if (err) reject(err);
      else resolve(boxes);
    });
  });
}

// Commands
async function listMessages(count = 10, offset = 0) {
  const box = await openBox('INBOX', true);
  console.log(`INBOX: ${box.messages.total} total messages\n`);

  const allUids = await search(['ALL']);
  const start = offset + count;
  const end = offset || undefined;
  const uids = allUids.slice(-start, end ? -end : undefined).reverse();

  if (uids.length === 0) {
    console.log('No messages found.');
    return;
  }

  const messages = await fetchMessages(uids);
  messages.sort((a, b) => b.uid - a.uid);

  console.log('='.repeat(80));
  console.log(`MESSAGES ${offset + 1}-${offset + messages.length}`);
  console.log('='.repeat(80));

  for (let i = 0; i < messages.length; i++) {
    const msg = messages[i];
    const from = decodeStr(msg.headers.match(/From: (.+)/i)?.[1] || '(Unknown)');
    const subject = decodeStr(msg.headers.match(/Subject: (.+)/i)?.[1] || '(No Subject)');
    const date = msg.headers.match(/Date: (.+)/i)?.[1] || '(No Date)';

    let flag = '';
    if (isSpamDomain(from)) flag = ' [SPAM?]';
    else if (isArchiveDomain(from)) flag = ' [ARCHIVE?]';

    console.log(`\n${offset + i + 1}. [UID:${msg.uid}]${flag}`);
    console.log(`   Date: ${date}`);
    console.log(`   From: ${from}`);
    console.log(`   Subject: ${subject}`);
    console.log('-'.repeat(70));
  }
}

async function moveToFolder(uids, folder) {
  await openBox('INBOX', false);
  console.log(`Moving ${uids.length} message(s) to ${folder}...`);
  const moved = await move(uids, folder);
  console.log(`Moved ${moved} message(s).`);
}

async function listFolders() {
  const boxes = await getBoxes();
  console.log('Available folders:');

  function printFolders(obj, prefix = '') {
    for (const [name, data] of Object.entries(obj)) {
      const fullName = prefix ? `${prefix}${data.delimiter}${name}` : name;
      console.log(`  - ${fullName}`);
      if (data.children) {
        printFolders(data.children, fullName);
      }
    }
  }
  printFolders(boxes);
}

async function searchMessages(query) {
  const box = await openBox('INBOX', true);
  const criteria = [['OR', ['FROM', query], ['SUBJECT', query]]];
  const uids = await search(criteria);

  console.log(`Found ${uids.length} messages matching "${query}"\n`);

  if (uids.length === 0) return;

  const messages = await fetchMessages(uids.slice(-20)); // Last 20 matches
  messages.sort((a, b) => b.uid - a.uid);

  for (const msg of messages) {
    const from = decodeStr(msg.headers.match(/From: (.+)/i)?.[1] || '(Unknown)');
    const subject = decodeStr(msg.headers.match(/Subject: (.+)/i)?.[1] || '(No Subject)');
    console.log(`[UID:${msg.uid}] ${from.substring(0, 30)} - ${subject.substring(0, 40)}`);
  }
}

// Main
async function main() {
  const args = process.argv.slice(2);
  const command = args[0] || 'list';

  return new Promise((resolve, reject) => {
    imap.once('ready', async () => {
      try {
        switch (command) {
          case 'list': {
            const countArg = args.find(a => a.startsWith('--count='));
            const offsetArg = args.find(a => a.startsWith('--offset='));
            const count = countArg ? parseInt(countArg.split('=')[1]) : 10;
            const offset = offsetArg ? parseInt(offsetArg.split('=')[1]) : 0;
            await listMessages(count, offset);
            break;
          }
          case 'spam': {
            const uids = args[1]?.split(',').map(Number).filter(n => n > 0) || [];
            if (uids.length === 0) {
              console.log('Usage: email-manager.js spam <uid1,uid2,...>');
            } else {
              await moveToFolder(uids, 'Spam');
            }
            break;
          }
          case 'archive': {
            const uids = args[1]?.split(',').map(Number).filter(n => n > 0) || [];
            if (uids.length === 0) {
              console.log('Usage: email-manager.js archive <uid1,uid2,...>');
            } else {
              await moveToFolder(uids, 'Archive');
            }
            break;
          }
          case 'trash': {
            const uids = args[1]?.split(',').map(Number).filter(n => n > 0) || [];
            if (uids.length === 0) {
              console.log('Usage: email-manager.js trash <uid1,uid2,...>');
            } else {
              await moveToFolder(uids, 'Trash');
            }
            break;
          }
          case 'folders': {
            await listFolders();
            break;
          }
          case 'search': {
            const query = args[1];
            if (!query) {
              console.log('Usage: email-manager.js search <query>');
            } else {
              await searchMessages(query);
            }
            break;
          }
          default:
            console.log(`
Email Manager - IMAP email management tool

Commands:
  list [--count=10] [--offset=0]  List inbox messages
  spam <uid1,uid2,...>            Move messages to Spam
  archive <uid1,uid2,...>         Move messages to Archive
  trash <uid1,uid2,...>           Move messages to Trash
  folders                         List all folders
  search <query>                  Search messages by from/subject

Examples:
  node email-manager.js list
  node email-manager.js list --count=5 --offset=10
  node email-manager.js spam 1234,1235,1236
  node email-manager.js search "anthropic"
`);
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
