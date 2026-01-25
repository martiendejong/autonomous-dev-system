#!/usr/bin/env node
/**
 * IMAP Spam Manager - View and delete spam messages
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
    imap.openBox(boxName, false, (err, box) => {
      if (err) reject(err);
      else resolve(box);
    });
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

function moveToTrash(uids, trashFolder) {
  return new Promise((resolve, reject) => {
    if (!uids || uids.length === 0) {
      resolve(0);
      return;
    }

    imap.move(uids, trashFolder, (err) => {
      if (err) reject(err);
      else resolve(uids.length);
    });
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

async function processSpamFolder(folderName, trashFolder, sixDaysAgo) {
  console.log(`\n${'='.repeat(80)}`);
  console.log(`CHECKING: ${folderName}`);
  console.log('='.repeat(80));

  try {
    const box = await openBox(folderName);
    console.log(`Total messages: ${box.messages.total}`);

    if (box.messages.total === 0) {
      console.log('No messages in this folder.');
      return { shown: 0, moved: 0 };
    }

    // Get ALL messages to show titles
    const allUids = await search(['ALL']);
    console.log(`\nAll spam messages in ${folderName}:`);
    console.log('-'.repeat(60));

    const messages = await fetchMessages(allUids);

    const recentUids = [];

    for (const msg of messages) {
      const headers = parseHeaders(msg.headers);
      const subject = headers.subject || '(No Subject)';
      const from = headers.from || '(Unknown)';
      const dateStr = headers.date || '(No Date)';

      // Parse date to check if recent
      let msgDate = new Date(dateStr);
      const isRecent = msgDate >= sixDaysAgo;

      if (isRecent) {
        recentUids.push(msg.uid);
      }

      const marker = isRecent ? '[RECENT]' : '';
      console.log(`${marker} ${dateStr}`);
      console.log(`   From: ${from}`);
      console.log(`   Subject: ${subject}`);
      console.log('');
    }

    console.log(`\nMessages from last 6 days: ${recentUids.length}`);

    // Move recent messages to trash
    if (recentUids.length > 0 && trashFolder) {
      console.log(`Moving ${recentUids.length} recent messages to ${trashFolder}...`);
      const moved = await moveToTrash(recentUids, trashFolder);
      console.log(`Moved ${moved} messages to trash.`);
      return { shown: messages.length, moved };
    }

    return { shown: messages.length, moved: 0 };
  } catch (err) {
    console.log(`Error accessing ${folderName}: ${err.message}`);
    return { shown: 0, moved: 0 };
  }
}

async function main() {
  console.log('Connecting to IMAP server (mail.zxcs.nl:993)...');
  console.log('User:', config.user);

  return new Promise((resolve, reject) => {
    imap.once('ready', async () => {
      console.log('Connected successfully!\n');
      try {
        const boxes = await getBoxes();
        console.log('Available folders:');
        const folderNames = [];
        function listFolders(obj, prefix = '') {
          for (const [name, data] of Object.entries(obj)) {
            const fullName = prefix ? `${prefix}${data.delimiter}${name}` : name;
            folderNames.push(fullName);
            console.log(`  - ${fullName}`);
            if (data.children) {
              listFolders(data.children, fullName);
            }
          }
        }
        listFolders(boxes);

        // Find all spam folders
        const spamFolders = folderNames.filter(f =>
          f.toLowerCase().includes('spam') ||
          f.toLowerCase().includes('junk') ||
          f.toLowerCase() === 'bulk'
        );

        const trashFolder = folderNames.find(f =>
          f.toLowerCase() === 'trash' ||
          f.toLowerCase() === 'prullenbak'
        );

        console.log(`\nSpam folders found: ${spamFolders.join(', ')}`);
        console.log(`Trash folder: ${trashFolder || 'Not found'}`);

        const sixDaysAgo = new Date();
        sixDaysAgo.setDate(sixDaysAgo.getDate() - 6);
        sixDaysAgo.setHours(0, 0, 0, 0);
        console.log(`\nLooking for messages since: ${sixDaysAgo.toLocaleDateString()}`);

        let totalShown = 0;
        let totalMoved = 0;

        for (const folder of spamFolders) {
          const result = await processSpamFolder(folder, trashFolder, sixDaysAgo);
          totalShown += result.shown;
          totalMoved += result.moved;
        }

        console.log('\n' + '='.repeat(80));
        console.log('SUMMARY');
        console.log('='.repeat(80));
        console.log(`Total spam messages shown: ${totalShown}`);
        console.log(`Total messages moved to trash: ${totalMoved}`);

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
