#!/usr/bin/env node
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

imap.once('ready', async () => {
  imap.openBox('INBOX', true, (err, box) => {
    if (err) throw err;

    imap.search(['ALL'], (err, uids) => {
      if (err) throw err;

      // Get last 5 UIDs
      const last5 = uids.slice(-5);
      console.log('Last 5 UIDs:', last5.join(', '));

      // Fetch to identify which is which
      const fetch = imap.fetch(last5, { bodies: 'HEADER.FIELDS (FROM SUBJECT)', struct: true });

      fetch.on('message', (msg) => {
        let uid, headers = '';
        msg.on('body', (stream) => {
          stream.on('data', (chunk) => { headers += chunk.toString(); });
        });
        msg.once('attributes', (attrs) => { uid = attrs.uid; });
        msg.once('end', () => {
          const from = headers.match(/From: (.+)/i)?.[1] || '';
          console.log(`UID ${uid}: ${from.substring(0, 50)}`);
        });
      });

      fetch.once('end', () => {
        imap.end();
      });
    });
  });
});

imap.once('error', (err) => console.error(err));
imap.connect();
