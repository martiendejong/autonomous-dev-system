# Pull Request Settings Guide
**Datum:** 2026-01-08
**Status:** Active

---

## 📋 STANDAARD PR INSTELLINGEN

Vanaf nu moeten alle Pull Requests de volgende instellingen hebben:

### 1. ✅ Auto-delete branch na merge
**Waarom:** Voorkomt ophoping van oude branches op remote

### 2. 🔄 Squash merge als default
**Waarom:** Houdt commit history schoon en lineair

---

## 🛠️ IMPLEMENTATIE

### Via GitHub CLI (gh pr create)

**Standaard commando template:**
```bash
gh pr create \
  --title "Duidelijke titel" \
  --body "$(cat <<'EOF'
## Summary
...

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

**Notities:**
- ⚠️ `gh pr create` heeft geen directe flag voor squash merge preference
- ⚠️ Auto-delete branch moet handmatig ingesteld worden in GitHub UI of via repo settings
- ✅ Best practice: Merge via `gh pr merge --squash --delete-branch` wanneer PR approved is

### Via Repository Settings (ONE-TIME SETUP)

Om dit repository-wide in te stellen:

1. **GitHub.com** → Repository → Settings → General
2. **Pull Requests sectie:**
   - ✅ Enable "Automatically delete head branches"
   - ✅ Set default merge method: "Squash merging"
   - ❌ Disable "Allow merge commits" (optioneel)
   - ❌ Disable "Allow rebase merging" (optioneel)

**Dit moet gedaan worden voor:**
- [ ] https://github.com/martiendejong/Hazina
- [ ] https://github.com/martiendejong/client-manager

---

## 🚀 MERGE WORKFLOW

### Wanneer PR klaar is om te mergen:

**Optie A - Via GitHub CLI (aanbevolen):**
```bash
# Check PR status
gh pr view <number>

# Merge met squash + auto-delete
gh pr merge <number> --squash --delete-branch

# Of als je op de branch zit:
gh pr merge --squash --delete-branch
```

**Optie B - Via GitHub UI:**
1. Open PR op GitHub.com
2. Klik "Squash and merge" (groene button dropdown)
3. ✅ Verify "Delete branch" checkbox is checked
4. Confirm merge

---

## 📝 PR BODY TEMPLATE

Gebruik altijd deze structuur:

```markdown
## Summary
- Bullet point samenvatting van wijzigingen
- Waarom deze wijzigingen nodig zijn

## Changes
Gedetailleerde lijst van wijzigingen per categorie

## Testing
- [ ] Test checklist item 1
- [ ] Test checklist item 2

## Related
Links naar gerelateerde issues/PRs

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

---

## ✅ CHECKLIST VOOR ELKE PR

Voordat je PR maakt:
- [ ] Branch naam is descriptive (bijv. `fix/bug-description`, `feature/feature-name`)
- [ ] Commits zijn duidelijk en atomair
- [ ] Tests zijn toegevoegd/updated (indien van toepassing)
- [ ] PR title is duidelijk en beschrijvend
- [ ] PR body volgt het template hierboven

Na PR aanmaken:
- [ ] PR is assigned aan jezelf (indien applicable)
- [ ] Labels zijn toegevoegd (bug, feature, etc.)
- [ ] Linked aan relevante issues

Bij mergen:
- [ ] Use `gh pr merge --squash --delete-branch`
- [ ] OF via GitHub UI met "Squash and merge" + "Delete branch"

---

## 🎯 VOORBEELDEN

### Voorbeeld 1: Feature PR
```bash
cd "C:\Projects\hazina"
git checkout develop
git pull origin develop
git checkout -b feature/add-caching-support

# ... make changes ...

git add .
git commit -m "feat: Add caching support for embeddings"
git push -u origin feature/add-caching-support

gh pr create \
  --title "feat: Add caching support for embeddings" \
  --body "$(cat <<'EOF'
## Summary
- Add in-memory cache for embeddings to reduce API calls
- Cache expires after 1 hour
- Reduces costs by ~60% for repeated queries

## Changes
- Add CacheService with LRU eviction
- Update EmbeddingsService to use cache
- Add cache configuration options

## Testing
- [x] Unit tests for CacheService
- [x] Integration tests for cached embeddings
- [x] Performance benchmarks

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### Voorbeeld 2: Bugfix PR
```bash
cd "C:\Projects\client-manager"
git checkout develop
git pull origin develop
git checkout -b fix/login-redirect-bug

# ... fix bug ...

git add .
git commit -m "fix: Resolve login redirect loop"
git push -u origin fix/login-redirect-bug

gh pr create \
  --title "fix: Resolve login redirect loop" \
  --body "$(cat <<'EOF'
## Summary
- Fix infinite redirect loop when session expires
- User is now properly redirected to login page

## Changes
- Update AuthContext to handle expired sessions
- Add session expiry check in App.tsx
- Clear local storage on session expiry

## Testing
- [x] Tested manual session expiry
- [x] Tested auto session expiry after timeout
- [x] Verified login flow works correctly

## Related
Fixes #123

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## 🔧 REPOSITORY SETTINGS UPDATE COMMANDO'S

**Om te verifiëren huidige settings:**
```bash
# Check merge settings
gh api repos/martiendejong/Hazina | jq '{allow_squash_merge, allow_merge_commit, allow_rebase_merge, delete_branch_on_merge}'
gh api repos/martiendejong/client-manager | jq '{allow_squash_merge, allow_merge_commit, allow_rebase_merge, delete_branch_on_merge}'
```

**Om settings te updaten (requires admin):**
```bash
# Hazina
gh api -X PATCH repos/martiendejong/Hazina \
  -f allow_squash_merge=true \
  -f allow_merge_commit=false \
  -f allow_rebase_merge=false \
  -f delete_branch_on_merge=true

# Client-Manager
gh api -X PATCH repos/martiendejong/client-manager \
  -f allow_squash_merge=true \
  -f allow_merge_commit=false \
  -f allow_rebase_merge=false \
  -f delete_branch_on_merge=true
```

---

## 📚 RESOURCES

- [GitHub: About merge methods](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/about-merge-methods-on-github)
- [GitHub CLI: pr merge](https://cli.github.com/manual/gh_pr_merge)
- [Git: Squash commits](https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History)

---

**LAATSTE UPDATE:** 2026-01-08 - Initial setup guide
