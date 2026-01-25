# Cross-Reference Analysis Report
**Generated:** 2026-01-25 18:43:24
**Source:** `C:\scripts\logs\cross-reference-validation.md`

## Executive Summary

| Category | Count | Priority | Action Required |
|----------|-------|----------|-----------------|
| Placeholder Links | 11 | LOW | Clean up or replace with real links |
| Template Artifacts | 1 | LOW | Normal for templates |
| External Repo Links | 11 | **HIGH** | Update paths or document |
| Wrong Relative Paths | 70 | **CRITICAL** | Fix immediately |
| Missing Files | 10 | **HIGH** | Create files or remove links |

**Total Issues:** 103

---

## 1. Placeholder Links (LOW PRIORITY)

These are links using placeholder text like `[text](url)` or `[text](link)`.
**Action:** Review and either add real URLs or remove.

### `` (11 links)
- [x] Link text: **View All**
- [x] Link text: **Eenvoudig huis**
- [x] Link text: **Generated Image**
- [x] Link text: **Eenvoudig huis**
- [x] Link text: **Any text here**
- [x] Link text: **Generated Image**
- [x] Link text: **Eenvoudig huis**
- [x] Link text: **anything**
- [x] Link text: **Generated Image**
- [x] Link text: **Eenvoudig huis**
- [x] Link text: **alt**

---

## 2. Template Artifacts (LOW PRIORITY)

These are placeholders in templates like `[MethodName]([params])`.
**Action:** None required - these are normal template syntax.
- `templates\FEATURE_GUIDE_TEMPLATE.md` â†’ `[params]`

---

## 3. External Repository Links (HIGH PRIORITY)

These link to `../client-manager` or `../hazina` which don't exist relative to C:\scripts.
**Action:** Update to absolute paths or add note that repos must be cloned.

### Target: `` (11 references)
**Referenced in:**
- `_machine\KNOWLEDGE_BASE_SUMMARY.md`
- `_machine\archive\reference-2026-01-initial-setup\CLIENT_MANAGER_DEEP_DIVE.md`
- `_machine\archive\reference-2026-01-initial-setup\CLIENT_MANAGER_DEEP_DIVE.md`
- `_machine\archive\reference-2026-01-initial-setup\CLIENT_MANAGER_DEEP_DIVE.md`
- `_machine\archive\reference-2026-01-initial-setup\HAZINA_DEEP_DIVE.md`
- `_machine\archive\reference-2026-01-initial-setup\HAZINA_DEEP_DIVE.md`
- `_machine\archive\reference-2026-01-initial-setup\HAZINA_DEEP_DIVE.md`
- `_machine\archive\reference-2026-01-initial-setup\HAZINA_DEEP_DIVE.md`
- `_machine\archive\reference-2026-01-initial-setup\HAZINA_DEEP_DIVE.md`
- `_machine\archive\reference-2026-01-initial-setup\HAZINA_DEEP_DIVE.md`
- `_machine\archive\reference-2026-01-initial-setup\HAZINA_DEEP_DIVE.md`

**Fix:**

---

## 4. Wrong Relative Paths (CRITICAL)

These use relative paths that resolve incorrectly.
**Action:** Fix immediately.

### Source: `.claude\skills\ef-migration-safety\SKILL.md`
- **Current:** `../../_machine/ef-core-table-naming-incident.md`
- **File:** `ef-core-table-naming-incident.md`
- **Action:** Search for this file and update path

### Source: `.claude\skills\self-improvement\SKILL.md`
- **Current:** `./ci-cd-troubleshooting.md`
- **File:** `ci-cd-troubleshooting.md`
- **Action:** Search for this file and update path

### Source: `.claude\skills\self-improvement\SKILL.md`
- **Current:** `./development-patterns.md`
- **File:** `development-patterns.md`
- **Action:** Search for this file and update path

### Source: `.claude\skills\self-improvement\SKILL.md`
- **Current:** `./new-file.md`
- **File:** `new-file.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\BRANCHING_STRATEGY.md`
- **Current:** `./worktrees.protocol.md`
- **File:** `worktrees.protocol.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\CLIENT_MANAGER_DEEP_DIVE.md`
- **Current:** `./worktrees.protocol.md`
- **File:** `worktrees.protocol.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\DATA_MIGRATION_STRATEGY.md`
- **Current:** `./ADR/002-sqlite-dev-postgres-prod.md`
- **File:** `002-sqlite-dev-postgres-prod.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\DATA_MIGRATION_STRATEGY.md`
- **Current:** `./ADR/006-entity-framework-core.md`
- **File:** `006-entity-framework-core.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\DATA_MIGRATION_STRATEGY.md`
- **Current:** `./TROUBLESHOOTING.md`
- **File:** `TROUBLESHOOTING.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\ENABLE_SWAGGER_API_DOCS.md`
- **Current:** `./TROUBLESHOOTING.md`
- **File:** `TROUBLESHOOTING.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\GETTING_STARTED.md`
- **Current:** `./TROUBLESHOOTING.md`
- **File:** `TROUBLESHOOTING.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\GETTING_STARTED.md`
- **Current:** `./TROUBLESHOOTING.md`
- **File:** `TROUBLESHOOTING.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\LLM_COST_OPTIMIZATION.md`
- **Current:** `./ADR/013-multi-provider-llm.md`
- **File:** `013-multi-provider-llm.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\LLM_COST_OPTIMIZATION.md`
- **Current:** `./ADR/014-token-based-pricing.md`
- **File:** `014-token-based-pricing.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\MULTI_ENVIRONMENT_CONFIGURATION.md`
- **Current:** `./ADR/002-sqlite-dev-postgres-prod.md`
- **File:** `002-sqlite-dev-postgres-prod.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\MULTI_ENVIRONMENT_CONFIGURATION.md`
- **Current:** `./TROUBLESHOOTING.md`
- **File:** `TROUBLESHOOTING.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\PROJECTS_INDEX.md`
- **Current:** `./worktrees.protocol.md`
- **File:** `worktrees.protocol.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\REACT_STATE_MANAGEMENT_50_GUIDELINES.md`
- **Current:** `./ADR/010-zustand-state-management.md`
- **File:** `010-zustand-state-management.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\SCRIPTS_INDEX.md`
- **Current:** `./worktrees.protocol.md`
- **File:** `worktrees.protocol.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\SCRIPTS_INDEX.md`
- **Current:** `./reflection.log.md`
- **File:** `reflection.log.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\SCRIPTS_INDEX.md`
- **Current:** `../claude.md`
- **File:** `claude.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\SCRIPTS_INDEX.md`
- **Current:** `../ZERO_TOLERANCE_RULES.md`
- **File:** `ZERO_TOLERANCE_RULES.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\SECRETS_MANAGEMENT.md`
- **Current:** `./ADR/002-sqlite-dev-postgres-prod.md`
- **File:** `002-sqlite-dev-postgres-prod.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\SECURITY_CHECKLIST.md`
- **Current:** `./ADR/008-jwt-authentication.md`
- **File:** `008-jwt-authentication.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\SECURITY_CHECKLIST.md`
- **Current:** `./ADR/004-multi-tenant-architecture.md`
- **File:** `004-multi-tenant-architecture.md`
- **Action:** Search for this file and update path

### Source: `_machine\archive\reference-2026-01-initial-setup\TEST_STRATEGY.md`
- **Current:** `./.github/workflows/`

### Source: `_machine\knowledge-base\02-MACHINE\environment-variables.md`
- **Current:** `./tools-documentation.md`
- **File:** `tools-documentation.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\02-MACHINE\environment-variables.md`
- **Current:** `./development-environment.md`
- **File:** `development-environment.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\02-MACHINE\environment-variables.md`
- **Current:** `./file-system-structure.md`
- **File:** `file-system-structure.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\02-MACHINE\environment-variables.md`
- **Current:** `./security-practices.md`
- **File:** `security-practices.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\02-MACHINE\file-system-map.md`
- **Current:** `../MACHINE_CONFIG.md`
- **File:** `MACHINE_CONFIG.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\02-MACHINE\file-system-map.md`
- **Current:** `../../GENERAL_WORKTREE_PROTOCOL.md`
- **File:** `GENERAL_WORKTREE_PROTOCOL.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\02-MACHINE\file-system-map.md`
- **Current:** `../../tools/README.md`
- **File:** `README.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\02-MACHINE\file-system-map.md`
- **Current:** `../SYSTEM_INTEGRATION.md`
- **File:** `SYSTEM_INTEGRATION.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\05-PROJECTS\client-manager\architecture.md`
- **Current:** `../04-EXTERNAL-SYSTEMS/clickup/integration.md`
- **File:** `integration.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\05-PROJECTS\client-manager\architecture.md`
- **Current:** `../04-EXTERNAL-SYSTEMS/github/workflows.md`
- **File:** `workflows.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\05-PROJECTS\hazina\framework-patterns.md`
- **Current:** `../../02-WORKFLOWS/cross-repo-dependencies.md`
- **File:** `cross-repo-dependencies.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\05-PROJECTS\hazina\framework-patterns.md`
- **Current:** `../../02-WORKFLOWS/cross-repo-dependencies.md`
- **File:** `cross-repo-dependencies.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../GENERAL_DUAL_MODE_WORKFLOW.md`
- **File:** `GENERAL_DUAL_MODE_WORKFLOW.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../GENERAL_DUAL_MODE_WORKFLOW.md`
- **File:** `GENERAL_DUAL_MODE_WORKFLOW.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../GENERAL_WORKTREE_PROTOCOL.md`
- **File:** `GENERAL_WORKTREE_PROTOCOL.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../git-workflow.md`
- **File:** `git-workflow.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../.claude/skills/ef-migration-safety/SKILL.md`
- **File:** `SKILL.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../.claude/skills/parallel-agent-coordination/SKILL.md`
- **File:** `SKILL.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../ci-cd-troubleshooting.md`
- **File:** `ci-cd-troubleshooting.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../continuous-improvement.md`
- **File:** `continuous-improvement.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../GENERAL_WORKTREE_PROTOCOL.md`
- **File:** `GENERAL_WORKTREE_PROTOCOL.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../git-workflow.md`
- **File:** `git-workflow.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../GENERAL_DUAL_MODE_WORKFLOW.md`
- **File:** `GENERAL_DUAL_MODE_WORKFLOW.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../GENERAL_DUAL_MODE_WORKFLOW.md`
- **File:** `GENERAL_DUAL_MODE_WORKFLOW.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../.claude/skills/parallel-agent-coordination/SKILL.md`
- **File:** `SKILL.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../ci-cd-troubleshooting.md`
- **File:** `ci-cd-troubleshooting.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../.claude/skills/ef-migration-safety/SKILL.md`
- **File:** `SKILL.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../continuous-improvement.md`
- **File:** `continuous-improvement.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../GENERAL_DUAL_MODE_WORKFLOW.md`
- **File:** `GENERAL_DUAL_MODE_WORKFLOW.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../GENERAL_WORKTREE_PROTOCOL.md`
- **File:** `GENERAL_WORKTREE_PROTOCOL.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../git-workflow.md`
- **File:** `git-workflow.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../continuous-improvement.md`
- **File:** `continuous-improvement.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../_machine/SYSTEM_INTEGRATION.md`
- **File:** `SYSTEM_INTEGRATION.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../_machine/DEFINITION_OF_DONE.md`
- **File:** `DEFINITION_OF_DONE.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../_machine/SOFTWARE_DEVELOPMENT_PRINCIPLES.md`
- **File:** `SOFTWARE_DEVELOPMENT_PRINCIPLES.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../ci-cd-troubleshooting.md`
- **File:** `ci-cd-troubleshooting.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../_machine/COORDINATION_TROUBLESHOOTING.md`
- **File:** `COORDINATION_TROUBLESHOOTING.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../_machine/ef-core-table-naming-incident.md`
- **File:** `ef-core-table-naming-incident.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../.claude/skills/allocate-worktree/SKILL.md`
- **File:** `SKILL.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../.claude/skills/release-worktree/SKILL.md`
- **File:** `SKILL.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../.claude/skills/github-workflow/SKILL.md`
- **File:** `SKILL.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../.claude/skills/ef-migration-safety/SKILL.md`
- **File:** `SKILL.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../.claude/skills/parallel-agent-coordination/SKILL.md`
- **File:** `SKILL.md`
- **Action:** Search for this file and update path

### Source: `_machine\knowledge-base\06-WORKFLOWS\INDEX.md`
- **Current:** `../../tools/README.md`
- **File:** `README.md`
- **Action:** Search for this file and update path

---

## 5. Missing Files (HIGH PRIORITY)

These files are referenced but don't exist.
**Action:** Either create the files or remove the references.

### `docs/apidoc/index.html`
- **Referenced in:** `development-patterns.md`
- **Link text:** View Full Documentation

### `C:\stores\brand2boost\prompts\`
- **Referenced in:** `_machine\archive\reference-2026-01-initial-setup\PROMPT_ENGINEERING.md`
- **Link text:** Hazina Prompts

### `.*\.md`
- **Referenced in:** `_machine\knowledge-base\README.md`
- **Link text:** .*\

### `C:\Projects\hazina\README.md`
- **Referenced in:** `_machine\knowledge-base\05-PROJECTS\hazina\framework-patterns.md`
- **Link text:** Hazina README.md

### `C:\Projects\hazina\TECHNICAL_GUIDE.md`
- **Referenced in:** `_machine\knowledge-base\05-PROJECTS\hazina\framework-patterns.md`
- **Link text:** Hazina Technical Guide

### `C:\scripts\tools\README.md`
- **Referenced in:** `_machine\knowledge-base\07-AUTOMATION\tools-library.md`
- **Link text:** tools/README.md

### `C:\scripts\CLAUDE.md`
- **Referenced in:** `_machine\knowledge-base\07-AUTOMATION\tools-library.md`
- **Link text:** CLAUDE.md

### `C:\scripts\_machine\reflection.log.md`
- **Referenced in:** `_machine\knowledge-base\07-AUTOMATION\tools-library.md`
- **Link text:** reflection.log.md

### `C:\scripts\tools\daily-tool-review.ps1`
- **Referenced in:** `_machine\knowledge-base\07-AUTOMATION\tools-library.md`
- **Link text:** daily-tool-review.ps1

### `link-to-hazina-pr`
- **Referenced in:** `_machine\pattern-templates\cross-repo-change.md`
- **Link text:** Hazina PR #XX

---

## Recommended Actions

### Immediate (CRITICAL)
1. Fix all wrong relative paths in section 4
2. Review external repo links and update documentation

### High Priority
1. Create missing files or remove references (section 5)
2. Document external repository dependencies

### Low Priority
1. Clean up placeholder links (section 1)
2. Template artifacts are OK to ignore

---

## Tool Commands

```powershell
# Re-run validation
.\tools\validate-xrefs-simple.ps1

# Re-run analysis
.\tools\analyze-xrefs.ps1
```

