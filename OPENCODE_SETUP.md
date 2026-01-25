# OpenCode Agent Setup Guide

## Installation Complete ✅

OpenCode AI is installed and ready to use!

- **Version:** 1.1.28
- **Command:** `opencode`
- **Launcher:** `C:\scripts\oc.bat` or `CTRL+R → oc`

## Quick Start

### Launch OpenCode
```bash
# Via quick launcher
CTRL+R → oc

# Or directly
cd C:\scripts
opencode
```

## Differences from Claude Code

OpenCode and Claude Code have different architectures:

| Feature | Claude Code | OpenCode |
|---------|-------------|----------|
| **Interface** | CLI with system prompts | Interactive TUI |
| **Configuration** | Command-line flags | Agent configuration files |
| **System Prompts** | `--append-system-prompt` | Agent system messages |
| **Permissions** | `--dangerously-skip-permissions` | Built-in permission handling |

## Creating Custom Agents (Optional)

To create an autonomous agent similar to the Claude Code setup:

```bash
# Create a new agent
opencode agent create

# List available agents
opencode agent list

# Run with specific agent
opencode --agent <agent-name>
```

### Autonomous Agent Configuration

When creating an agent, you can configure it with instructions similar to the Claude agent's system prompt. The agent should:

1. **Read startup files:**
   - `C:\scripts\ZERO_TOLERANCE_RULES.md`
   - `C:\scripts\claude.md`
   - `C:\scripts\_machine\reflection.log.md`
   - `C:\scripts\_machine\worktrees.pool.md`

2. **Follow core directives:**
   - Autonomous execution
   - Self-improvement
   - Worktree-first development
   - Cross-repo coordination

3. **Use available tools:**
   - Git worktrees
   - GitHub CLI (`gh`)
   - Browser MCP
   - PowerShell scripts in `C:\scripts\tools\`

## Model Configuration

OpenCode supports multiple AI providers:

```bash
# List available models
opencode models

# Use specific model
opencode --model anthropic/claude-sonnet-4.5
opencode --model openai/gpt-4
opencode --model google/gemini-pro
```

## Session Management

```bash
# Continue last session
opencode --continue

# Continue specific session
opencode --session <session-id>

# List sessions
opencode session
```

## Advanced Options

```bash
# Start with a message/task
opencode run "Review code in src/ directory"

# Attach files
opencode run --file README.md "Summarize this file"

# Use with GitHub PR
opencode pr 123  # Checkout PR #123 and start OpenCode
```

## MCP (Model Context Protocol) Integration

OpenCode supports MCP for external integrations:

```bash
# Manage MCP servers
opencode mcp

# See available MCP integrations
opencode mcp list
```

## Web Interface

OpenCode includes a web interface:

```bash
# Start web UI
opencode web
```

## Documentation Access

All Claude agent documentation applies to OpenCode workflows:

- **Worktree Protocol:** `C:\scripts\worktree-workflow.md`
- **Dual Mode Workflow:** `C:\scripts\dual-mode-workflow.md`
- **Zero Tolerance Rules:** `C:\scripts\ZERO_TOLERANCE_RULES.md`
- **Tools Documentation:** `C:\scripts\tools\README.md`
- **Main Manual:** `C:\scripts\claude.md`

## Next Steps

1. **Test the launcher:** `CTRL+R → oc`
2. **Try OpenCode:** Interact with the TUI
3. **Create custom agent** (optional): `opencode agent create`
4. **Configure MCP servers** (optional): `opencode mcp`

## Troubleshooting

### Command not found
```bash
# Verify installation
opencode --version

# Reinstall if needed
npm install -g opencode-ai@latest
```

### Agent not loading
- OpenCode uses TUI by default
- Custom agents must be created with `opencode agent create`
- Use `--agent <name>` flag when starting

### Need help?
```bash
opencode --help
opencode agent --help
opencode run --help
```

## Resources

- **Official Docs:** https://opencode.ai/docs/
- **GitHub:** https://github.com/opencode-ai/opencode
- **npm Package:** https://www.npmjs.com/package/opencode-ai

---

**Created:** 2026-01-21
**OpenCode Version:** 1.1.28
