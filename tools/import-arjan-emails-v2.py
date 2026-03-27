#!/usr/bin/env python3
"""
Arjan Emails Import Tool - Versie 2
Importeert emails van specifieke contacten uit beide mailboxen
Output format: identiek aan gemeente_emails (EML + JSON)
"""

import os
import sys
import base64
import json
from pathlib import Path
from datetime import datetime
from email.utils import parsedate_to_datetime
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# Gmail API scopes
SCOPES = ['https://www.googleapis.com/auth/gmail.readonly']

# Email accounts configuratie
EMAIL_ACCOUNTS = {
    'gmail': {
        'account': 'martiendejong2008@gmail.com',
        'credentials_path': 'C:/scripts/_machine/gmail-credentials.json',
        'token_path': 'C:/scripts/_machine/gmail-token.json'
    },
    'martiendejong': {
        'account': 'info@martiendejong.nl',
        'credentials_path': 'C:/scripts/_machine/martiendejong-credentials.json',
        'token_path': 'C:/scripts/_machine/martiendejong-token.json'
    }
}

# Contactpersonen om te zoeken
CONTACTS = {
    'social_media_hulp': {
        'name': 'Social Media Hulp',
        'emails': [
            'info@socialmediahulp.nl',
            'socialmediahulp.nl',
            'social media hulp',
            'socialmediahulp'
        ]
    },
    'arjan_stroeve': {
        'name': 'Arjan Stroeve',
        'emails': [
            'arjan@stroeve.nl',
            'arjan.stroeve@',
            'arjanstroeve',
            'stroeve'
        ]
    },
    'rinus_socranext': {
        'name': 'Rinus Huisman (Socranext)',
        'emails': [
            'rinushuisman@gmail.com',
            'rinus@socranext.nl',
            'socranext.nl',
            'socranext',
            'rinus huisman',
            'rinushuisman',
            'rinus'
        ]
    },
    'allan_drenth': {
        'name': 'Allan Drenth',
        'emails': [
            'allan@drenth.nl',
            'allan.drenth@',
            'allandrenth',
            'drenth'
        ]
    }
}

def get_gmail_service(account_key):
    """Authenticeert en maakt Gmail service aan voor specifiek account"""
    config = EMAIL_ACCOUNTS[account_key]
    creds = None
    token_path = Path(config['token_path'])
    credentials_path = Path(config['credentials_path'])

    print(f"\n🔐 Authenticeren voor: {config['account']}")

    # Token bestand bevat access en refresh tokens
    if token_path.exists():
        creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)

    # Als geen geldige credentials, login flow
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            print("   🔄 Refreshing token...")
            creds.refresh(Request())
        else:
            if not credentials_path.exists():
                print(f"\n❌ Credentials niet gevonden: {credentials_path}")
                print("\n📋 Setup vereist:")
                print("1. https://console.cloud.google.com/")
                print("2. Maak OAuth 2.0 credentials (Desktop app)")
                print("3. Download JSON → sla op als:", credentials_path)
                return None

            print(f"   🌐 OAuth flow starten voor {config['account']}...")
            flow = InstalledAppFlow.from_client_secrets_file(
                str(credentials_path), SCOPES)
            creds = flow.run_local_server(port=0)

        # Sla token op
        token_path.write_text(creds.to_json())
        print("   ✅ Token opgeslagen")

    return build('gmail', 'v1', credentials=creds)

def build_query(contact_group):
    """Bouwt Gmail search query voor contactgroep"""
    contact_info = CONTACTS.get(contact_group, {})
    emails = contact_info.get('emails', [])

    # Zoek emails FROM of TO deze contacten
    from_queries = [f'from:{c}' for c in emails]
    to_queries = [f'to:{c}' for c in emails]
    all_queries = from_queries + to_queries

    return ' OR '.join(all_queries)

def sanitize_filename_part(text, max_len=80):
    """Maakt text veilig voor gebruik in filename"""
    # Verwijder/vervang onveilige karakters
    safe = text.replace('<', '_').replace('>', '_').replace('"', '')
    safe = safe.replace('/', '_').replace('\\', '_').replace(':', '_')
    safe = safe.replace('|', '_').replace('*', '_').replace('?', '_')
    safe = "".join(c for c in safe if c.isalnum() or c in (' ', '-', '_', '@', '.'))
    safe = safe.strip()[:max_len]
    return safe

def download_emails(service, account_name, contact_group, output_dir):
    """Download emails voor een contactgroep"""
    contact_info = CONTACTS[contact_group]
    query = build_query(contact_group)

    print(f"\n{'='*70}")
    print(f"📂 Contact groep: {contact_info['name']}")
    print(f"🔍 Query: {query[:100]}...")
    print(f"{'='*70}")

    try:
        # Zoek emails
        results = service.users().messages().list(
            userId='me',
            q=query,
            maxResults=500
        ).execute()

        messages = results.get('messages', [])
        print(f"📧 Gevonden: {len(messages)} emails")

        if not messages:
            print("   ℹ️  Geen emails gevonden voor deze contactgroep")
            return 0

        # Output directory
        output_path = Path(output_dir) / contact_group
        output_path.mkdir(parents=True, exist_ok=True)

        # Download elke email
        for idx, message in enumerate(messages, 1):
            try:
                # Get full message
                msg = service.users().messages().get(
                    userId='me',
                    id=message['id'],
                    format='full'
                ).execute()

                # Extract headers
                headers = msg['payload']['headers']
                subject = next((h['value'] for h in headers if h['name'].lower() == 'subject'), 'No Subject')
                from_email = next((h['value'] for h in headers if h['name'].lower() == 'from'), 'Unknown')
                to_email = next((h['value'] for h in headers if h['name'].lower() == 'to'), 'Unknown')
                date = next((h['value'] for h in headers if h['name'].lower() == 'date'), 'Unknown')

                # Parse date
                try:
                    date_obj = parsedate_to_datetime(date)
                    date_str = date_obj.strftime('%Y-%m-%d')
                except:
                    date_str = '0000-00-00'

                # Sanitize filename parts
                from_clean = sanitize_filename_part(from_email, 60)
                subject_clean = sanitize_filename_part(subject, 80)

                # Filename format: {account}_{date}__{from}__{subject}
                base_filename = f"{account_name}_{date_str}__{from_clean}__{subject_clean}"

                # Save as .EML
                eml_path = output_path / f"{base_filename}.eml"

                # Get raw email
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

                json_path = output_path / f"{base_filename}.json"
                json_path.write_text(json.dumps(email_metadata, indent=2, ensure_ascii=False), encoding='utf-8')

                print(f"  [{idx:3d}/{len(messages):3d}] ✅ {subject[:50]}")

            except Exception as e:
                print(f"  [{idx:3d}/{len(messages):3d}] ❌ Error: {e}")

        print(f"\n✅ {len(messages)} emails opgeslagen in: {output_path}")
        return len(messages)

    except HttpError as error:
        print(f'❌ HTTP Error bij ophalen emails: {error}')
        return 0

def main():
    """Main functie"""
    print("=" * 70)
    print("  Arjan Emails Import Tool v2.0")
    print("  Output format: EML + JSON (zoals gemeente_emails)")
    print("=" * 70)

    output_dir = Path('C:/arjan_emails')
    total_emails = 0
    results = {}

    # Accounts om te importeren (kan later uitgebreid worden met info@martiendejong.nl)
    accounts_to_import = ['gmail']  # Later: 'martiendejong'

    for account_key in accounts_to_import:
        account_config = EMAIL_ACCOUNTS[account_key]
        account_name = account_config['account']

        print(f"\n{'#'*70}")
        print(f"# Mailbox: {account_name}")
        print(f"{'#'*70}")

        # Authenticatie
        service = get_gmail_service(account_key)

        if not service:
            print(f"❌ Authenticatie mislukt voor {account_name}")
            results[account_name] = 'FAILED - Authentication'
            continue

        print(f"✅ Authenticatie succesvol voor {account_name}")

        # Import voor elke contactgroep
        account_total = 0
        for contact_group in CONTACTS.keys():
            count = download_emails(service, account_name, contact_group, output_dir)
            account_total += count

        total_emails += account_total
        results[account_name] = f'{account_total} emails'

    # Summary
    print(f"\n{'='*70}")
    print("  IMPORT SAMENVATTING")
    print(f"{'='*70}")
    for account, result in results.items():
        print(f"  {account:40s} : {result}")
    print(f"{'='*70}")
    print(f"  TOTAAL: {total_emails} emails geïmporteerd")
    print(f"{'='*70}")
    print(f"\n📁 Locatie: {output_dir}")
    print("\n💡 Volgende stappen:")
    print("   1. Upload je ChatGPT conversations naar: chatgpt_conversations/")
    print("   2. Controleer de geïmporteerde emails per contactpersoon")
    print("   3. Voeg eventueel extra email adressen toe in het script\n")

if __name__ == '__main__':
    main()
