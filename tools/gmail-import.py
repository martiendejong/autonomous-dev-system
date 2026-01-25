#!/usr/bin/env python3
"""
Gmail Email Import Tool
Importeert emails van specifieke contacten uit Gmail naar lokale bestanden
"""

import os
import base64
import json
from pathlib import Path
from datetime import datetime
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# Gmail API scopes
SCOPES = ['https://www.googleapis.com/auth/gmail.readonly']

# Email addresses to search for
CONTACTS = {
    'social_media_hulp': [
        'info@socialmediahulp.nl',
        'socialmediahulp.nl',
        'social media hulp'
    ],
    'arjan_stroeve': [
        'arjan@stroeve.nl',
        'arjan.stroeve',
        'arjanstroeve'
    ],
    'rinus_socranext': [
        'rinus@socranext.nl',
        'socranext.nl',
        'socranext'
    ],
    'allan_drenth': [
        'allan@drenth.nl',
        'allan.drenth',
        'allandrenth'
    ]
}

def get_gmail_service():
    """Authenticeert en maakt Gmail service aan"""
    creds = None
    token_path = Path('C:/scripts/_machine/gmail-token.json')
    credentials_path = Path('C:/scripts/_machine/gmail-credentials.json')

    # Token bestand bevat access en refresh tokens
    if token_path.exists():
        creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)

    # Als geen geldige credentials, login flow
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not credentials_path.exists():
                print(f"\n❌ Credentials bestand niet gevonden: {credentials_path}")
                print("\n📋 Setup vereist:")
                print("1. Ga naar https://console.cloud.google.com/")
                print("2. Maak een nieuw project aan (of gebruik bestaand)")
                print("3. Enable Gmail API")
                print("4. Maak OAuth 2.0 credentials (Desktop app)")
                print("5. Download JSON en sla op als:", credentials_path)
                return None

            flow = InstalledAppFlow.from_client_secrets_file(
                str(credentials_path), SCOPES)
            creds = flow.run_local_server(port=0)

        # Sla token op voor volgende keer
        token_path.write_text(creds.to_json())

    return build('gmail', 'v1', credentials=creds)

def build_query(contact_group):
    """Bouwt Gmail search query voor contactgroep"""
    contacts = CONTACTS.get(contact_group, [])
    # Zoek emails FROM of TO deze contacten
    from_queries = [f'from:{c}' for c in contacts]
    to_queries = [f'to:{c}' for c in contacts]
    all_queries = from_queries + to_queries
    return ' OR '.join(all_queries)

def get_message_body(payload):
    """Extraheert message body uit email payload"""
    body = ""

    if 'parts' in payload:
        for part in payload['parts']:
            if part['mimeType'] == 'text/plain':
                if 'data' in part['body']:
                    body = base64.urlsafe_b64decode(part['body']['data']).decode('utf-8')
                    break
            elif part['mimeType'] == 'text/html' and not body:
                if 'data' in part['body']:
                    body = base64.urlsafe_b64decode(part['body']['data']).decode('utf-8')
    else:
        if 'body' in payload and 'data' in payload['body']:
            body = base64.urlsafe_b64decode(payload['body']['data']).decode('utf-8')

    return body

def download_emails(service, contact_group, output_dir):
    """Download emails voor een contactgroep"""
    query = build_query(contact_group)
    print(f"\n🔍 Zoeken met query: {query}")

    try:
        # Zoek emails
        results = service.users().messages().list(
            userId='me',
            q=query,
            maxResults=500  # Maximaal 500 emails per contactgroep
        ).execute()

        messages = results.get('messages', [])
        print(f"📧 Gevonden: {len(messages)} emails")

        if not messages:
            return 0

        # Download elke email
        output_path = Path(output_dir) / contact_group
        output_path.mkdir(parents=True, exist_ok=True)

        for idx, message in enumerate(messages, 1):
            msg = service.users().messages().get(
                userId='me',
                id=message['id'],
                format='full'
            ).execute()

            # Extract metadata
            headers = msg['payload']['headers']
            subject = next((h['value'] for h in headers if h['name'] == 'Subject'), 'No Subject')
            from_email = next((h['value'] for h in headers if h['name'] == 'From'), 'Unknown')
            to_email = next((h['value'] for h in headers if h['name'] == 'To'), 'Unknown')
            date = next((h['value'] for h in headers if h['name'] == 'Date'), 'Unknown')

            # Extract body
            body = get_message_body(msg['payload'])

            # Parse date for filename (gebruik eerste deel van date header)
            try:
                from email.utils import parsedate_to_datetime
                date_obj = parsedate_to_datetime(date)
                date_str = date_obj.strftime('%Y-%m-%d')
            except:
                date_str = '0000-00-00'

            # Extract clean sender name/email
            from_clean = from_email.replace('<', '_').replace('>', '_').replace('"', '').strip()

            # Sanitize subject
            safe_subject = "".join(c for c in subject[:80] if c.isalnum() or c in (' ', '-', '_'))
            safe_subject = safe_subject.strip().replace(' ', ' ')

            # Build filename like gemeente_emails: {account}_{date}__{from}_{email}__{subject}.eml
            # Determine which email account (since we're logged into one account at a time)
            account = 'martiendejong2008@gmail.com'  # Will be the logged-in account

            base_filename = f"{account}_{date_str}__{from_clean}__{safe_subject}"

            # Save as .EML (email message format)
            eml_filename = f"{base_filename}.eml"
            eml_path = output_path / eml_filename

            # Get raw email for .eml format
            raw_msg = service.users().messages().get(
                userId='me',
                id=message['id'],
                format='raw'
            ).execute()

            msg_bytes = base64.urlsafe_b64decode(raw_msg['raw'])
            eml_path.write_bytes(msg_bytes)

            # Save metadata as JSON
            email_metadata = {
                'id': message['id'],
                'subject': subject,
                'from': from_email,
                'to': to_email,
                'date': date
            }

            json_filename = f"{base_filename}.json"
            json_path = output_path / json_filename
            json_path.write_text(json.dumps(email_metadata, indent=2, ensure_ascii=False), encoding='utf-8')

            print(f"  [{idx}/{len(messages)}] ✅ {subject[:60]}")

        print(f"\n✅ {len(messages)} emails opgeslagen in {output_path}")
        return len(messages)

    except HttpError as error:
        print(f'❌ Fout bij ophalen emails: {error}')
        return 0

def main():
    """Main functie"""
    print("=" * 60)
    print("Gmail Email Import Tool")
    print("=" * 60)

    # Authenticatie
    print("\n🔐 Authenticeren met Gmail...")
    service = get_gmail_service()

    if not service:
        print("\n❌ Authenticatie mislukt. Setup vereist.")
        return

    print("✅ Authenticatie succesvol!")

    # Import voor elke contactgroep
    output_dir = Path('C:/scripts/arjan_emails')
    total_emails = 0

    for contact_group in CONTACTS.keys():
        print(f"\n{'='*60}")
        print(f"📂 Contact groep: {contact_group.replace('_', ' ').title()}")
        print(f"{'='*60}")
        count = download_emails(service, contact_group, output_dir)
        total_emails += count

    print(f"\n{'='*60}")
    print(f"✅ KLAAR - Totaal {total_emails} emails geïmporteerd")
    print(f"{'='*60}")

if __name__ == '__main__':
    main()
