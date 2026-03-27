#!/usr/bin/env python3
"""
Email Import Script - Arjan Stroeve & Gerelateerde Contacten

Dit script importeert emails van/naar:
- Arjan Stroeve
- Allan Drenth
- Rinus Huisman / Socranext
- Social Media Hulp

Van accounts:
- info@martiendejong.nl
- martiendejong2008@gmail.com

Output: C:\arjan_emails\emails\
"""

import imaplib
import email
from email.header import decode_header
import os
from datetime import datetime
import getpass
import re

# Configuratie
OUTPUT_DIR = r"C:\arjan_emails\emails"
ACCOUNTS = [
    {
        "email": "info@martiendejong.nl",
        "imap_server": "imap.gmail.com",  # Aanpassen indien anders
        "imap_port": 993
    },
    {
        "email": "martiendejong2008@gmail.com",
        "imap_server": "imap.gmail.com",
        "imap_port": 993
    }
]

# Zoekfilters - mensen/bedrijven om te zoeken
SEARCH_TERMS = [
    "arjan",
    "stroeve",
    "allan",
    "drenth",
    "rinus",
    "huisman",
    "socranext",
    "socialmediahulp",
    "social media hulp",
    "eethuys de steen",
    "cassandra"
]

def sanitize_filename(filename):
    """Maak bestandsnaam Windows-veilig"""
    # Verwijder ongeldige karakters
    invalid_chars = '<>:"/\\|?*'
    for char in invalid_chars:
        filename = filename.replace(char, '_')
    # Beperk lengte
    if len(filename) > 200:
        filename = filename[:200]
    return filename

def decode_mime_words(s):
    """Decode MIME encoded strings"""
    decoded_string = ''
    try:
        for part, encoding in decode_header(s):
            if isinstance(part, bytes):
                decoded_string += part.decode(encoding or 'utf-8', errors='ignore')
            else:
                decoded_string += part
    except:
        decoded_string = str(s)
    return decoded_string

def connect_imap(email_address, password, imap_server, imap_port):
    """Verbind met IMAP server"""
    print(f"\nVerbinden met {imap_server} voor {email_address}...")
    try:
        mail = imaplib.IMAP4_SSL(imap_server, imap_port)
        mail.login(email_address, password)
        print(f"✓ Succesvol ingelogd als {email_address}")
        return mail
    except imaplib.IMAP4.error as e:
        print(f"✗ Login fout: {e}")
        print("  Mogelijke oorzaken:")
        print("  - Verkeerd wachtwoord")
        print("  - 2FA ingeschakeld (gebruik app-specific password)")
        print("  - IMAP niet ingeschakeld in account instellingen")
        return None

def search_emails(mail, search_terms):
    """Zoek emails met OR query voor alle zoektermen"""
    # Selecteer inbox en all mail
    folders_to_search = ['INBOX', '[Gmail]/All Mail', 'All Mail']

    all_email_ids = []

    for folder in folders_to_search:
        try:
            mail.select(folder)
            print(f"\n  Zoeken in folder: {folder}")
        except:
            continue

        # Zoek voor elke term
        for term in search_terms:
            queries = [
                f'(OR FROM "{term}" TO "{term}")',
                f'(OR CC "{term}" BCC "{term}")',
                f'(SUBJECT "{term}")',
                f'(BODY "{term}")'
            ]

            for query in queries:
                try:
                    status, messages = mail.search(None, query)
                    if status == 'OK':
                        msg_ids = messages[0].split()
                        if msg_ids:
                            all_email_ids.extend(msg_ids)
                            print(f"    '{term}' ({query[:20]}...): {len(msg_ids)} emails")
                except Exception as e:
                    continue

    # Verwijder duplicaten
    unique_ids = list(set(all_email_ids))
    print(f"\n  Totaal unieke emails gevonden: {len(unique_ids)}")
    return unique_ids

def download_email(mail, email_id, output_dir, account_email):
    """Download en save een enkele email"""
    try:
        status, msg_data = mail.fetch(email_id, '(RFC822)')
        if status != 'OK':
            return False

        # Parse email
        email_body = msg_data[0][1]
        message = email.message_from_bytes(email_body)

        # Haal metadata op
        subject = decode_mime_words(message.get('Subject', 'No Subject'))
        from_addr = decode_mime_words(message.get('From', 'Unknown'))
        date_str = message.get('Date', '')

        # Parse datum voor bestandsnaam
        try:
            date_tuple = email.utils.parsedate_tz(date_str)
            if date_tuple:
                timestamp = email.utils.mktime_tz(date_tuple)
                date_obj = datetime.fromtimestamp(timestamp)
                date_formatted = date_obj.strftime('%Y-%m-%d_%H%M%S')
            else:
                date_formatted = datetime.now().strftime('%Y-%m-%d_%H%M%S')
        except:
            date_formatted = datetime.now().strftime('%Y-%m-%d_%H%M%S')

        # Maak bestandsnaam
        subject_clean = sanitize_filename(subject)
        filename = f"{date_formatted}_{subject_clean[:80]}.eml"
        filepath = os.path.join(output_dir, filename)

        # Check of bestand al bestaat
        counter = 1
        original_filepath = filepath
        while os.path.exists(filepath):
            name, ext = os.path.splitext(original_filepath)
            filepath = f"{name}_{counter}{ext}"
            counter += 1

        # Save email
        with open(filepath, 'wb') as f:
            f.write(email_body)

        print(f"  ✓ {date_formatted} - {subject[:60]}")
        return True

    except Exception as e:
        print(f"  ✗ Error downloading email {email_id}: {e}")
        return False

def import_from_account(account_config, search_terms, output_dir):
    """Import emails from één account"""
    email_address = account_config['email']

    print(f"\n{'='*60}")
    print(f"Account: {email_address}")
    print(f"{'='*60}")

    # Vraag wachtwoord
    password = getpass.getpass(f"Wachtwoord voor {email_address}: ")

    # Verbind
    mail = connect_imap(
        email_address,
        password,
        account_config['imap_server'],
        account_config['imap_port']
    )

    if not mail:
        print(f"✗ Kon niet verbinden met {email_address}")
        return 0

    # Zoek emails
    email_ids = search_emails(mail, search_terms)

    if not email_ids:
        print(f"Geen emails gevonden voor {email_address}")
        mail.logout()
        return 0

    # Download emails
    print(f"\nDownloading {len(email_ids)} emails...")
    success_count = 0

    for i, email_id in enumerate(email_ids, 1):
        print(f"\n[{i}/{len(email_ids)}]", end=" ")
        if download_email(mail, email_id, output_dir, email_address):
            success_count += 1

    mail.logout()

    print(f"\n✓ Succesvol gedownload: {success_count}/{len(email_ids)} emails")
    return success_count

def create_index(output_dir):
    """Maak index bestand van alle emails"""
    emails = sorted([f for f in os.listdir(output_dir) if f.endswith('.eml')])

    index_file = os.path.join(output_dir, 'email_index.txt')
    with open(index_file, 'w', encoding='utf-8') as f:
        f.write(f"Email Index - Arjan Stroeve & Gerelateerde Contacten\n")
        f.write(f"Gegenereerd: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Totaal emails: {len(emails)}\n")
        f.write("="*80 + "\n\n")

        for email_file in emails:
            f.write(f"{email_file}\n")

    print(f"\n✓ Index aangemaakt: {index_file}")
    print(f"  Totaal emails in index: {len(emails)}")

def main():
    """Main functie"""
    print("""
╔═══════════════════════════════════════════════════════════╗
║  Email Import - Arjan Stroeve & Gerelateerde Contacten   ║
╚═══════════════════════════════════════════════════════════╝

Zoekt naar emails van/naar:
  • Arjan Stroeve
  • Allan Drenth
  • Rinus Huisman / Socranext
  • Social Media Hulp
  • Eethuys de Steen
  • Cassandra project

Van accounts:
  • info@martiendejong.nl
  • martiendejong2008@gmail.com

Output: {OUTPUT_DIR}
""")

    # Maak output directory
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"✓ Output directory: {OUTPUT_DIR}\n")

    # Import van elk account
    total_imported = 0
    for account in ACCOUNTS:
        count = import_from_account(account, SEARCH_TERMS, OUTPUT_DIR)
        total_imported += count

    # Maak index
    if total_imported > 0:
        create_index(OUTPUT_DIR)

    # Samenvatting
    print(f"\n{'='*60}")
    print(f"SAMENVATTING")
    print(f"{'='*60}")
    print(f"Totaal geïmporteerde emails: {total_imported}")
    print(f"Locatie: {OUTPUT_DIR}")

    if total_imported > 0:
        print(f"\nVolgende stappen:")
        print(f"1. Check emails in: {OUTPUT_DIR}")
        print(f"2. Lees email_index.txt voor overzicht")
        print(f"3. Update TIJDLIJN_ARJAN_STROEVE_COMPLEET.md")
        print(f"4. Vul OPENSTAANDE_VRAGEN.md in")
    else:
        print("\n⚠ Geen emails gevonden!")
        print("Mogelijke oorzaken:")
        print("  - Geen emails van deze contacten in accounts")
        print("  - IMAP niet correct geconfigureerd")
        print("  - Zoektermen niet correct")

    print()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nAfgebroken door gebruiker.")
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
