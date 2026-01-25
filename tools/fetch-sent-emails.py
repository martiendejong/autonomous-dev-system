#!/usr/bin/env python3
"""
Email Fetcher - Retrieve Sent Emails via IMAP
Fetches emails from Sent folder and saves them as text files
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
FILTER_TO = "meppel.nl"  # Only emails sent TO this domain
MAX_EMAILS = 100

def sanitize_filename(text):
    """Convert text to safe filename"""
    # Remove or replace unsafe characters
    text = re.sub(r'[<>:"/\\|?*]', '', text)
    # Replace spaces with underscores
    text = re.sub(r'\s+', '_', text)
    # Limit length
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

            # Get text/plain or text/html
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
    print("=== Email Fetcher ===")
    print(f"Host: {IMAP_HOST}")
    print(f"Email: {EMAIL_ADDRESS}")
    print(f"Filter: {FILTER_TO}")
    print(f"Output: {OUTPUT_DIR}")
    print()

    # Create output directory
    Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)

    try:
        # Connect to IMAP server
        print("Connecting to IMAP server...")
        imap = imaplib.IMAP4_SSL(IMAP_HOST, IMAP_PORT)

        # Login
        print("Logging in...")
        imap.login(EMAIL_ADDRESS, IMAP_PASSWORD)

        # Try different Sent folder names
        sent_folders = ["INBOX.Sent", "Sent", "Sent Items", "Verzonden"]
        selected_folder = None

        for folder in sent_folders:
            try:
                status, messages = imap.select(f'"{folder}"', readonly=True)
                if status == 'OK':
                    selected_folder = folder
                    print(f"Selected folder: {folder}")
                    break
            except:
                continue

        if not selected_folder:
            # List all folders
            print("Could not find Sent folder. Available folders:")
            status, folders = imap.list()
            for folder in folders:
                print(f"  {folder.decode()}")
            return

        # Search for emails
        print(f"Searching for emails to '{FILTER_TO}'...")
        status, message_ids = imap.search(None, f'(TO "{FILTER_TO}")')

        if status != 'OK':
            print("No messages found.")
            return

        email_ids = message_ids[0].split()
        total_emails = len(email_ids)
        print(f"Found {total_emails} matching emails")

        # Fetch emails
        emails_fetched = 0
        for i, email_id in enumerate(email_ids[-MAX_EMAILS:], 1):  # Get last MAX_EMAILS
            print(f"Fetching {i}/{min(total_emails, MAX_EMAILS)}...", end='\r')

            # Fetch email
            status, msg_data = imap.fetch(email_id, '(RFC822)')

            if status != 'OK':
                continue

            # Parse email
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

            # Extract body
            body = extract_email_body(msg)

            # Create filename
            safe_subject = sanitize_filename(subject)
            filename = f"{date_file}_{safe_subject}.txt"
            filepath = os.path.join(OUTPUT_DIR, filename)

            # Avoid duplicate filenames
            counter = 1
            while os.path.exists(filepath):
                filename = f"{date_file}_{safe_subject}_{counter}.txt"
                filepath = os.path.join(OUTPUT_DIR, filename)
                counter += 1

            # Save email
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(f"=== EMAIL ===\n")
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

        # Logout
        imap.logout()

    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
