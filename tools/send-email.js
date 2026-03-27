#!/usr/bin/env node
/**
 * Email Sender - SMTP email sending tool
 *
 * Usage:
 *   node send-email.js --to <email> --subject <subject> --body <body> [--html] [--attachments <file1,file2>]
 */

const nodemailer = require('nodemailer');
const fs = require('fs');
const path = require('path');

// Parse command line arguments
const args = process.argv.slice(2);
const options = {};

for (let i = 0; i < args.length; i++) {
  if (args[i].startsWith('--')) {
    const key = args[i].substring(2);
    const value = args[i + 1] && !args[i + 1].startsWith('--') ? args[i + 1] : true;
    options[key] = value;
    if (value !== true) i++;
  }
}

// Configuration
const config = {
  from: options.from || 'info@martiendejong.nl',
  to: options.to,
  subject: options.subject,
  body: options.body,
  html: options.html || false,
  attachments: options.attachments ? options.attachments.split(',') : []
};

// SMTP configuration for info@martiendejong.nl
const transporter = nodemailer.createTransport({
  host: 'mail.zxcs.nl',
  port: 465,
  secure: true, // Use SSL
  auth: {
    user: 'info@martiendejong.nl',
    pass: 'hLPFy6MdUnfEDbYTwXps'
  },
  tls: {
    rejectUnauthorized: false
  },
  connectionTimeout: 10000,
  greetingTimeout: 10000
});

async function sendEmail() {
  if (!config.to || !config.subject || !config.body) {
    console.error('Usage: node send-email.js --to <email> --subject <subject> --body <body> [--html] [--attachments <file1,file2>]');
    process.exit(1);
  }

  const mailOptions = {
    from: `"Martien de Jong - Claude Agent" <${config.from}>`,
    to: config.to,
    subject: config.subject
  };

  // Set body content
  if (config.html) {
    mailOptions.html = config.body;
  } else {
    mailOptions.text = config.body;
  }

  // Add attachments
  if (config.attachments.length > 0) {
    mailOptions.attachments = config.attachments.map(filePath => {
      const fullPath = path.resolve(filePath.trim());
      return {
        filename: path.basename(fullPath),
        path: fullPath
      };
    });
  }

  try {
    console.log('Sending email...');
    console.log(`From: ${mailOptions.from}`);
    console.log(`To: ${mailOptions.to}`);
    console.log(`Subject: ${mailOptions.subject}`);
    if (mailOptions.attachments) {
      console.log(`Attachments: ${mailOptions.attachments.map(a => a.filename).join(', ')}`);
    }

    const info = await transporter.sendMail(mailOptions);
    console.log('\n✅ Email sent successfully!');
    console.log(`Message ID: ${info.messageId}`);
  } catch (error) {
    console.error('\n❌ Failed to send email:', error.message);
    process.exit(1);
  }
}

sendEmail();
