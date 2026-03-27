#!/usr/bin/env python3
"""
Email Fetcher - Retrieve Inbox Emails via IMAP
Fetches emails from INBOX folder and saves them as text files
"""

import imaplib
import email
import os
import re
from datetime import datetime
from pathlib import Path

# Configuration
IMAP_HOST = "mail.zxcs.nl"
IMAP_PORT = 993
EMAIL_ADDRESS = "info@martiendejong.nl"
IMAP_PASSWORD = "hLPFy6MdUnfEDbYTwXps"
OUTPUT_DIR = r"C:\scripts\correspondence\gemeente-meppel"
FILTER_FROM = "meppel.nl"  # Only emails FROM this domain
MAX_EMAILS = 100

def sanitize_filename(text):
    """Convert text to safe filename"""
    text = re.sub(r'[<>:"/\\|?*]', '', text)
    text = re.sub(r'\s+', '_', text)
    return text[:100]

def decode_header(header):
    """Decode email header"""
    if header is None:
        return ""
    decoded_parts = email.header.decode_header(header)
    result = []
    for part, encoding in decoded_parts:
        if isinstance(part, bytes):
            try:
                result.append(part.decode(encoding or 'utf-8', errors='replace'))
            except:
                result.append(part.decode('utf-8', errors='replace'))
        else:
            result.append(part)
    return ''.join(result)

def extract_email_body(msg):
    """Extract email body from message"""
    body = ""
    if msg.is_multipart():
        for part in msg.walk():
            content_type = part.get_content_type()
            content_disposition = str(part.get("Content-Disposition"))
            if content_type == "text/plain" and "attachment" not in content_disposition:
                try:
                    body = part.get_payload(decode=True).decode('utf-8', errors='replace')
                    break
                except:
                    pass
            elif content_type == "text/html" and not body and "attachment" not in content_disposition:
                try:
                    body = part.get_payload(decode=True).decode('utf-8', errors='replace')
                except:
                    pass
    else:
        try:
            body = msg.get_payload(decode=True).decode('utf-8', errors='replace')
        except:
            body = str(msg.get_payload())
    return body

def main():
    print("=== Email Fetcher (INBOX) ===")
    print(f"Host: {IMAP_HOST}")
    print(f"Email: {EMAIL_ADDRESS}")
    print(f"Filter: FROM {FILTER_FROM}")
    print(f"Output: {OUTPUT_DIR}")
    print()

    Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)

    try:
        print("Connecting to IMAP server...")
        imap = imaplib.IMAP4_SSL(IMAP_HOST, IMAP_PORT)

        print("Logging in...")
        imap.login(EMAIL_ADDRESS, IMAP_PASSWORD)

        status, messages = imap.select('"INBOX"', readonly=True)
        if status != 'OK':
            print("Could not select INBOX")
            return

        print("Selected folder: INBOX")

        # Search for emails
        print(f"Searching for emails from '{FILTER_FROM}'...")
        status, message_ids = imap.search(None, f'(FROM "{FILTER_FROM}")')

        if status != 'OK':
            print("No messages found.")
            return

        email_ids = message_ids[0].split()
        total_emails = len(email_ids)
        print(f"Found {total_emails} matching emails")

        # Fetch emails
        emails_fetched = 0
        for i, email_id in enumerate(email_ids[-MAX_EMAILS:], 1):
            print(f"Fetching {i}/{min(total_emails, MAX_EMAILS)}...", end='\r')

            status, msg_data = imap.fetch(email_id, '(RFC822)')
            if status != 'OK':
                continue

            raw_email = msg_data[0][1]
            msg = email.message_from_bytes(raw_email)

            # Extract headers
            subject = decode_header(msg.get('Subject', 'No Subject'))
            date_str = msg.get('Date', '')
            to_addr = decode_header(msg.get('To', ''))
            from_addr = decode_header(msg.get('From', ''))
            cc_addr = decode_header(msg.get('Cc', ''))

            # Parse date
            try:
                date_parsed = email.utils.parsedate_to_datetime(date_str)
                date_formatted = date_parsed.strftime('%Y-%m-%d %H:%M:%S')
                date_file = date_parsed.strftime('%Y%m%d')
            except:
                date_formatted = date_str
                date_file = "unknown"

            body = extract_email_body(msg)

            # Create filename with INBOX prefix
            safe_subject = sanitize_filename(subject)
            filename = f"INBOX_{date_file}_{safe_subject}.txt"
            filepath = os.path.join(OUTPUT_DIR, filename)

            counter = 1
            while os.path.exists(filepath):
                filename = f"INBOX_{date_file}_{safe_subject}_{counter}.txt"
                filepath = os.path.join(OUTPUT_DIR, filename)
                counter += 1

            # Save email
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(f"=== EMAIL (RECEIVED) ===\n")
                f.write(f"Date: {date_formatted}\n")
                f.write(f"From: {from_addr}\n")
                f.write(f"To: {to_addr}\n")
                if cc_addr:
                    f.write(f"Cc: {cc_addr}\n")
                f.write(f"Subject: {subject}\n")
                f.write(f"\n--- BODY ---\n\n")
                f.write(body)

            emails_fetched += 1

        print(f"\n\n=== Summary ===")
        print(f"Fetched: {emails_fetched} emails")
        print(f"Saved to: {OUTPUT_DIR}")

        imap.logout()

    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
