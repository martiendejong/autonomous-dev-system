---
name: browse-awareness
description: Gentle awareness tool for prolonged passive browsing detection. Provides non-invasive reminders when extended passive consumption is detected. Use when setting up mental health support or discussing browsing habits.
version: 1.0.0
author: Claude Agent
tags: [mental-health, awareness, browsing, self-care, productivity]
activation:
  triggers:
    - browsing awareness
    - passive browsing
    - mental health monitoring
    - browse reminder
    - mindful browsing
    - verdoving detectie
    - bewustwording
---

# Browse Awareness - Zachte Bewustwording voor Passief Browsen

## Filosofie

> Browsen is geen fout gedrag, maar een **signaal**.
> De tool maakt het signaal zichtbaar, op het juiste moment, met minimale verstoring.

Dit systeem respecteert autonomie volledig:
- **Geen blokkades** - Niets wordt afgesloten of geblokkeerd
- **Geen controle** - Geen afdwinging, alleen bewustwording
- **Geen moraliseren** - Neutraal, feitelijk, spiegelend

## Wanneer te Gebruiken

Dit systeem is ontworpen voor situaties van:
- Hoge cognitieve belasting (veel programmeren, complexe verantwoordelijkheid)
- Weinig externe regulatie of sociale buffering
- Neiging tot mentale verdoving bij overbelasting

Passief internetgebruik (browsen, video's kijken, doelloos scrollen) is dan geen neutrale activiteit, maar een vroeg signaal van mentale overloop.

## Snelstart

```powershell
# Start achtergrond monitoring
C:\scripts\tools\browse-awareness.ps1 -Action start

# Eenmalige check
C:\scripts\tools\browse-awareness.ps1 -Action check

# Status bekijken
C:\scripts\tools\browse-awareness.ps1 -Action status

# Test notificatie
C:\scripts\tools\browse-awareness.ps1 -Action test
```

## Configuratie

| Parameter | Default | Beschrijving |
|-----------|---------|--------------|
| ThresholdMinutes | 45 | Minuten passief browsen voor eerste herinnering |
| IntervalMinutes | 15 | Minuten tussen herinneringen |
| QuietHoursStart | 23 | Stille uren start (geen notificaties) |
| QuietHoursEnd | 7 | Stille uren einde |

**Voorbeeld met aangepaste drempel:**
```powershell
browse-awareness.ps1 -Action start -ThresholdMinutes 30 -IntervalMinutes 10
```

## Detectie Logica

### Passieve Sites (worden gedetecteerd)
- Video platforms: YouTube, Netflix, Twitch, Vimeo
- Social media: Facebook, Twitter/X, Instagram, TikTok, Reddit, LinkedIn
- News aggregators: HackerNews, NU.nl, NOS.nl
- Content consumption: Medium, Substack, Tumblr, Pinterest

### Productieve Sites (worden uitgesloten)
- Development: GitHub, GitLab, StackOverflow
- Documentation: docs.microsoft.com, learn.microsoft.com
- AI tools: Claude.ai, ChatGPT
- Work tools: Jira, ClickUp, Notion, Figma, Confluence

### Patroon Herkenning
1. **Tijd** - Pas na threshold (default 45 min) van continue passief browsen
2. **Activiteit** - System idle > 5 min reset de teller
3. **Context** - Laat op de avond (22:00+) gebruikt andere berichten
4. **Interval** - Niet vaker dan elke 15 minuten

## Notificatie Stijl

**Berichten zijn altijd:**
- Feitelijk: "Dit lijkt op langdurig passief browsen (45 min)."
- Neutraal: Geen "je zou moeten..." of "je doet het verkeerd"
- Kort: Één observatie, optioneel één suggestie

**Alternatieve suggesties (optioneel bijgevoegd):**
- "Even opstaan en bewegen kan helpen."
- "Misschien even de ogen sluiten, niets doen."
- "Een korte ademhalingsoefening kan reset geven."
- "Naar buiten kijken, focus loslaten."
- "Even water drinken, lichaam voelen."
- "Niets is ook iets."

## Autostart (Optioneel)

### Via Startup Folder
```powershell
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\BrowseAwareness.lnk")
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-WindowStyle Hidden -File C:\scripts\tools\browse-awareness.ps1 -Action start"
$Shortcut.Save()
```

### Via Scheduled Task
```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-WindowStyle Hidden -File C:\scripts\tools\browse-awareness.ps1 -Action start"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Limited
Register-ScheduledTask -TaskName "BrowseAwareness" -Action $action -Trigger $trigger -Principal $principal
```

## Logs & State

- **Config:** `%LOCALAPPDATA%\ClaudeAgent\browse-awareness-config.json`
- **State:** `%LOCALAPPDATA%\ClaudeAgent\browse-awareness-state.json`
- **Log:** `%LOCALAPPDATA%\ClaudeAgent\browse-awareness.log`

## Succesdefinitie

Het systeem is succesvol als:
- Je eerder merkt dat je in passief verdovingsgedrag zit
- Het gedrag vaker vanzelf stopt of pauzeert
- De overgang naar overbelasting minder vaak escaleert
- **Zonder** dat je je gecontroleerd, gefrustreerd of tegengewerkt voelt

Niet als browsen volledig verdwijnt.

## Integratie met Claude Agent

Bij sessie-start kan Claude checken:
```powershell
# Check huidige staat
browse-awareness.ps1 -Action status

# Als passief browsen gedetecteerd:
# Claude kan dit meewegen in interactie-stijl
```

## Troubleshooting

**Notificaties komen niet door:**
1. Check Windows Focus Assist instellingen
2. Check of app toegestaan is voor notificaties
3. Probeer `browse-awareness.ps1 -Action test`

**Te veel notificaties:**
- Verhoog `ThresholdMinutes` (bijv. 60)
- Verhoog `IntervalMinutes` (bijv. 30)

**Te weinig detectie:**
- De tool detecteert alleen browser-windows
- Productive sites zijn uitgesloten
- System idle > 5 min reset de teller

---

*"Bewustwording, geen controle."*
