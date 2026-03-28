# Configuration Guide

Complete reference for all configuration settings in the Autonomous Dev System.

## Configuration Files

| File | Purpose | Required |
|------|---------|----------|
| `docs/config.template.json` | Main configuration template | Yes |
| `MACHINE_CONFIG.md` | Machine-specific paths | Yes |
| `.claude/settings.json` | Claude Code settings | Auto-generated |
| `tools/vault.secure.json` | Encrypted credentials | Auto-created |
| `agentidentity/CORE_IDENTITY.md` | Agent identity | Optional (customize) |

## config.template.json

The main configuration file controls all system behavior. Copy `docs/config.template.json` to your preferred location and customize.

### OpenAI Configuration

```json
{
  "openai": {
    "apiKey": "sk-...",
    "model": "gpt-4-turbo-preview",
    "temperature": 0.7,
    "maxTokens": 4000
  }
}
```

**Settings:**

- **`apiKey`** (string, required)
  - Your OpenAI API key
  - Format: `sk-...` (51 characters)
  - Get from: [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys)
  - **Security:** Store in vault, not in config file directly

- **`model`** (string, default: `"gpt-4-turbo-preview"`)
  - AI model to use
  - Options: `gpt-4-turbo-preview`, `gpt-4`, `gpt-3.5-turbo`
  - Recommendation: `gpt-4-turbo-preview` for best results

- **`temperature`** (number, 0.0-2.0, default: `0.7`)
  - Creativity vs determinism
  - `0.0` = Deterministic, consistent outputs
  - `1.0` = Balanced creativity
  - `2.0` = Maximum creativity
  - Recommendation: `0.7` for code generation, `1.2` for creative content

- **`maxTokens`** (number, default: `4000`)
  - Maximum response length
  - Range: `1` to `8192` (model-dependent)
  - Recommendation: `4000` for balanced cost/capability

### WordPress Configuration

```json
{
  "wordpress": {
    "siteUrl": "https://your-site.com",
    "apiKey": "your-wordpress-application-password",
    "username": "admin"
  }
}
```

**Settings:**

- **`siteUrl`** (string, required)
  - Your WordPress site URL
  - Format: `https://domain.com` (no trailing slash)
  - Must be accessible via HTTPS

- **`apiKey`** (string, required)
  - WordPress Application Password
  - **NOT** your login password
  - Create at: WordPress Admin → Users → Your Profile → Application Passwords
  - Format: `xxxx xxxx xxxx xxxx xxxx xxxx` (24 characters with spaces)

- **`username`** (string, required)
  - WordPress admin username
  - Used for API authentication
  - Must have administrator privileges

**Security Note:** Store `apiKey` in vault:
```powershell
vault.ps1 -Action set -Service "wordpress" -Token "xxxx xxxx xxxx xxxx xxxx xxxx"
```

### RSS Feed Configuration

```json
{
  "rss": {
    "feeds": [
      {
        "url": "https://example.com/feed.xml",
        "name": "Example Feed",
        "category": "general",
        "updateInterval": 3600
      }
    ]
  }
}
```

**Settings:**

- **`feeds`** (array, required)
  - List of RSS feeds to monitor
  - Each feed has:
    - **`url`** (string, required) - RSS/Atom feed URL
    - **`name`** (string, required) - Human-readable feed name
    - **`category`** (string, optional) - Feed category for organization
    - **`updateInterval`** (number, seconds, default: `3600`) - How often to check for updates

**Examples:**
```json
{
  "url": "https://feeds.bbci.co.uk/news/world/rss.xml",
  "name": "BBC World News",
  "category": "news",
  "updateInterval": 1800
}
```

### Faction Definitions

Factions represent ideological perspectives for multi-perspective news analysis.

```json
{
  "factions": {
    "definitions": [
      {
        "id": "progressive",
        "name": "Progressive",
        "keywords": ["climate", "equality", "justice", "diversity"],
        "sentimentBias": 0.2
      }
    ]
  }
}
```

**Settings:**

- **`id`** (string, required, unique)
  - Faction identifier (lowercase, no spaces)
  - Used in code and URLs

- **`name`** (string, required)
  - Display name

- **`keywords`** (array of strings, required)
  - Keywords that characterize this faction
  - Used for content classification
  - Minimum: 3 keywords

- **`sentimentBias`** (number, -1.0 to 1.0, default: `0.0`)
  - Sentiment adjustment for this faction
  - Positive: Optimistic framing
  - Negative: Critical framing
  - `0.0`: Neutral

**Example Factions:**

```json
{
  "id": "conservative",
  "name": "Conservative",
  "keywords": ["tradition", "security", "economy", "family", "law-order"],
  "sentimentBias": -0.2
}
```

```json
{
  "id": "libertarian",
  "name": "Libertarian",
  "keywords": ["freedom", "minimal-government", "free-market", "individual-rights"],
  "sentimentBias": 0.0
}
```

### Region Mappings

Configure geographic regions for localized content.

```json
{
  "regions": {
    "mappings": [
      {
        "code": "us",
        "name": "United States",
        "timezone": "America/New_York",
        "language": "en"
      }
    ]
  }
}
```

**Settings:**

- **`code`** (string, required, unique)
  - ISO 3166-1 alpha-2 country code (lowercase)
  - Examples: `us`, `gb`, `nl`, `de`, `fr`

- **`name`** (string, required)
  - Full region name (English)

- **`timezone`** (string, required)
  - IANA timezone identifier
  - Find at: [https://en.wikipedia.org/wiki/List_of_tz_database_time_zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)
  - Examples: `America/New_York`, `Europe/Amsterdam`, `Asia/Tokyo`

- **`language`** (string, required)
  - ISO 639-1 language code
  - Examples: `en`, `nl`, `de`, `fr`, `es`

**Common Regions:**

```json
[
  { "code": "us", "name": "United States", "timezone": "America/New_York", "language": "en" },
  { "code": "uk", "name": "United Kingdom", "timezone": "Europe/London", "language": "en" },
  { "code": "nl", "name": "Netherlands", "timezone": "Europe/Amsterdam", "language": "nl" },
  { "code": "de", "name": "Germany", "timezone": "Europe/Berlin", "language": "de" },
  { "code": "fr", "name": "France", "timezone": "Europe/Paris", "language": "fr" },
  { "code": "jp", "name": "Japan", "timezone": "Asia/Tokyo", "language": "ja" }
]
```

### Agent Configuration

Control autonomous agent behavior.

```json
{
  "agents": {
    "enabled": true,
    "maxConcurrent": 3,
    "retryAttempts": 3,
    "timeout": 30000
  }
}
```

**Settings:**

- **`enabled`** (boolean, default: `true`)
  - Enable/disable autonomous agents
  - `false` = Manual mode only

- **`maxConcurrent`** (number, 1-10, default: `3`)
  - Maximum agents running simultaneously
  - Higher = Faster parallel processing
  - Lower = Less resource usage
  - Recommendation: `3` for balanced performance

- **`retryAttempts`** (number, 0-5, default: `3`)
  - How many times to retry failed operations
  - `0` = No retries (fail immediately)
  - `3` = Three retries with exponential backoff

- **`timeout`** (number, milliseconds, default: `30000`)
  - Maximum time for agent operations
  - `30000` = 30 seconds
  - Increase for complex operations
  - Decrease for fast-fail behavior

### Logging Configuration

Control log output and retention.

```json
{
  "logging": {
    "level": "info",
    "outputPath": "./logs",
    "maxFileSize": "10MB",
    "maxFiles": 5
  }
}
```

**Settings:**

- **`level`** (string, default: `"info"`)
  - Logging verbosity
  - Options (least to most verbose):
    - `error` - Errors only
    - `warn` - Warnings and errors
    - `info` - General information (recommended)
    - `debug` - Detailed debugging info
    - `trace` - Extremely verbose (development only)

- **`outputPath`** (string, default: `"./logs"`)
  - Directory for log files
  - Relative to project root
  - Created automatically if missing

- **`maxFileSize`** (string, default: `"10MB"`)
  - Maximum size per log file
  - Format: `<number>MB` or `<number>KB`
  - Logs rotate when limit reached

- **`maxFiles`** (number, default: `5`)
  - Maximum number of log files to keep
  - Oldest files deleted when limit reached
  - Total disk space = `maxFileSize * maxFiles`

## MACHINE_CONFIG.md

Machine-specific path configuration. Edit this file to match your environment.

```markdown
BASE_REPO_PATH=C:\Projects               # Where main repos are cloned
WORKTREE_PATH=C:\Projects\worker-agents  # Where agent worktrees go
CONTROL_PLANE_PATH=C:\scripts            # This repository
MACHINE_CONTEXT_PATH=C:\scripts\_machine # Operational state files
```

**Variables:**

- **`BASE_REPO_PATH`**
  - Location of main project repositories
  - Windows: `C:\Projects` or `D:\Projects`
  - Linux/macOS: `~/projects` or `/opt/projects`

- **`WORKTREE_PATH`**
  - Location for agent worktrees
  - Should be a subdirectory of `BASE_REPO_PATH`
  - Format: `{BASE_REPO_PATH}/worker-agents`

- **`CONTROL_PLANE_PATH`**
  - Location of this repository
  - Windows: `C:\scripts`
  - Linux/macOS: `~/scripts`

- **`MACHINE_CONTEXT_PATH`**
  - Operational state files
  - Format: `{CONTROL_PLANE_PATH}/_machine`

## Vault Configuration

Encrypted credential storage. Use `vault.ps1` to manage secrets.

**Add credential:**
```powershell
vault.ps1 -Action set -Service "service-name" -Token "your-secret-key"
```

**Retrieve credential:**
```powershell
vault.ps1 -Action get -Service "service-name"
```

**List all credentials:**
```powershell
vault.ps1 -Action list
```

**Common vault services:**

| Service | Purpose | Format |
|---------|---------|--------|
| `openai` | OpenAI API key | `sk-...` |
| `clickup` | ClickUp API key | `pk_...` |
| `github` | GitHub token | `ghp_...` |
| `wordpress` | WordPress app password | `xxxx xxxx xxxx ...` |

## Environment-Specific Configuration

### Development

```json
{
  "logging": { "level": "debug" },
  "agents": { "maxConcurrent": 1, "timeout": 60000 }
}
```

### Production

```json
{
  "logging": { "level": "warn" },
  "agents": { "maxConcurrent": 5, "timeout": 30000 }
}
```

### Testing

```json
{
  "openai": { "model": "gpt-3.5-turbo", "temperature": 0.0 },
  "agents": { "enabled": false }
}
```

## Troubleshooting Configuration

### Issue: "API key invalid"

**Check:**
1. Verify key format (correct prefix: `sk-`, `pk_`, etc.)
2. Check expiration date
3. Verify key permissions
4. Test key directly at provider's website

### Issue: "Configuration file not found"

**Solution:**
```powershell
# Copy template
Copy-Item docs/config.template.json -Destination config.json

# Edit with your values
code config.json
```

### Issue: "Timezone not recognized"

**Solution:**

Use valid IANA timezone:
- NOT: `UTC+1`, `EST`, `GMT`
- YES: `America/New_York`, `Europe/Amsterdam`, `UTC`

Full list: [https://en.wikipedia.org/wiki/List_of_tz_database_time_zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)

## Best Practices

1. **Never commit API keys** - Use vault.ps1 for all secrets
2. **Test configuration changes** - Use small values first, then scale up
3. **Monitor logs** - Check `logs/` directory for errors
4. **Document customizations** - Add comments to config files
5. **Backup configuration** - Keep copies of working configs

## Next Steps

- **Start Using the System:** See `QUICK_START.md`
- **Explore Features:** Read `README.md`
- **Learn Workflows:** Browse `.claude/skills/`

---

**Configuration complete!** Your system is ready to use.
