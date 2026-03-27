#!/usr/bin/env node
/**
 * Save a copy of sent email to Sent folder
 */

const Imap = require('imap');
const fs = require('fs');

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

const to = process.argv[2];
const subject = process.argv[3];
const bodyFile = process.argv[4];

if (!to || !subject || !bodyFile) {
  console.error('Usage: node save-to-sent.js <to> <subject> <body-file>');
  process.exit(1);
}

const body = fs.readFileSync(bodyFile, 'utf8');
const now = new Date();

// Create RFC822 formatted email
const message = [
  `From: "Martien de Jong - Claude Agent" <info@martiendejong.nl>`,
  `To: ${to}`,
  `Subject: ${subject}`,
  `Date: ${now.toUTCString()}`,
  `Message-ID: <${Date.now()}@martiendejong.nl>`,
  `Content-Type: text/html; charset="UTF-8"`,
  '',
  body
].join('\r\n');

const imap = new Imap(config);

imap.once('ready', () => {
  imap.openBox('Sent', false, (err, box) => {
    if (err) {
      console.error('Error opening Sent folder:', err.message);
      imap.end();
      return;
    }

    imap.append(message, { mailbox: 'Sent', flags: ['\\Seen'] }, (err) => {
      if (err) {
        console.error('Error saving to Sent:', err.message);
      } else {
        console.log('✅ Email saved to Sent folder');
      }
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
