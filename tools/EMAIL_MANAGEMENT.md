# Email Management Tools

Tools for managing emails via IMAP for `info@martiendejong.nl`.

## Quick Reference (Main Tools)

```powershell
cd C:\scripts\tools

# PowerShell wrapper (recommended)
.\email.ps1 list                      # Show 10 most recent
.\email.ps1 list -Count 5 -Offset 10  # Pagination
.\email.ps1 spam 1234,1235            # Move to spam
.\email.ps1 archive 1234              # Move to archive
.\email.ps1 search "anthropic"        # Search emails
.\email.ps1 folders                   # List folders

# Auto-cleanup (batch spam detection)
node email-cleanup.js                 # Scan & clean spam
node email-cleanup.js --dry-run       # Preview only
node email-cleanup.js --count=100     # Scan more messages

# Direct Node.js usage
node email-manager.js list --count=10 --offset=0
node email-manager.js spam 1234,1235,1236
node email-manager.js archive 1234
node email-manager.js search "query"
```

## Main Tools

| Tool | Purpose |
|------|---------|
| `email.ps1` | **PowerShell wrapper** - easiest to use |
| `email-manager.js` | **Unified manager** - list, spam, archive, search |
| `email-cleanup.js` | **Auto-cleanup** - detect & batch remove spam |

## Legacy Scripts (still work)

| Script | Purpose |
|--------|---------|
| `imap-recent-messages.js` | Show 5 most recent inbox messages |
| `imap-spam-manager.js` | View spam folder, move to trash |
| `imap-next.js` | Move UIDs to spam, show next 5 |
| `imap-action.js` | Move to spam/archive with offset |

## IMAP Configuration

```
Host: mail.zxcs.nl
Port: 993 (SSL/TLS)
User: info@martiendejong.nl
Password: (see C:\scripts\_machine\credentials.md)
```

## Folder Structure

| Folder | Purpose |
|--------|---------|
| INBOX | Main inbox |
| Spam | Spam/junk messages |
| Archive | Archived messages (keep but out of inbox) |
| Trash | Deleted messages |
| Prullenbak | Dutch trash folder |
| Sent | Sent messages |
| Drafts | Draft messages |

## Workflow: Inbox Cleanup

1. **Start with recent messages:**
   ```powershell
   node imap-recent-messages.js
   ```

2. **Review and categorize:**
   - Important → Keep in inbox
   - Spam/Phishing → Move to Spam
   - Promotional/Archive → Move to Archive

3. **Process batch and continue:**
   ```powershell
   node imap-action.js --spam=UID1,UID2 --archive=UID3 --offset=5
   ```

4. **Repeat** until inbox is clean

## Common Spam Patterns

### Known Spam Domains
- `neooudh.store` - Fake Dutch services (ov-chipkaart, energiescan, alarmsysteem, traprenovatie)
- `rimhasi.com` - Fake Coinbase phishing
- `ekvira.in` - Fake eHerkenning phishing
- `firebaseapp.com` - Fake ChatGPT/subscription scams
- `autoserve1.com` - Crypto scams ($PENGU tokens)
- `ilovepdf.lat` - Fake alarmsysteem
- `moochmarod.ae` - Fake TEMU
- `khouchona.com` - Fake Bol.com
- `refinhajoune.com` - Fake KPN
- Random gmail addresses with job applications (e.g., sumitpaul202512@gmail.com)

### Legitimate Senders to Keep
- `@anthropic.com`, `@mail.anthropic.com` - Claude/Anthropic (important)
- `@google.com` - Google services
- `@kenya-airways.com` - Kenya Airways travel notifications
- `@perridon.com` - Sjoerd Schepman (important contact)
- `@meppel.nl` - Municipality Meppel
- `@volgjewoning.nl` - Housing notifications (important)
- `@scauting.nl` - Corina van den Bosch
- `@IND.nl` - Dutch Immigration (important, government)
- `@lovable.dev` - Lovable (archive, not spam)
- `@brainito.com` - Spam (promotional)
- `@whitepress.com` - Spam (marketing)
- `@gmail.com` from Martien de Jong - Own forwarded emails
- `@gmail.com` from Mang'abo Momanyi - Important contact (NDA)

### LinkedIn
- User preference: LinkedIn notifications → Spam
- Exception: Direct messages from known contacts

## Session Summary Template

After cleanup session, record:
- Messages reviewed: X
- Moved to spam: X
- Moved to archive: X
- Important kept: X

## Credentials Location

See `C:\scripts\_machine\credentials.md` for:
- IMAP password
- SMTP password (different!)

---
*Last updated: 2026-01-14*
*Maintained by: Claude Agent*
