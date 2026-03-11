# Art Revisionist Case Research Skill

Use when creating or editing content for an Art Revisionist case/investigation. This skill provides the complete workflow for structuring historical research into the Art Revisionist application format.

---

## Overview

Art Revisionist is a research publication platform for historical investigations. Each "case" (like Valsuani, Senufo, CV Martien) has a structured content hierarchy that must be followed exactly for the application to display it correctly.

## Content Hierarchy

```
Case (e.g., "Valsuani")
└── Pages (main topics, 3-6 recommended)
    └── Details (sub-topics per page, 3-6 per page)
        └── Evidence (supporting documents, 0-5 per detail)
            └── Attachments (files, images)
```

## Storage Location

All cases are stored in: `C:\stores\artrevisionist\{CaseName}\`

## Two-File Architecture

Art Revisionist uses **TWO representations** that must stay synchronized:

### 1. `pages.json` - Full Nested Content
The main content file with complete nested structure including all text content.

### 2. `pages/` Folder Structure - Index Files
Navigation index files with id, title, summary only (no full content).

---

## PHASE 1: Content Planning

Before writing any JSON, plan the content structure:

### Step 1.1: Identify Main Argument
- What is the central thesis? (e.g., "Marcello Valsuani never existed")
- What primary sources support this?
- What is the narrative arc?

### Step 1.2: Design Page Structure
Create 3-6 main pages that tell the complete story:

| Page | Purpose | Example |
|------|---------|---------|
| 1 | Hook/Problem Statement | "Who Founded the Valsuani Foundry?" |
| 2 | Historical Background | "Claude Valsuani: Master Bronze Founder" |
| 3 | Technical/Process Context | "Lost-Wax Bronze Casting" |
| 4 | Evidence Archive | "Valsuani Bronze Authentication" |
| 5 | Implications/Legacy | "The Valsuani Legacy" |

### Step 1.3: Map Evidence to Details
For each page, identify:
- Which details need documentary evidence?
- What images/documents support each claim?
- Where are the source files located?

---

## PHASE 2: Create pages.json (Full Content)

### File Location
`C:\stores\artrevisionist\{CaseName}\pages.json`

### Complete JSON Schema

```json
{
  "pages": [
    {
      "id": "1",
      "title": "Page Title (compelling, SEO-friendly)",
      "summary": "2-3 sentence summary of page content",
      "content": "Full markdown content for the page. Can be multiple paragraphs.\n\nUse **bold** for emphasis.\n\n• Bullet points for lists\n\nInclude all narrative text here.",
      "featuredImageFilename": "image.jpeg",
      "wordPressMediaId": null,
      "additionalImages": [],
      "details": [
        {
          "id": "1",
          "title": "Detail Title",
          "summary": "Summary of this detail section",
          "content": "Full content for this detail...",
          "featuredImageFilename": "detail-image.jpeg",
          "wordPressMediaId": null,
          "additionalImages": [],
          "evidence": [
            {
              "id": "evidence-1",
              "title": "Evidence Item Title",
              "summary": "What this evidence proves",
              "content": "Full description of the evidence...",
              "featuredImageFilename": "document.jpeg",
              "wordPressMediaId": null,
              "additionalImages": [],
              "attachments": []
            }
          ]
        }
      ]
    }
  ]
}
```

### Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | String number ("1", "2", etc.) |
| `title` | Yes | Display title, SEO-optimized |
| `summary` | Yes | 1-3 sentences, appears in previews |
| `content` | Yes | Full markdown content |
| `featuredImageFilename` | No | Relative path to image file |
| `wordPressMediaId` | No | WordPress integration ID |
| `additionalImages` | No | Array of additional image paths |
| `details` | Pages only | Array of detail objects |
| `evidence` | Details only | Array of evidence objects |
| `attachments` | Evidence only | Array of attachment objects |

### Image Path Conventions

Images can be stored in several locations:
- Root of case folder: `"image.jpeg"`
- Subfolder: `"office_images\\subfolder\\image.jpeg"`
- Use double backslashes in JSON for Windows paths

---

## PHASE 3: Create Folder Structure (Index Files)

### Directory Structure

```
C:\stores\artrevisionist\{CaseName}\pages\
├── main.json                 (page index)
├── 1\                        (Page 1 folder)
│   ├── details.json          (details index)
│   ├── 1\                    (Detail 1 folder)
│   │   └── evidence.json     (evidence index)
│   ├── 2\
│   │   └── evidence.json
│   └── ...
├── 2\
│   ├── details.json
│   └── ...
└── ...
```

### main.json Format

```json
[
  {
    "id": "1",
    "title": "Page Title",
    "summary": "Page summary"
  },
  {
    "id": "2",
    "title": "Second Page Title",
    "summary": "Second page summary"
  }
]
```

### details.json Format

```json
[
  {
    "id": "1",
    "title": "Detail Title",
    "summary": "Detail summary"
  }
]
```

### evidence.json Format

```json
[
  {
    "id": "evidence-1",
    "title": "Evidence Title",
    "summary": "Evidence summary"
  }
]
```

For details without evidence, use empty array: `[]`

---

## PHASE 4: Execution Commands

### Step 4.1: Create pages.json
Write the full nested JSON to `C:\stores\artrevisionist\{CaseName}\pages.json`

### Step 4.2: Create Page Folders
```bash
mkdir -p "C:\stores\artrevisionist\{CaseName}\pages\1" \
         "C:\stores\artrevisionist\{CaseName}\pages\2" \
         # ... for each page
```

### Step 4.3: Create details.json Files
Write details.json to each page folder.

### Step 4.4: Create Detail Folders
```bash
mkdir -p "C:\stores\artrevisionist\{CaseName}\pages\1\1" \
         "C:\stores\artrevisionist\{CaseName}\pages\1\2" \
         # ... for each detail
```

### Step 4.5: Create evidence.json Files
Write evidence.json to each detail folder (empty `[]` if no evidence).

---

## PHASE 5: Validation Checklist

Before completing, verify:

- [ ] `pages.json` is valid JSON (no trailing commas, proper escaping)
- [ ] All image paths exist and use correct escaping
- [ ] Every page has at least 1 detail
- [ ] Every detail folder has an evidence.json (even if empty)
- [ ] IDs are sequential strings ("1", "2", "3")
- [ ] Evidence IDs use "evidence-N" format
- [ ] Content is substantial (not placeholder text)
- [ ] Folder structure mirrors pages.json hierarchy

---

## Content Writing Guidelines

### Page Titles
- Clear, compelling, SEO-friendly
- Question format works well for hooks ("Who Founded...?")
- Include key terms readers might search

### Summaries
- 1-3 sentences maximum
- Convey the core argument/content
- No cliffhangers - be direct

### Content
- Use markdown formatting
- Break into logical paragraphs
- Use bullet points for lists
- Include relevant quotes from sources
- Bold key terms and names

### Evidence
- Each piece should prove a specific claim
- Include transcription AND translation for foreign documents
- Explain significance explicitly
- Link to the broader argument

---

## Example: Valsuani Case Structure

**Page 1: "Who Founded the Valsuani Foundry?"** (Hook)
- Detail 1: The Marcello Myth Debunked (2 evidence items)
- Detail 2: Carlo Valsuani - The Real Father (3 evidence items)
- Detail 3: Primary Documents Proving the Truth (3 evidence items)

**Page 2: "Claude Valsuani: Master Bronze Founder"** (Biography)
- Detail 1: Early Life in Crescenzago
- Detail 2: Establishing the Paris Foundry
- Detail 3: The Master Sculptors
- Detail 4: Claude's Death
- Detail 5: Marcel Continues the Legacy

**Page 3: "Lost-Wax Bronze Casting"** (Technical Context)
- Detail 1: What Is Lost-Wax Casting?
- Detail 2: The Valsuani Process Step by Step
- Detail 3: Why Valsuani Was Famous
- Detail 4: Valsuani vs Hébrard

**Page 4: "Valsuani Bronze Authentication"** (Evidence Archive)
- Detail 1: Stamps and Signatures
- Detail 2: Birth Certificate Evidence
- Detail 3: Passport Evidence
- Detail 4: Death Certificates
- Detail 5: Business Documents
- Detail 6: Newspaper Articles

**Page 5: "The Valsuani Legacy"** (Implications)
- Detail 1: Valsuani Bronzes in Museums
- Detail 2: Valsuani and Degas
- Detail 3: Why Accurate History Matters

---

## Quick Reference Commands

```powershell
# Check existing case structure
ls "C:\stores\artrevisionist\{CaseName}"

# Validate JSON syntax
cat "C:\stores\artrevisionist\{CaseName}\pages.json" | python -m json.tool

# Count pages, details, evidence
cat "C:\stores\artrevisionist\{CaseName}\pages.json" | jq '.pages | length'

# List all JSON files in structure
find "C:\stores\artrevisionist\{CaseName}\pages" -name "*.json" | sort
```

---

## Troubleshooting

### "File has not been read yet" Error
Always read a file before writing to it (Claude Code requirement).

### JSON Parse Errors
- Check for trailing commas
- Escape backslashes in paths (`\\` not `\`)
- Escape quotes in content (`\"`)
- Use proper newlines in content (`\n`)

### Images Not Displaying
- Verify file exists at specified path
- Check case sensitivity of filename
- Use correct path separator for platform

---

## Related Files

- Reference case: `C:\stores\artrevisionist\CV Martien\`
- Image storage: `C:\stores\artrevisionist\{CaseName}\office_images\`
- Main content: `C:\stores\artrevisionist\{CaseName}\pages.json`

---

*Skill created: 2026-01-29*
*Based on: Valsuani case implementation*
*Author: Claude Agent*
