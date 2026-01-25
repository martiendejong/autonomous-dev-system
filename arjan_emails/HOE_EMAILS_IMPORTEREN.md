# Hoe Emails Importeren - Stap voor Stap

**Doel:** Alle emails van/naar Arjan, Allan, Rinus en Social Media Hulp importeren

---

## 🚀 Snelle Start (3 Opties)

### Optie 1: Python Script (AANBEVOLEN)
**Tijd:** 5-10 minuten
**Gemakkelijk:** Automatisch

```bash
cd C:\scripts\tools
python import-arjan-emails.py
```

Het script vraagt om wachtwoorden voor beide accounts en doet de rest automatisch.

---

### Optie 2: Gmail Web Interface (Handmatig)
**Tijd:** 15-30 minuten
**Gemakkelijk:** Klik & download

**Stappen:**

1. **Ga naar Gmail** (info@martiendejong.nl)
2. **Zoek:**
   ```
   from:arjan OR to:arjan OR from:allan OR to:allan OR from:rinus OR to:rinus OR from:socialmediahulp OR to:socialmediahulp
   ```
3. **Selecteer alle** (checkbox boven)
4. **Klik:** Meer (drie puntjes) → Berichten downloaden
5. **Save in:** `C:\scripts\arjan_emails\emails\`

6. **Herhaal voor** martiendejong2008@gmail.com

---

### Optie 3: Gmail Takeout (Complete Export)
**Tijd:** Enkele uren (wachttijd)
**Gemakkelijk:** Volledigst maar traag

1. **Ga naar:** https://takeout.google.com
2. **Selecteer:** Gmail
3. **Downloadformaat:** MBOX of EML
4. **Start export**
5. **Wacht op email** met downloadlink
6. **Download & extract** naar `C:\scripts\arjan_emails\emails\`

---

## 📝 Optie 1 Details: Python Script

### Vereisten
- Python 3.x geïnstalleerd (check: `python --version`)
- Internet verbinding
- Email wachtwoorden klaar

### Als 2FA (Twee-Factor Authenticatie) Aan Staat

**Voor Gmail accounts met 2FA:**

1. **Ga naar:** https://myaccount.google.com/apppasswords
2. **Log in** met je Gmail account
3. **Select app:** Mail
4. **Select device:** Windows Computer
5. **Klik:** Generate
6. **Kopieer** het 16-character wachtwoord
7. **Gebruik dit** in plaats van je normale wachtwoord

**Herhaal voor beide accounts:**
- info@martiendejong.nl
- martiendejong2008@gmail.com

### Script Uitvoeren

```bash
# Open PowerShell of Command Prompt
cd C:\scripts\tools

# Run script
python import-arjan-emails.py
```

**Script zal vragen:**
```
Wachtwoord voor info@martiendejong.nl: [typ hier]
Wachtwoord voor martiendejong2008@gmail.com: [typ hier]
```

**Output:**
- Emails worden opgeslagen in: `C:\scripts\arjan_emails\emails\`
- Bestandsnaam formaat: `YYYY-MM-DD_HHMMSS_[onderwerp].eml`
- Index bestand: `email_index.txt`

### Wat Het Script Doet

1. ✅ Verbindt met Gmail IMAP servers
2. ✅ Zoekt in ALLE folders (Inbox, Sent, All Mail)
3. ✅ Zoekt naar:
   - arjan, stroeve
   - allan, drenth
   - rinus, huisman, socranext
   - socialmediahulp, social media hulp
   - eethuys de steen
   - cassandra

4. ✅ Download alle gevonden emails
5. ✅ Save als .eml bestanden (met tijdstempel)
6. ✅ Maakt index bestand

---

## ⚠️ Troubleshooting

### Probleem: "Login Error"

**Oplossing:**
1. Check of IMAP ingeschakeld is:
   - Gmail → Settings → Forwarding and POP/IMAP
   - Enable IMAP

2. Als 2FA aan staat: gebruik App Password (zie boven)

3. Check wachtwoord (typ opnieuw)

---

### Probleem: "No emails found"

**Mogelijke oorzaken:**
1. **Emails zijn er niet** - Check handmatig in Gmail
2. **Verkeerde zoekterm** - Probeer één term tegelijk
3. **Andere folder** - Emails in Archive/Trash?

**Handmatig checken:**
```
Gmail → Zoekbalk → typ: from:arjan
```

Als je WEL emails ziet, maar script vindt ze niet → Gebruik Optie 2 (handmatig)

---

### Probleem: "Permission Denied"

**Oplossing:**
```bash
# Run als Administrator
# Rechtermuisknop op PowerShell → Run as Administrator
cd C:\scripts\tools
python import-arjan-emails.py
```

---

## 📊 Na Import - Verificatie

### Check 1: Aantal Emails
```bash
cd C:\scripts\arjan_emails\emails
ls *.eml | wc -l
```

**Verwacht:** Minimaal 10-20 emails (schatting)

### Check 2: Bekijk Index
```bash
notepad email_index.txt
```

**Zou moeten tonen:** Alle email bestandsnamen chronologisch

### Check 3: Open Eerste Email
```bash
# Dubbel-klik op een .eml bestand
# Opent in Outlook / Windows Mail / Default email app
```

---

## 🎯 Volgende Stappen Na Succesvolle Import

1. **✅ Emails geïmporteerd** → Check email_index.txt

2. **📖 Lees emails chronologisch**
   - Start met oudste (2022)
   - Let op: namen, data, projecten

3. **📝 Update documenten:**
   - `TIJDLIJN_ARJAN_STROEVE_COMPLEET.md` - Vul tijdlijn
   - `OPENSTAANDE_VRAGEN.md` - Beantwoord vragen
   - `EIGEN_HERINNERINGEN.md` - Noteer wat je ziet

4. **🔍 Zoek naar:**
   - Contract (als attachment)
   - Facturen (als attachment)
   - Belangrijke data (start project, einde, etc.)
   - Betalingen mentions
   - Conflicten / problemen

5. **📊 Analyse:**
   - Hoe vaak contact?
   - Toon van emails (vriendelijk/zakelijk/gespannen)?
   - Laatste email wanneer?
   - Openstaande zaken?

---

## 💡 Tips

### Efficiënt Emails Lezen

**Sorteer op datum:**
```bash
# In File Explorer
C:\scripts\arjan_emails\emails\
Sorteer: Datum (oudste eerst)
```

**Begin met oudste email** (eerste contact)
- Geeft context voor rest

**Let op email threads:**
- Subject: "Re: ..." is antwoord op eerder email
- Lees threads in volgorde

### Notities Maken

**Tijdens lezen emails:**
```markdown
# Email Notities

## 2022-03-15 - Eerste Contact
Email: 2022-03-15_143522_Voorstel AI Chatbot.eml
Van: Arjan Stroeve
Aan: info@martiendejong.nl
Inhoud: Arjan stelt voor om Cassandra te maken
Key points:
- Project voor Eethuys de Steen
- Budget: €XXXX
- Deadline: XX-XX-2022
```

**Save als:** `C:\scripts\arjan_emails\EMAIL_LEESNOTITIES.md`

---

## 🆘 Hulp Nodig?

### Email Import Werkt Niet

**Plan B: Handmatige Download**
1. Gmail website
2. Zoek emails handmatig
3. Selecteer → Download
4. Save in emails/ folder

### Wachtwoord Vergeten

**Reset:**
- info@martiendejong.nl → Provider contacteren
- martiendejong2008@gmail.com → Google account recovery

### Technische Problemen

**Check:**
- Python geïnstalleerd? `python --version`
- Internet verbinding actief?
- Firewall blokkeert script niet?

---

## ⏱️ Tijdsinschatting

| Methode | Tijd |
|---------|------|
| **Python Script** | 5-10 min (automatisch) |
| **Gmail Web** | 15-30 min (handmatig selecteren) |
| **Gmail Takeout** | 1-4 uur (wachttijd op export) |

**Emails lezen & analyseren:** 2-4 uur (afhankelijk van aantal)

---

**Succes met importeren! 📧**
