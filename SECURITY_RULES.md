# Security Rules (autonomous-dev-system)

Zero-tolerance security rules that apply to **every** repo managed by this autonomous
development system. Adopted 2026-04-16 as part of the CodeHub credential-leak remediation
(ClickUp task 869cnyf88).

## Zero-Tolerance Rules

### Rule 1 — Never commit passwords or secrets

Never commit any of the following:

- Hardcoded passwords in source code
- API keys, tokens, or session cookies
- Database connection strings with credentials
- OAuth client secrets (e.g. `GOCSPX-*`)
- Email / SMTP credentials
- Encryption keys, certificates, `.pem` / `.key` files
- SSH private keys

### Rule 2 — Use environment variables or secret managers

All sensitive configuration MUST come from one of:

- Environment variables (`Environment.GetEnvironmentVariable` / `process.env`)
- Platform secret managers (Azure Key Vault, AWS Secrets Manager, GCP Secret Manager)
- `dotnet user-secrets` for local .NET development
- `.env` files that are **never** committed (enforced by `.gitignore`)

```csharp
// CORRECT
var adminPassword = Environment.GetEnvironmentVariable("DEFAULT_ADMIN_PASSWORD");
if (string.IsNullOrEmpty(adminPassword))
{
    logger.LogWarning("DEFAULT_ADMIN_PASSWORD not set. Skipping admin seeding.");
    return;
}
var passwordHash = BCrypt.HashPassword(adminPassword);

// WRONG
var passwordHash = BCrypt.HashPassword("admin123");
```

### Rule 3 — Pre-commit hook required in every repo

Every repository managed by the autonomous dev system MUST have
`tools/pre-commit-hook.ps1` installed as `.git/hooks/pre-commit`. This hook blocks
commits that contain:

- Generic password patterns (`password=...`, `Password=...;`)
- API keys (`api_key=...` with 20+ char values)
- GitHub tokens (`gh_token=...`, `github_token=...`)
- Bearer / OAuth tokens
- RSA / OpenSSH / PGP private keys
- AWS access keys (`AKIA...`)
- Google OAuth secrets (`GOCSPX-...`)
- Connection strings with embedded passwords
- JWT-shaped tokens

Installation (PowerShell):

```powershell
powershell -ExecutionPolicy Bypass `
  -File "C:\scripts\tools\pre-commit-hook.ps1" `
  -Install `
  -RepoPath "C:\projects\your-repo"
```

Installation (Git Bash):

```bash
cat > .git/hooks/pre-commit <<'EOF'
#!/bin/sh
powershell.exe -ExecutionPolicy Bypass -File "C:\scripts\tools\pre-commit-hook.ps1" -Check
exit $?
EOF
chmod +x .git/hooks/pre-commit
```

The `C:\scripts\claim-worktree.cmd` allocator auto-installs this hook in every new
worktree via `C:\scripts\_machine\install-precommit.ps1`.

### Rule 4 — Gitignore enforcement

Always gitignore:

- `appsettings.*.json` (except the base `appsettings.json` template)
- `.env`, `.env.*`
- `secrets/`, `credentials/`
- `*.key`, `*.pem`, `*.crt`, `*.pfx`
- Anything matching `*.Production.json`, `*.local.json`

Use explicit filenames alongside wildcards — some wildcard patterns fail for files
that are already tracked. If a file is already tracked, run:

```bash
git rm --cached path/to/file
```

### Rule 5 — Git history purging

If a secret reaches `origin`:

1. **Rotate the secret immediately** — regenerate the password / key / token in the
   upstream provider console. Never assume history purging is sufficient; the secret
   has already been published.
2. **Purge from git history** with `git-filter-repo`:

   ```bash
   pip install git-filter-repo
   echo 'OLD_SECRET_VALUE==>REDACTED' > /tmp/replacements.txt
   git filter-repo --replace-text /tmp/replacements.txt
   git push origin --force --all
   git push origin --force --tags
   ```

3. **Notify the team** — force-pushes to shared branches require coordination.
4. **Document the incident** — add to the team incident log.

### Rule 6 — Credential rotation cadence

Rotate credentials when:

- Accidentally committed to git (even if later removed — assume they are leaked).
- A team member with access leaves the project.
- Suspected breach or anomalous activity.
- Every 90 days for production secrets as a baseline hygiene measure.

### Rule 7 — User-secrets for local .NET development

```bash
dotnet user-secrets init --project YourProject.Api
dotnet user-secrets set "DEFAULT_ADMIN_PASSWORD" "your-secure-password" --project YourProject.Api
dotnet user-secrets set "Jwt:SecretKey" "your-jwt-secret" --project YourProject.Api
dotnet user-secrets set "Google:ClientSecret" "your-oauth-secret" --project YourProject.Api
```

## CI/CD Secret Scanning Gate

Every repo MUST have `.github/workflows/secret-scan.yml` running Gitleaks plus repo-
specific grep patterns on every PR and push to protected branches. A reference
workflow lives in this repo at `.github/workflows/secret-scan.yml` — copy it
into new repos and adjust the language-specific grep patterns as needed.

## Pre-Commit Checklist

Before `git commit`:

- [ ] No hardcoded passwords in source files
- [ ] No API keys or tokens in configs
- [ ] Environment variables used for all secrets
- [ ] `appsettings.*.Production.json` not tracked
- [ ] Pre-commit hook installed (`.git/hooks/pre-commit` exists and is executable)
- [ ] GitHub Actions secret scan workflow present
- [ ] Sensitive files in `.gitignore`

## Secret-Scanning Tools

- **Gitleaks** (recommended) — `brew install gitleaks` / `choco install gitleaks`
- **detect-secrets** — `pip install detect-secrets`
- **TruffleHog** — `pip install trufflehog`

## Incident Response

If a secret is leaked:

1. **STOP** — do not push further changes to the affected branch.
2. **ROTATE** — change the leaked secret in its source of truth.
3. **PURGE** — remove from git history (Rule 5).
4. **NOTIFY** — alert the team and security lead.
5. **DOCUMENT** — record the incident.
6. **PREVENT** — add the missing guardrail that would have caught this.

---

**Last updated:** 2026-04-16
**Origin:** Extracted and generalized from CodeHub PR #49 (ClickUp task 869cnyf88)
