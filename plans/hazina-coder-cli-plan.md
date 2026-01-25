# HazinaCoder CLI - Comprehensive Implementation Plan

**Created:** 2026-01-21
**Goal:** Build a Claude Code CLI alternative using the Hazina framework with multi-provider support
**User Request:** "a coding tool that can do the same things as claude code can but then it should use the hazina framework"

---

## Executive Summary

Build `HazinaCoder` - a production-ready, multi-provider coding assistant CLI that replicates Claude Code's functionality using the Hazina AI framework. The tool will support OpenAI, Anthropic Claude, Google Gemini, Ollama (local), Mistral, and more through a unified interface.

---

## 50-Expert Consultation

### Category 1: Architecture & Design (Experts 1-10)

**Expert 1 - Software Architect (Enterprise)**
> "Use a provider factory pattern with dependency injection. The CLI should be provider-agnostic at its core, with provider-specific adapters implementing a common interface (already exists as `ILLMClient`)."

**Expert 2 - CLI/UX Designer**
> "Support multiple interaction modes: (1) Interactive REPL, (2) Single-command execution, (3) Piped input. Add color-coded output for tools vs assistant responses. Consider Spectre.Console for rich terminal output."

**Expert 3 - API Integration Specialist**
> "The existing Anthropic client lacks tool calling support. This is CRITICAL - without it, Claude can't use tools. Implement Anthropic's tool_use/tool_result message types per their Messages API spec."

**Expert 4 - Configuration Expert**
> "Use a layered config approach: (1) Environment variables, (2) Config file (~/.hazinacoder/config.json), (3) Command-line args. Support multiple provider profiles for easy switching."

**Expert 5 - Performance Engineer**
> "Implement true streaming for all providers. The current Anthropic client fakes streaming by chunking. Use Server-Sent Events (SSE) parsing for Anthropic's streaming API."

**Expert 6 - Security Architect**
> "API keys should NEVER be in code. Support: (1) Environment variables, (2) Secure credential store (Windows Credential Manager / macOS Keychain), (3) Config file with proper permissions."

**Expert 7 - Plugin Architecture Expert**
> "Design the tool system to be extensible. Allow users to register custom tools via a plugin directory or configuration. Tools should be hot-loadable."

**Expert 8 - State Management Expert**
> "Implement conversation persistence. Save/load sessions to allow resuming work. Use SQLite or JSON files for session storage."

**Expert 9 - Error Handling Specialist**
> "Wrap all provider calls with retry logic and exponential backoff. Handle rate limits, network errors, and provider-specific error codes gracefully."

**Expert 10 - Cross-Platform Expert**
> "Ensure the CLI works on Windows, macOS, and Linux. Use .NET's `RuntimeInformation` for platform detection. The BashTool already handles this."

### Category 2: LLM Provider Integration (Experts 11-20)

**Expert 11 - OpenAI API Expert**
> "OpenAI implementation is solid. Ensure you're using the latest `gpt-4o` model which has the best tool-calling performance. Consider adding `gpt-4o-mini` as a fast/cheap option."

**Expert 12 - Anthropic Claude Expert**
> "CRITICAL GAP: The current `ClaudeClientWrapper` doesn't support tool calling. Anthropic's Messages API uses:
> - `tool_use` content blocks for the model requesting tool calls
> - `tool_result` content blocks for providing results back
> The streaming endpoint is `/v1/messages` with `stream: true`."

**Expert 13 - Google Gemini Expert**
> "Gemini supports function calling through `function_declarations`. The response includes `function_call` parts. Map these to Hazina's tool system."

**Expert 14 - Ollama/Local LLM Expert**
> "For local models, Ollama's function calling depends on the model. Some like `llama3.1` support tools, others don't. Gracefully degrade to prompt-based tool simulation if needed."

**Expert 15 - Mistral Expert**
> "Mistral's API closely mirrors OpenAI's function calling format. Should be straightforward to implement tool support."

**Expert 16 - Token Optimization Expert**
> "Implement context window management. When conversation exceeds limits, use summarization or sliding window. Track token counts per provider (they differ)."

**Expert 17 - Model Selection Expert**
> "Allow model switching mid-session. Some tasks need expensive models (complex reasoning), others need fast models (simple edits). Add `/model <name>` command."

**Expert 18 - Embeddings Expert**
> "For future RAG integration, ensure embedding support. OpenAI's `text-embedding-3-small` is cost-effective. Store embeddings for code indexing."

**Expert 19 - Multi-Modal Expert**
> "Support image input for providers that support it (GPT-4o, Claude 3). Useful for UI debugging, screenshot analysis, diagram interpretation."

**Expert 20 - Cost Tracking Expert**
> "The Hazina framework already tracks costs. Expose this to users with `/cost` command showing session costs by provider."

### Category 3: Tool System (Experts 21-30)

**Expert 21 - File System Expert**
> "Existing tools (read_file, write_file, edit_file, glob, grep) are solid. Add:
> - `list_directory` - Better than bash for cross-platform
> - `search_replace` - Regex-based bulk replacement
> - `diff` - Show unified diff before edits"

**Expert 22 - Code Analysis Expert**
> "Add code intelligence tools:
> - `syntax_check` - Validate code without running
> - `format_code` - Run formatters (prettier, black, dotnet format)
> - `find_references` - Find usages of symbols"

**Expert 23 - Build System Expert**
> "Add build-aware tools:
> - `build_project` - Smart build (detects project type)
> - `run_tests` - Execute test frameworks
> - `check_dependencies` - Audit package versions"

**Expert 24 - Git Expert**
> "Add Git-specific tools:
> - `git_status` - Structured git status
> - `git_diff` - Show current changes
> - `git_commit` - Commit with message
> - `git_log` - Recent commit history"

**Expert 25 - Process Execution Expert**
> "The BashTool is good but needs:
> - Timeout configuration
> - Working directory override
> - Environment variable injection
> - Background process support"

**Expert 26 - Web/API Tool Expert**
> "Add network tools:
> - `web_fetch` - HTTP GET with response parsing
> - `api_request` - Full HTTP method support
> - `web_search` - Internet search integration"

**Expert 27 - Database Tool Expert**
> "For database-heavy projects:
> - `query_database` - Run SQL queries
> - `show_schema` - Display table structures
> - `migration_status` - EF Core migration state"

**Expert 28 - Documentation Tool Expert**
> "Add documentation helpers:
> - `read_docs` - Parse README, API docs
> - `search_docs` - Full-text search in docs
> - `generate_docs` - Create doc skeletons"

**Expert 29 - Testing Tool Expert**
> "Testing-specific tools:
> - `run_test` - Execute specific test
> - `coverage_report` - Get test coverage
> - `generate_test` - Scaffold test files"

**Expert 30 - Security Tool Expert**
> "Security scanning tools:
> - `scan_secrets` - Detect exposed credentials
> - `check_vulnerabilities` - Package vulnerability scan
> - `lint_security` - Security-focused linting"

### Category 4: User Experience (Experts 31-40)

**Expert 31 - Terminal UX Expert**
> "Use Spectre.Console for:
> - Progress spinners during long operations
> - Syntax-highlighted code blocks
> - Table output for structured data
> - Interactive prompts for confirmations"

**Expert 32 - Keyboard/Input Expert**
> "Support readline-style editing:
> - Command history (up/down arrows)
> - Multi-line input (paste or Shift+Enter)
> - Tab completion for files/commands"

**Expert 33 - Output Formatting Expert**
> "Distinguish output types with colors:
> - Green: Assistant responses
> - Cyan: Tool calls
> - Yellow: Warnings
> - Red: Errors
> - Gray: Debug/verbose info"

**Expert 34 - Markdown Rendering Expert**
> "Render markdown in terminal:
> - Code blocks with syntax highlighting
> - Lists and headers
> - Bold/italic text
> Consider Markdig for parsing + Spectre for rendering."

**Expert 35 - Logging Expert**
> "Implement structured logging:
> - Console output (user-facing)
> - File log (debug, ~/.hazinacoder/logs/)
> - Structured JSON for analysis"

**Expert 36 - Session Management Expert**
> "Session commands:
> - `/save [name]` - Save current session
> - `/load [name]` - Load previous session
> - `/clear` - Clear conversation
> - `/history` - Show conversation summary"

**Expert 37 - Help System Expert**
> "Comprehensive help:
> - `/help` - General help
> - `/help <tool>` - Tool-specific help
> - `/tools` - List available tools
> - `/commands` - List slash commands"

**Expert 38 - Prompt Engineering Expert**
> "Craft the system prompt carefully:
> - Define the assistant's identity
> - Explain each tool's purpose
> - Set behavior expectations
> - Include examples for complex tools"

**Expert 39 - Context Window Expert**
> "Show token usage:
> - `/tokens` - Current context size
> - Visual indicator when approaching limit
> - Auto-summarize when needed"

**Expert 40 - Accessibility Expert**
> "Ensure accessibility:
> - Screen reader friendly output
> - No reliance on color alone
> - Clear structure in output"

### Category 5: Implementation & Testing (Experts 41-50)

**Expert 41 - .NET Best Practices Expert**
> "Use:
> - Minimal APIs / top-level statements for CLI
> - `System.CommandLine` for argument parsing
> - Nullable reference types
> - Record types for DTOs"

**Expert 42 - Dependency Injection Expert**
> "Wire up services:
> - `ILLMClient` registered based on provider
> - `IToolsContext` for tool registry
> - `IConfiguration` for settings"

**Expert 43 - Unit Testing Expert**
> "Test coverage for:
> - Tool execution (mock file system)
> - Provider selection logic
> - Configuration parsing
> - Error handling paths"

**Expert 44 - Integration Testing Expert**
> "E2E tests with:
> - Recorded/mocked API responses
> - Real file system operations (temp dirs)
> - Process execution verification"

**Expert 45 - Documentation Expert**
> "Document:
> - Installation steps
> - Configuration options
> - Available tools
> - Provider setup guides"

**Expert 46 - CI/CD Expert**
> "Build pipeline:
> - dotnet build/test
> - Cross-platform verification
> - NuGet packaging
> - Release automation"

**Expert 47 - Package Distribution Expert**
> "Distribution options:
> - .NET tool (dotnet tool install)
> - Standalone executables (win-x64, linux-x64, osx-arm64)
> - Scoop/Homebrew packages"

**Expert 48 - Telemetry Expert**
> "Optional anonymous telemetry:
> - Error rates by provider
> - Tool usage patterns
> - Performance metrics
> Opt-in only, with clear disclosure."

**Expert 49 - Backward Compatibility Expert**
> "Version the configuration format. Support migration from older configs. Maintain API stability for tool implementations."

**Expert 50 - Future-Proofing Expert**
> "Design for extensibility:
> - MCP (Model Context Protocol) server support
> - Agent orchestration capabilities
> - RAG integration points
> - Voice input/output"

---

## Critical Gaps to Address

### Gap 1: Anthropic Tool Calling (BLOCKING)
The current `ClaudeClientWrapper` does NOT support tool calling. Without this, the CLI is useless with Claude. **Must implement Anthropic's tool_use/tool_result message protocol.**

### Gap 2: True Streaming for Anthropic
Current implementation fakes streaming by chunking. Need real SSE parsing for responsive UX.

### Gap 3: Provider Selection at Runtime
Need dynamic provider switching without restart.

---

## Implementation Plan

### Phase 1: Foundation (Core Infrastructure)

**1.1 Create Project Structure**
```
apps/CLI/Hazina.App.HazinaCoder/
├── Hazina.App.HazinaCoder.csproj
├── Program.cs                    # Entry point
├── Configuration/
│   ├── HazinaCoderConfig.cs     # Main config model
│   ├── ProviderConfig.cs        # Provider-specific configs
│   └── ConfigLoader.cs          # Config loading logic
├── Providers/
│   ├── ProviderFactory.cs       # Create provider by name
│   └── ProviderRegistry.cs      # Available providers
├── Commands/
│   ├── CommandHandler.cs        # Slash command router
│   └── Commands/                # Individual commands
├── Tools/
│   ├── ExtendedToolsContext.cs  # Enhanced tool set
│   └── Additional/              # New tools
└── UI/
    ├── ConsoleRenderer.cs       # Rich output
    └── InputHandler.cs          # Readline-style input
```

**1.2 Core Dependencies**
- Spectre.Console (rich terminal UI)
- System.CommandLine (argument parsing)
- Microsoft.Extensions.Configuration
- Microsoft.Extensions.DependencyInjection

### Phase 2: Anthropic Tool Calling (CRITICAL)

**2.1 Update ClaudeClientWrapper**
- Implement `tool_use` detection in responses
- Implement `tool_result` message construction
- Add streaming with SSE parsing
- Handle tool call loops (model calls tool → result → continue)

**2.2 Message Type Extensions**
```csharp
// New message content types for Anthropic
public class ToolUseContent
{
    public string Id { get; set; }
    public string Name { get; set; }
    public JsonElement Input { get; set; }
}

public class ToolResultContent
{
    public string ToolUseId { get; set; }
    public string Content { get; set; }
}
```

### Phase 3: Multi-Provider CLI

**3.1 Configuration System**
```json
// ~/.hazinacoder/config.json
{
  "defaultProvider": "openai",
  "providers": {
    "openai": {
      "apiKey": "${OPENAI_API_KEY}",
      "model": "gpt-4o"
    },
    "anthropic": {
      "apiKey": "${ANTHROPIC_API_KEY}",
      "model": "claude-sonnet-4-20250514"
    },
    "ollama": {
      "endpoint": "http://localhost:11434",
      "model": "llama3.1"
    }
  },
  "defaultWorkingDirectory": ".",
  "historyFile": "~/.hazinacoder/history.txt",
  "maxTokens": 8192
}
```

**3.2 Provider Factory**
```csharp
public class ProviderFactory
{
    public ILLMClient CreateProvider(string name, IConfiguration config)
    {
        return name.ToLower() switch
        {
            "openai" => new OpenAIClientWrapper(OpenAIConfig.FromConfig(config)),
            "anthropic" => new ClaudeClientWrapper(AnthropicConfig.FromConfig(config)),
            "gemini" => new GeminiClientWrapper(GeminiConfig.FromConfig(config)),
            "ollama" => new OllamaClientWrapper(OllamaConfig.FromConfig(config)),
            "mistral" => new MistralClientWrapper(MistralConfig.FromConfig(config)),
            _ => throw new ArgumentException($"Unknown provider: {name}")
        };
    }
}
```

### Phase 4: Enhanced Tool Set

**4.1 Additional Tools**
| Tool | Purpose |
|------|---------|
| `list_directory` | Cross-platform directory listing |
| `web_fetch` | HTTP requests with response parsing |
| `git_status` | Structured git information |
| `git_diff` | Show working tree changes |
| `search_replace` | Regex-based bulk edits |
| `syntax_check` | Validate code syntax |

### Phase 5: User Experience

**5.1 Slash Commands**
| Command | Description |
|---------|-------------|
| `/help` | Show help |
| `/provider <name>` | Switch provider |
| `/model <name>` | Switch model |
| `/tools` | List available tools |
| `/clear` | Clear conversation |
| `/save [name]` | Save session |
| `/load [name]` | Load session |
| `/cost` | Show session costs |
| `/tokens` | Show token usage |
| `/exit` | Exit CLI |

**5.2 Rich Terminal Output**
- Spectre.Console for colors and formatting
- Syntax-highlighted code blocks
- Progress spinners for tool execution
- Tables for structured data

### Phase 6: Testing & Documentation

**6.1 Test Coverage**
- Unit tests for tools
- Integration tests for providers
- E2E tests for CLI flows

**6.2 Documentation**
- README with setup instructions
- Provider configuration guides
- Tool reference documentation

---

## File Modifications Required

### New Files
1. `apps/CLI/Hazina.App.HazinaCoder/` - Entire new project
2. `src/Hazina.Agents.Tools/Additional/` - New tools

### Modified Files
1. `src/Core/LLMs.Providers/Hazina.LLMs.Anthropic/ClaudeClientWrapper.cs` - **ADD TOOL CALLING**
2. `src/Hazina.Agents.Tools/Context/ClaudeCodeToolsContext.cs` - Add new tools
3. `Hazina.sln` / `Hazina.Apps.sln` - Add new project

---

## Success Criteria

1. **Multi-Provider**: User can switch between OpenAI, Claude, Gemini, Ollama, Mistral
2. **Tool Calling Works**: All providers that support tools can use read/write/edit/bash/glob/grep
3. **Streaming**: Real-time token display for all providers
4. **Claude Parity**: Achieves functional parity with Claude Code CLI
5. **Configuration**: Easy provider setup via config file or environment variables
6. **Cross-Platform**: Works on Windows, macOS, Linux

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Anthropic tool calling complexity | Follow official API docs exactly, test thoroughly |
| Provider API changes | Version pin SDKs, monitor changelogs |
| Context window limits | Implement token tracking and summarization |
| Cross-platform issues | Test on all platforms in CI |

---

## Timeline Estimate

| Phase | Effort |
|-------|--------|
| Phase 1: Foundation | Small |
| Phase 2: Anthropic Tools | Medium (critical path) |
| Phase 3: Multi-Provider CLI | Medium |
| Phase 4: Enhanced Tools | Small |
| Phase 5: UX Polish | Small |
| Phase 6: Testing & Docs | Small |

---

## Recommendation

**Start with Phase 2 (Anthropic Tool Calling)** - This is the critical gap. The existing `Hazina.App.ClaudeCode` already works for OpenAI. Fixing Claude support unlocks the most value.

Then proceed to Phase 3 (Multi-Provider CLI) which wraps everything in a configurable, user-friendly package.

---

*Plan created: 2026-01-21*
*Experts consulted: 50*
*Status: Ready for implementation*
