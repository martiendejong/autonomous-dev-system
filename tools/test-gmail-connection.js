#!/usr/bin/env node
/**
 * Test Gmail IMAP connection
 */

const Imap = require('imap');

const password = process.env.GMAIL_APP_PASSWORD || process.argv[2] || '';

console.log('='.repeat(80));
console.log('GMAIL IMAP CONNECTION TEST');
console.log('='.repeat(80));
console.log(`Email: martiendejong2008@gmail.com`);
console.log(`Password length: ${password.length} characters`);
console.log(`Password (masked): ${password.substring(0, 4)}${'*'.repeat(password.length - 4)}`);
console.log('');

const config = {
  user: 'martiendejong2008@gmail.com',
  password: password,
  host: 'imap.gmail.com',
  port: 993,
  tls: true,
  tlsOptions: {
    rejectUnauthorized: false,
    servername: 'imap.gmail.com'
  },
  authTimeout: 30000,
  connTimeout: 30000,
  debug: console.log
};

const imap = new Imap(config);

imap.once('ready', () => {
  console.log('✅ SUCCESS! Connected to Gmail IMAP');
  imap.openBox('INBOX', true, (err, box) => {
    if (err) {
      console.error('❌ Error opening INBOX:', err.message);
    } else {
      console.log(`✅ INBOX opened: ${box.messages.total} total messages`);
    }
    imap.end();
  });
});

imap.once('error', (err) => {
  console.error('❌ Connection error:', err.message);
  console.error('');
  console.error('Troubleshooting steps:');
  console.error('1. Verify IMAP is enabled: https://mail.google.com/mail/u/0/#settings/fwdandpop');
  console.error('2. Verify 2FA is enabled: https://myaccount.google.com/security');
  console.error('3. Generate new app password: https://myaccount.google.com/apppasswords');
  console.error('4. Check for security alerts: https://myaccount.google.com/notifications');
  process.exit(1);
});

imap.once('end', () => {
  console.log('Connection ended');
});

imap.connect();
