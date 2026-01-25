# 📋 Exact Overzicht: Te Verwijderen Branches
**Datum:** 2026-01-08
**Status:** Wacht op bevestiging

---

## ⚠️ BELANGRIJK: Worktrees Cleanup Eerst!

Deze branches zitten in actieve worktrees en moeten EERST worktree cleanup krijgen:

### HAZINA Worktrees (5 branches)
```bash
# Worktree locations:
C:/Projects/worker-agents/agent-002/hazina      -> agent-002-context-compression
C:/Projects/worker-agents/agent-003/hazina      -> agent-003-brand-fragments
C:/Projects/worker-agents/agent-005/hazina      -> agent-005-google-drive-hazina
C:/Projects/worker-agents/agent-006/Hazina      -> agent-006-deduplication
C:/Projects/worker-agents/agent-007/hazina-pr4  -> agent-006-workflow-fix

# Cleanup commando's:
cd "C:\Projects\hazina"
git worktree remove "C:/Projects/worker-agents/agent-002/hazina" --force
git worktree remove "C:/Projects/worker-agents/agent-003/hazina" --force
git worktree remove "C:/Projects/worker-agents/agent-005/hazina" --force
git worktree remove "C:/Projects/worker-agents/agent-006/Hazina" --force
git worktree remove "C:/Projects/worker-agents/agent-007/hazina-pr4" --force
```

### CLIENT-MANAGER Worktrees (5 branches)
```bash
# Worktree locations:
C:/Projects/worker-agents/agent-001/client-manager -> agent-001-license-manager
C:/Projects/worker-agents/agent-002/client-manager -> agent-002-fix-registration-duplicate-email
C:/Projects/worker-agents/agent-003/client-manager -> improvement/CM-054-quality-scoring
C:/Projects/worker-agents/agent-004/client-manager -> agent-004-revolutionary-concepts-final
C:/Projects/worker-agents/agent-005/client-manager -> agent-005-google-drive-integration

# Cleanup commando's:
cd "C:\Projects\client-manager"
git worktree remove "C:/Projects/worker-agents/agent-001/client-manager" --force
git worktree remove "C:/Projects/worker-agents/agent-002/client-manager" --force
git worktree remove "C:/Projects/worker-agents/agent-003/client-manager" --force
git worktree remove "C:/Projects/worker-agents/agent-004/client-manager" --force
git worktree remove "C:/Projects/worker-agents/agent-005/client-manager" --force
```

---

## 📊 HAZINA - Te Verwijderen Branches

### Categorie 1: Lokaal + Remote (beide verwijderen)

**Branches (8):**
1. agent-002-context-compression ⚠️ (worktree!)
2. agent-002-tool-agent-3layer
3. agent-003-brand-fragments ⚠️ (worktree!)
4. agent-005-google-drive-hazina ⚠️ (worktree!)
5. agent-006-workflow-fix ⚠️ (worktree!)
6. bulkchanges3
7. fix/add-missing-projects-and-fix-promptmanagement
8. fix/package-version-conflicts

**Delete commando's:**
```bash
cd "C:\Projects\hazina"

# Branch 1: agent-002-context-compression (eerst worktree cleanup!)
git worktree remove "C:/Projects/worker-agents/agent-002/hazina" --force
git branch -d agent-002-context-compression
git push origin --delete agent-002-context-compression

# Branch 2: agent-002-tool-agent-3layer
git branch -d agent-002-tool-agent-3layer
git push origin --delete agent-002-tool-agent-3layer

# Branch 3: agent-003-brand-fragments (eerst worktree cleanup!)
git worktree remove "C:/Projects/worker-agents/agent-003/hazina" --force
git branch -d agent-003-brand-fragments
git push origin --delete agent-003-brand-fragments

# Branch 4: agent-005-google-drive-hazina (eerst worktree cleanup!)
git worktree remove "C:/Projects/worker-agents/agent-005/hazina" --force
git branch -d agent-005-google-drive-hazina
git push origin --delete agent-005-google-drive-hazina

# Branch 5: agent-006-workflow-fix (eerst worktree cleanup!)
git worktree remove "C:/Projects/worker-agents/agent-007/hazina-pr4" --force
git branch -d agent-006-workflow-fix
git push origin --delete agent-006-workflow-fix

# Branch 6: bulkchanges3
git branch -d bulkchanges3
git push origin --delete bulkchanges3

# Branch 7: fix/add-missing-projects-and-fix-promptmanagement
git branch -d fix/add-missing-projects-and-fix-promptmanagement
git push origin --delete fix/add-missing-projects-and-fix-promptmanagement

# Branch 8: fix/package-version-conflicts
git branch -d fix/package-version-conflicts
git push origin --delete fix/package-version-conflicts
```

### Categorie 2: Alleen Lokaal

**Branches (9):**
1. bulkchanges
2. bulkchanges3-import-website
3. bulkchanges3-naming
4. bulkchanges3-tagging
5. google_adk
6. maibn
7. picture_upload
8. task3-document-summarization
9. token_use_optimization

**Delete commando's:**
```bash
cd "C:\Projects\hazina"
git branch -d bulkchanges
git branch -d bulkchanges3-import-website
git branch -d bulkchanges3-naming
git branch -d bulkchanges3-tagging
git branch -d google_adk
git branch -d maibn
git branch -d picture_upload
git branch -d task3-document-summarization
git branch -d token_use_optimization
```

### Categorie 3: Alleen Remote

**Branches (2):**
1. refactor-name-and-structure
2. token_use_optimization (ook lokaal, zie Categorie 2)

**Delete commando's:**
```bash
cd "C:\Projects\hazina"
git push origin --delete refactor-name-and-structure
git push origin --delete token_use_optimization
```

**HAZINA TOTAAL: 17 lokale branches + 10 remote branches = 19 unieke branches**
(token_use_optimization telt dubbel: lokaal + remote)

---

## 📊 CLIENT-MANAGER - Te Verwijderen Branches

### Categorie 1: Lokaal + Remote (beide verwijderen)

**Branches (26):**
1. agent-001-content-hooks-feature
2. agent-001-disable-signup-message
3. agent-001-fix-user-management
4. agent-001-holographic-evolution-v2
5. agent-001-license-manager ⚠️ (worktree!)
6. agent-001-product-catalog-phase1
7. agent-001-product-catalog-phases234-docs
8. agent-001-product-catalog-phases234-impl
9. agent-001-ui-proposals-revolutionary
10. agent-002-fix-registration-duplicate-email ⚠️ (worktree!)
11. agent-002-tool-agent-3layer
12. agent-003-brand-fragments
13. agent-003-document-tagging
14. agent-004-revolutionary-concepts-final ⚠️ (worktree!)
15. agent-005-documentation-improvements
16. agent-005-google-drive-integration ⚠️ (worktree!)
17. bulkchanges3
18. feature/logo-variation-improvements
19. feature/restaurant-menu-documents
20. fix/build-errors-duplicate-class-and-tokentransaction
21. improvement/CM-002-dynamic-model-routing
22. improvement/CM-011-query-optimization
23. improvement/CM-022-content-adaptation
24. improvement/CM-051-semantic-cache
25. improvement/CM-054-progressive-refinement
26. improvement/CM-054-quality-scoring ⚠️ (worktree!)

**Delete commando's:**
```bash
cd "C:\Projects\client-manager"

# Branches met worktrees (eerst cleanup!)
git worktree remove "C:/Projects/worker-agents/agent-001/client-manager" --force
git branch -d agent-001-license-manager
git push origin --delete agent-001-license-manager

git worktree remove "C:/Projects/worker-agents/agent-002/client-manager" --force
git branch -d agent-002-fix-registration-duplicate-email
git push origin --delete agent-002-fix-registration-duplicate-email

git worktree remove "C:/Projects/worker-agents/agent-004/client-manager" --force
git branch -d agent-004-revolutionary-concepts-final
git push origin --delete agent-004-revolutionary-concepts-final

git worktree remove "C:/Projects/worker-agents/agent-005/client-manager" --force
git branch -d agent-005-google-drive-integration
git push origin --delete agent-005-google-drive-integration

git worktree remove "C:/Projects/worker-agents/agent-003/client-manager" --force
git branch -d improvement/CM-054-quality-scoring
git push origin --delete improvement/CM-054-quality-scoring

# Overige branches (geen worktrees)
git branch -d agent-001-content-hooks-feature && git push origin --delete agent-001-content-hooks-feature
git branch -d agent-001-disable-signup-message && git push origin --delete agent-001-disable-signup-message
git branch -d agent-001-fix-user-management && git push origin --delete agent-001-fix-user-management
git branch -d agent-001-holographic-evolution-v2 && git push origin --delete agent-001-holographic-evolution-v2
git branch -d agent-001-product-catalog-phase1 && git push origin --delete agent-001-product-catalog-phase1
git branch -d agent-001-product-catalog-phases234-docs && git push origin --delete agent-001-product-catalog-phases234-docs
git branch -d agent-001-product-catalog-phases234-impl && git push origin --delete agent-001-product-catalog-phases234-impl
git branch -d agent-001-ui-proposals-revolutionary && git push origin --delete agent-001-ui-proposals-revolutionary
git branch -d agent-002-tool-agent-3layer && git push origin --delete agent-002-tool-agent-3layer
git branch -d agent-003-brand-fragments && git push origin --delete agent-003-brand-fragments
git branch -d agent-003-document-tagging && git push origin --delete agent-003-document-tagging
git branch -d agent-005-documentation-improvements && git push origin --delete agent-005-documentation-improvements
git branch -d bulkchanges3 && git push origin --delete bulkchanges3
git branch -d feature/logo-variation-improvements && git push origin --delete feature/logo-variation-improvements
git branch -d feature/restaurant-menu-documents && git push origin --delete feature/restaurant-menu-documents
git branch -d fix/build-errors-duplicate-class-and-tokentransaction && git push origin --delete fix/build-errors-duplicate-class-and-tokentransaction
git branch -d improvement/CM-002-dynamic-model-routing && git push origin --delete improvement/CM-002-dynamic-model-routing
git branch -d improvement/CM-011-query-optimization && git push origin --delete improvement/CM-011-query-optimization
git branch -d improvement/CM-022-content-adaptation && git push origin --delete improvement/CM-022-content-adaptation
git branch -d improvement/CM-051-semantic-cache && git push origin --delete improvement/CM-051-semantic-cache
git branch -d improvement/CM-054-progressive-refinement && git push origin --delete improvement/CM-054-progressive-refinement
```

### Categorie 2: Alleen Lokaal

**Branches (42):**
1. agent-001
2. agent-001-content-hooks-ui
3. agent-001-holographic-evolution
4. agent-001-product-catalog-phases234
5. agent-001-revolutionary-ui-concepts
6. agent-001-ui-proposals
7. agent001-webpage-tools
8. agent-002
9. agent-004
10. bulkchanges
11. bulkchanges3-import-website
12. bulkchanges3-interview-tool
13. bulkchanges3-naming
14. bulkchanges3-routing
15. bulkchanges3-tagging
16. feature/reliability-improvements
17. feedback2-fix-chat-naming-v2
18. feedback2-fix-connection-status-v2
19. feedback2-fix-logo-transparency
20. feedback2-fix-new-project-creation-critical
21. feedback3-fix-new-project-message-display
22. feedback-fix-analysis-fields-generation
23. feedback-fix-chat-naming
24. feedback-fix-loading-duration
25. feedback-fix-new-project-creation
26. feedback-improve-connection-status-ui
27. feedback-prevent-brand-name-duplication
28. feedback-prevent-duplicate-gathered-data
29. google_adk
30. improvement/CM-064-unlimited-plan
31. improvement/CM-161-interactive-demo
32. new_ui
33. picture_upload
34. reduce_token_usage
35. task1-instant-scroll-on-open
36. task2-fix-image-reference-retrieval
37. task-filter-gathered-data
38. task-fix-signalr-connection
39. task-improve-logo-generation
40. task-loading-indicators
41. test
42. token_use_optimization

**Delete commando's:**
```bash
cd "C:\Projects\client-manager"
git branch -d agent-001
git branch -d agent-001-content-hooks-ui
git branch -d agent-001-holographic-evolution
git branch -d agent-001-product-catalog-phases234
git branch -d agent-001-revolutionary-ui-concepts
git branch -d agent-001-ui-proposals
git branch -d agent001-webpage-tools
git branch -d agent-002
git branch -d agent-004
git branch -d bulkchanges
git branch -d bulkchanges3-import-website
git branch -d bulkchanges3-interview-tool
git branch -d bulkchanges3-naming
git branch -d bulkchanges3-routing
git branch -d bulkchanges3-tagging
git branch -d feature/reliability-improvements
git branch -d feedback2-fix-chat-naming-v2
git branch -d feedback2-fix-connection-status-v2
git branch -d feedback2-fix-logo-transparency
git branch -d feedback2-fix-new-project-creation-critical
git branch -d feedback3-fix-new-project-message-display
git branch -d feedback-fix-analysis-fields-generation
git branch -d feedback-fix-chat-naming
git branch -d feedback-fix-loading-duration
git branch -d feedback-fix-new-project-creation
git branch -d feedback-improve-connection-status-ui
git branch -d feedback-prevent-brand-name-duplication
git branch -d feedback-prevent-duplicate-gathered-data
git branch -d google_adk
git branch -d improvement/CM-064-unlimited-plan
git branch -d improvement/CM-161-interactive-demo
git branch -d new_ui
git branch -d picture_upload
git branch -d reduce_token_usage
git branch -d task1-instant-scroll-on-open
git branch -d task2-fix-image-reference-retrieval
git branch -d task-filter-gathered-data
git branch -d task-fix-signalr-connection
git branch -d task-improve-logo-generation
git branch -d task-loading-indicators
git branch -d test
git branch -d token_use_optimization
```

### Categorie 3: Alleen Remote

**Branches (10):**
1. agent-001-chat-virtual-scrolling
2. feature/single-llm-with-tools
3. hazina
4. improvement/CM-064-unlimited-plan (ook lokaal)
5. improvement/CM-161-interactive-demo (ook lokaal)
6. new_ui (ook lokaal)
7. payment
8. rename_api
9. token_use_optimization (ook lokaal)
10. upgrade_ui_infrastructure (ook lokaal)

**Delete commando's:**
```bash
cd "C:\Projects\client-manager"
git push origin --delete agent-001-chat-virtual-scrolling
git push origin --delete feature/single-llm-with-tools
git push origin --delete hazina
git push origin --delete improvement/CM-064-unlimited-plan
git push origin --delete improvement/CM-161-interactive-demo
git push origin --delete new_ui
git push origin --delete payment
git push origin --delete rename_api
git push origin --delete token_use_optimization
git push origin --delete upgrade_ui_infrastructure
```

**CLIENT-MANAGER TOTAAL: 68 lokale branches + 36 remote branches = 73 unieke branches**

---

## 📈 GRAND TOTAAL

### Worktrees te verwijderen:
- **Hazina:** 5 worktrees
- **Client-Manager:** 5 worktrees
- **TOTAAL:** 10 worktrees

### Branches te verwijderen:
- **Hazina:** 19 unieke branches (17 lokaal + 10 remote)
- **Client-Manager:** 73 unieke branches (68 lokaal + 36 remote)
- **TOTAAL:** 92 unieke branches

### Operaties:
- **Worktree removes:** 10
- **Lokale branch deletes:** 85
- **Remote branch deletes:** 46
- **TOTALE OPERATIES:** 141

---

## 🎯 UITVOERING OPTIES

### Optie A: Automatisch uitvoeren (aanbevolen)
Ik voer alle delete operaties automatisch uit met:
1. Eerst alle worktrees verwijderen
2. Dan alle lokale branches
3. Tot slot alle remote branches
4. Verificatie na elke stap

**Voordeel:** Snel, betrouwbaar, met verificatie
**Tijd:** ~5-10 minuten

### Optie B: Per repository handmatig
Je kopieert de commando's en voert ze zelf uit.

**Voordeel:** Volledige controle
**Nadeel:** Tijdrovend, kans op fouten

### Optie C: Per categorie met bevestiging
Ik voer het uit per categorie (worktrees, lokaal, remote) en vraag elke keer bevestiging.

**Voordeel:** Meer controle, maar sneller dan handmatig
**Nadeel:** Meer interacties nodig

---

## ⚠️ VEILIGHEIDSCHECK

Alle branches in dit overzicht zijn:
✅ Volledig gemerged in develop
✅ Geen unieke commits die verloren gaan
✅ Alle code zit in develop/main

**Dit is een veilige cleanup operatie!**

---

## ❓ WAT WIL JE?

Kies een optie:
- **A** - "ga door met optie A" → Ik doe alles automatisch
- **B** - "ik doe het zelf" → Je gebruikt de commando's hierboven
- **C** - "doe het stap voor stap" → Per categorie met bevestiging
- **STOP** - "wacht, ik wil eerst controleren" → Ik wacht

**Welke optie kies je?**
