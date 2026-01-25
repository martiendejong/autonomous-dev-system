# Actiepunten - Arjan Stroeve Situatie

**Laatste Update:** 20 januari 2026
**Doel:** Gestructureerd plan voor opheldering en afhandeling

---

## 🎯 Overzicht Status

| Categorie | Status | Prioriteit | Deadline |
|-----------|--------|------------|----------|
| Email Import | 🔴 Niet gestart | 🔴 URGENT | 22-01-2026 |
| ChatGPT Upload | 🔴 Niet gestart | 🟠 Hoog | 24-01-2026 |
| Tijdlijn Analyse | ⏳ Wacht op data | 🟠 Hoog | 27-01-2026 |
| Vragen Beantwoorden | ⏳ Wacht op data | 🟡 Middel | 31-01-2026 |
| Besluit Contact Arjan | ⏳ Wacht op analyse | 🟢 Laag | TBD |

---

## 🔴 FASE 1: Data Verzameling (URGENT - Deze Week)

### 1.1 Email Import ⚠️ HOOGSTE PRIORITEIT
**Deadline:** 22 januari 2026 (woensdag)
**Status:** 🔴 Niet gestart

**Acties:**
- [ ] Gmail inloggen (martiendejong2008@gmail.com)
- [ ] Zakelijk email inloggen (info@martiendejong.nl)
- [ ] Zoeken naar emails van/naar:
  - [ ] Arjan Stroeve (email adres nog bepalen)
  - [ ] Rinus Huisman / Socranext
  - [ ] Allan Drenth
  - [ ] Social Media Hulp
  - [ ] Eethuys de Steen

**Zoektermen Gmail:**
```
from:arjan OR to:arjan
from:stroeve OR to:stroeve
subject:Cassandra
subject:"Eethuys de Steen"
subject:"Social Media Hulp"
from:socranext OR to:socranext
from:rinus OR to:rinus
from:allan.drenth OR to:allan.drenth
after:2022/01/01 before:2026/01/20
```

**Tool gebruiken:**
```bash
python C:\scripts\tools\import-arjan-emails-v2.py
```

**Output locatie:**
- `C:\scripts\arjan_emails\emails\`
- Bestandsnaam formaat: `YYYY-MM-DD_HHMMSS_[onderwerp].eml`

**Verwacht resultaat:**
- Alle emails chronologisch opgeslagen
- email_index.txt gegenereerd
- Minimaal geschatte aantal: 20-100 emails

---

### 1.2 ChatGPT Conversations Upload
**Deadline:** 24 januari 2026 (vrijdag)
**Status:** 🔴 Niet gestart

**Acties:**
- [ ] ChatGPT geschiedenis bekijken (chat.openai.com)
- [ ] Zoeken naar conversations over:
  - [ ] Project Cassandra
  - [ ] Arjan Stroeve
  - [ ] Social Media Hulp
  - [ ] Eethuys de Steen
  - [ ] Socranext / Rinus
  - [ ] Brand2Boost (indien Arjan vermeld)

**Export methode:**
- [ ] ChatGPT > Settings > Data Controls > Export data
- [ ] Of: handmatig copy-paste relevante conversations

**Opslaan als:**
- `C:\scripts\arjan_emails\chatgpt_conversations\[onderwerp]_[datum].md`
- Markdown formaat (voor leesbaarheid)

**Metadata toevoegen:**
```markdown
# [Onderwerp]
**Datum conversatie:** [DD-MM-YYYY]
**ChatGPT versie:** [GPT-3.5 / GPT-4 / etc]
**Context:** [Korte beschrijving]

---

[Conversatie hier...]
```

---

### 1.3 Documenten Zoeken
**Deadline:** 24 januari 2026
**Status:** 🔴 Niet gestart

**Acties:**
- [ ] Zoeken in C:\Users\HP\Documents\ naar:
  - [ ] Contract Cassandra
  - [ ] Projectdocumentatie
  - [ ] Facturen
  - [ ] Meeting notes
  - [ ] Code documentatie

**Zoektermen File Explorer:**
- Cassandra
- Arjan
- Stroeve
- "Social Media Hulp"
- "Eethuys de Steen"
- Contract
- Factuur

**Gevonden bestanden kopiëren naar:**
- `C:\scripts\arjan_emails\documenten\`

---

### 1.4 Eigen Geheugen/Aantekeningen
**Deadline:** 24 januari 2026
**Status:** 🔴 Niet gestart

**Acties:**
- [ ] Schrijf alles op wat je je herinnert over:
  - Hoe je Arjan leerde kennen
  - Eerste gesprek over Cassandra
  - Belangrijke meetings/momenten
  - Conflicten/problemen
  - Positieve ervaringen
  - Huidige status

**Opslaan als:**
- `C:\scripts\arjan_emails\EIGEN_HERINNERINGEN.md`

**Structuur:**
```markdown
# Eigen Herinneringen - Arjan Stroeve

## Hoe We Elkaar Leerden Kennen
[Beschrijving...]

## Project Cassandra
### Start
[Beschrijving...]

### Ontwikkeling
[Beschrijving...]

### Problemen
[Beschrijving...]

### Afronding
[Beschrijving...]

## Huidige Situatie
[Beschrijving...]
```

---

## 🟠 FASE 2: Analyse & Structuur (Volgende Week)

### 2.1 Tijdlijn Completeren
**Deadline:** 27 januari 2026 (maandag)
**Status:** ⏳ Wacht op FASE 1 data
**Afhankelijk van:** Email import (1.1)

**Acties:**
- [ ] Alle emails chronologisch doorlezen
- [ ] Belangrijke data/momenten markeren
- [ ] TIJDLIJN_ARJAN_STROEVE_COMPLEET.md vullen
- [ ] Referenties naar emails toevoegen

**Structuur tijdlijn:**
- Chronologische volgorde (2022 → 2026)
- Per maand: belangrijkste gebeurtenissen
- Email referenties: `[Email 15-03-2022: Onderwerp]`
- Crisis momenten markeren met ⚠️
- Positieve momenten markeren met ✅

**Voorbeeld entry:**
```markdown
### Maart 2022 - Eerste Contact

**15 maart 2022** - Eerste email van Arjan
- Email: `2022-03-15_143522_Voorstel AI Chatbot.eml`
- Inhoud: Arjan stelt voor om AI chatbot te maken voor Eethuys de Steen
- Context: Via Social Media Hulp als tussenpersoon
- Status: Positief ontvangen, interesse getoond
```

---

### 2.2 Vragen Beantwoorden
**Deadline:** 29 januari 2026
**Status:** ⏳ Wacht op data
**Afhankelijk van:** Email import, ChatGPT upload

**Acties:**
- [ ] Open `OPENSTAANDE_VRAGEN.md`
- [ ] Ga door alle categorieën
- [ ] Vul in waar mogelijk op basis van:
  - Emails
  - ChatGPT conversations
  - Eigen herinneringen
  - Gevonden documenten

**Markering systeem:**
- ✅ Vraag beantwoord met zekerheid
- 🟡 Vraag deels beantwoord / onzeker
- ❌ Vraag niet te beantwoorden met beschikbare data
- ❓ Vraag vereist directe communicatie met Arjan

**Na invullen:**
- [ ] Tel aantal beantwoorde vragen
- [ ] Lijst maken van kritieke onbeantwoorde vragen
- [ ] Beslissen: welke vragen MOETEN beantwoord worden?

---

### 2.3 Analyse Document Maken
**Deadline:** 31 januari 2026
**Status:** ⏳ Wacht op tijdlijn + vragen
**Afhankelijk van:** 2.1, 2.2

**Template:** Gebruik structuur van `C:\gemeente_emails\NEUTRALE_ANALYSE_CASE_MARTIEN_SOFY.md`

**Acties:**
- [ ] Creëer `ANALYSE_RELATIE_ARJAN_STROEVE.md`
- [ ] Schrijf neutrale analyse met secties:
  - Situatiebeschrijving
  - Chronologisch verloop
  - Sterke punten relatie
  - Zwakke punten / problemen
  - Financiële aspecten
  - Juridische aspecten
  - Risico's
  - Kansen
  - Aanbevelingen

**Toon:**
- Objectief (niet emotioneel)
- Feitelijk (gebaseerd op emails/documenten)
- Balanced (zowel positief als negatief)

---

### 2.4 Samenvatting Maken
**Deadline:** 31 januari 2026
**Status:** ⏳ Wacht op analyse

**Acties:**
- [ ] Creëer `SAMENVATTING_SITUATIE_ARJAN.md`
- [ ] Maximum 1 A4 (zoals gemeente_emails samenvatting)
- [ ] Bevat:
  - Kern van de situatie
  - Huidige status
  - Belangrijkste openstaande vragen
  - Aanbevolen acties

**Doel:**
- Snel overzicht voor Corina/Suzanne (indien ondersteuning nodig)
- Eigen quick-reference
- Basis voor gesprek met Arjan (indien contact)

---

## 🟡 FASE 3: Besluitvorming (Begin Februari)

### 3.1 Review Documentatie
**Deadline:** 3 februari 2026
**Status:** ⏳ Pending

**Acties:**
- [ ] Lees alle gegenereerde documenten door
- [ ] Check op inconsistenties
- [ ] Verify feiten waar mogelijk
- [ ] Update waar nodig

**Checklist:**
- [ ] TIJDLIJN_ARJAN_STROEVE_COMPLEET.md volledig?
- [ ] OPENSTAANDE_VRAGEN.md maximaal ingevuld?
- [ ] ANALYSE_RELATIE_ARJAN_STROEVE.md objectief en compleet?
- [ ] SAMENVATTING_SITUATIE_ARJAN.md helder?
- [ ] Alle emails correct gearchiveerd?

---

### 3.2 Bespreking met Corina (WMO)
**Deadline:** 5 februari 2026 (tijdens reguliere afspraak)
**Status:** ⏳ Pending
**Optioneel:** Alleen indien emotionele/praktische ondersteuning gewenst

**Voorbereiding:**
- [ ] Print `SAMENVATTING_SITUATIE_ARJAN.md`
- [ ] Markeer belangrijkste punten
- [ ] Lijst maken van waar je hulp bij nodig hebt

**Bespreken:**
- [ ] Emotionele impact van situatie
- [ ] Hulp nodig bij besluitvorming?
- [ ] Moet Suzanne (WMO consulent) betrokken worden?
- [ ] Praktische ondersteuning (bijv. email schrijven naar Arjan)

---

### 3.3 Besluit: Actie of Geen Actie?
**Deadline:** 7 februari 2026
**Status:** ⏳ Pending

**Opties:**

**Optie A: Contact Opnemen met Arjan**
- [ ] Email schrijven
- [ ] Telefoon bellen
- [ ] Meeting voorstellen
- **Doel:** _________________
- **Vragen stellen:** _________________
- **Uitkomst verwacht:** _________________

**Optie B: Juridisch Advies Inwinnen**
- [ ] Advocaat raadplegen
- **Reden:** _________________
- **Kosten:** € _________ (schatting)
- **Verwacht resultaat:** _________________

**Optie C: Laten Rusten**
- [ ] Documentatie archiveren
- [ ] Geen verdere actie
- [ ] Focus op Brand2Boost
- **Reden:** _________________

**Optie D: Anders**
- [ ] Omschrijving: _________________

**Beslissingsmatrix:**
| Factor | Optie A | Optie B | Optie C | Optie D |
|--------|---------|---------|---------|---------|
| Urgentie | | | | |
| Kosten | | | | |
| Emotionele impact | | | | |
| Kans op succes | | | | |
| Risico | | | | |

**Finale beslissing:** _________________ (datum: _______)

---

## 🟢 FASE 4: Uitvoering (Indien Optie A of B)

### 4.1 Contact met Arjan (Indien Optie A)
**Datum gepland:** _________________
**Status:** ⏳ Pending besluit

**Voorbereiding:**
- [ ] Conceptemail/gesprekspunten schrijven
- [ ] Review door Corina (indien gewenst)
- [ ] Emotioneel voorbereid
- [ ] Duidelijke doelen voor gesprek

**Email template:**
```
Onderwerp: [Te bepalen - niet confronterend]

Beste Arjan,

[Vriendelijke opening]

[Korte context: waarom je contact opneemt]

[Concrete vragen/punten]

[Vriendelijke afsluiting]

Met vriendelijke groet,
Martien de Jong
```

**Na contact:**
- [ ] Notities maken van gesprek
- [ ] Email correspondentie opslaan
- [ ] Tijdlijn updaten
- [ ] Volgende stappen bepalen

---

### 4.2 Juridisch Advies (Indien Optie B)
**Datum afspraak:** _________________
**Advocaat:** _________________

**Meenemen naar afspraak:**
- [ ] TIJDLIJN_ARJAN_STROEVE_COMPLEET.md (geprint)
- [ ] ANALYSE_RELATIE_ARJAN_STROEVE.md (geprint)
- [ ] Alle emails (USB stick of geprint)
- [ ] Contract (indien aanwezig)
- [ ] Betalingsbewijzen/facturen
- [ ] Lijst met vragen voor advocaat

**Vragen voor advocaat:**
1. _________________________________________________
2. _________________________________________________
3. _________________________________________________

**Verwachte kosten:** € ___________ (consult)
**Verwacht advies over:** _________________

---

## 📊 Voortgang Tracking

### Week van 20 januari 2026
- [ ] Email import (1.1)
- [ ] ChatGPT upload (1.2)
- [ ] Documenten zoeken (1.3)
- [ ] Eigen herinneringen opschrijven (1.4)

### Week van 27 januari 2026
- [ ] Tijdlijn completeren (2.1)
- [ ] Vragen beantwoorden (2.2)
- [ ] Analyse maken (2.3)
- [ ] Samenvatting maken (2.4)

### Week van 3 februari 2026
- [ ] Documentatie review (3.1)
- [ ] Bespreking Corina (3.2) - optioneel
- [ ] Besluit nemen (3.3)

### Week van 10 februari 2026 (indien nodig)
- [ ] Actie uitvoeren (4.1 of 4.2)

---

## 🎯 Success Criteria

Dit actiepuntenplan is succesvol als:

✅ Alle beschikbare data is verzameld
✅ Volledige tijdlijn is gemaakt
✅ Kritieke vragen zijn beantwoord
✅ Objectieve analyse is gemaakt
✅ Weloverwogen besluit is genomen
✅ Emotionele rust is bereikt
✅ Focus kan weer op Brand2Boost / Sophy / toekomst

---

## 📝 Notities

*(Gebruik voor bijhouden voortgang, insights tijdens proces, etc.)*

```
[Datum] [Notitie]
_________________________________________________
_________________________________________________
_________________________________________________
```

---

**Aangemaakt:** 20 januari 2026
**Eigenaar:** Martien de Jong
**Review frequentie:** Wekelijks (elke maandag)
**Volgende review:** 27 januari 2026
