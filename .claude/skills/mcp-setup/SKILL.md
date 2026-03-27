# MCP Server Setup Skill

**Description:** Configure MCP (Model Context Protocol) servers to extend Claude Code capabilities with external integrations like Google Drive, databases, APIs, and more.

**Use when:** User wants to add integrations, connect external services, or extend Claude's capabilities beyond built-in tools.

---

## Quick Reference

### Add MCP Server (CLI)

```bash
# User-level (all projects)
claude mcp add <name> -s user -- <command> [args...]

# Project-level (current project only)
claude mcp add <name> -- <command> [args...]
```

### Configuration Location

| Scope | Location |
|-------|----------|
| User | `~/.claude.json` → `mcpServers` object |
| Project | `~/.claude.json` → `projects["path"].mcpServers` |

---

## Common MCP Servers

### Google Drive

**Package:** `@modelcontextprotocol/server-gdrive`

**Prerequisites:**
1. Google Cloud Project with Drive API enabled
2. OAuth 2.0 credentials (Desktop app type)
3. OAuth JSON file downloaded

**Setup:**
```bash
claude mcp add gdrive -s user -- npx -y @modelcontextprotocol/server-gdrive
```

**Environment Variables (add to ~/.claude.json):**
```json
{
  "mcpServers": {
    "gdrive": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-gdrive"],
      "env": {
        "GDRIVE_OAUTH_PATH": "C:\\path\\to\\gcp-oauth.keys.json",
        "GDRIVE_CREDENTIALS_PATH": "C:\\path\\to\\gdrive-credentials.json"
      }
    }
  }
}
```

**OAuth Setup Steps:**
1. Google Cloud Console → Create project
2. APIs & Services → Library → Enable "Google Drive API"
3. APIs & Services → OAuth consent screen → Configure (External, add test users)
4. APIs & Services → Credentials → Create OAuth client ID → Desktop app
5. Download JSON → Save as `gcp-oauth.keys.json`

### Filesystem (Extended)

**Package:** `@modelcontextprotocol/server-filesystem`

```bash
claude mcp add filesystem -s user -- npx -y @modelcontextprotocol/server-filesystem /path/to/allow
```

### GitHub

**Package:** `@modelcontextprotocol/server-github`

```bash
claude mcp add github -s user -- npx -y @modelcontextprotocol/server-github
```

**Requires:** `GITHUB_TOKEN` environment variable

### PostgreSQL

**Package:** `@modelcontextprotocol/server-postgres`

```bash
claude mcp add postgres -- npx -y @modelcontextprotocol/server-postgres postgresql://user:pass@host/db
```

### Brave Search

**Package:** `@modelcontextprotocol/server-brave-search`

```bash
claude mcp add brave -s user -- npx -y @modelcontextprotocol/server-brave-search
```

**Requires:** `BRAVE_API_KEY` environment variable

---

## Configuration Structure

### Full MCP Server Config

```json
{
  "mcpServers": {
    "<server-name>": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "<package-name>", "arg1", "arg2"],
      "env": {
        "API_KEY": "value",
        "CONFIG_PATH": "/path/to/config"
      }
    }
  }
}
```

### Docker-based Server

```json
{
  "mcpServers": {
    "<server-name>": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-v", "/host/path:/container/path",
        "-e", "ENV_VAR=value",
        "image-name"
      ]
    }
  }
}
```

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| MCP not loading | JSON syntax error | Validate `~/.claude.json` with `jq` |
| MCP not loading | Server crashed | Check npm package exists, run manually |
| "Access denied" | Missing credentials | Check env vars, OAuth setup |
| Tools not appearing | Wrong scope | Use `-s user` for global access |
| OAuth redirect failed | Wrong app type | Use "Desktop app", not "Web app" |

### Debug MCP Server

```bash
# Test server manually
npx -y @modelcontextprotocol/server-gdrive

# Check Claude config
cat ~/.claude.json | jq '.mcpServers'

# List configured servers
claude mcp list
```

---

## Post-Setup Checklist

1. [ ] Restart Claude Code (MCP servers initialize on startup)
2. [ ] Complete any OAuth flows (browser opens automatically)
3. [ ] Test with a simple command (e.g., "list my Drive files")
4. [ ] Verify tools appear in Claude's capabilities

---

## Machine-Specific Paths

| Item | Path |
|------|------|
| OAuth Keys | `C:\scripts\_machine\gcp-oauth.keys.json` |
| Drive Credentials | `C:\scripts\_machine\gdrive-credentials.json` |
| Claude Config | `C:\Users\HP\.claude.json` |

---

## References

- [MCP Specification](https://modelcontextprotocol.io/)
- [Official MCP Servers](https://github.com/modelcontextprotocol/servers)
- [Claude Code MCP Docs](https://docs.anthropic.com/claude-code/mcp)
