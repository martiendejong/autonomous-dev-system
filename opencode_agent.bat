@echo off
setlocal enabledelayedexpansion

REM --- Enable ANSI escape sequences for color support ---
REM Modern Windows 10+ supports ANSI codes by default
REM Set initial terminal color to IDLE state (black background)
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\scripts\set-state-color.ps1" -State idle 2>nul

REM --- Set dynamic window title ---
REM Try to get current branch name, otherwise use default
for /f "tokens=*" %%i in ('git branch --show-current 2^>nul') do set BRANCH=%%i
if defined BRANCH (
    REM Convert branch name to uppercase for visibility
    for /f "tokens=*" %%a in ('powershell -Command "\"!BRANCH!\".ToUpper()"') do set BRANCH_UPPER=%%a
    title ⚪ IDLE - !BRANCH_UPPER! [OpenCode]
) else (
    title ⚪ OPENCODE AGENT - IDLE
)

REM --- Git checkpoint ---
git add .
git commit -m "checkpoint before opencode agent session" >nul 2>&1

REM --- OpenCode Autonomous Agent ---
REM --- Based on claude_agent.bat structure ---
REM --- Features: ---
REM --- 1. Explicit file reading instructions at startup ---
REM --- 2. Self-improvement mandate built into prompt ---
REM --- 3. Cross-repo dependency awareness ---
REM --- 4. Parallel agent coordination ---
REM --- 5. CI/CD troubleshooting capabilities ---
REM --- 6. Machine-wide resource management ---

REM --- OpenCode Configuration ---
REM NOTE: OpenCode uses a different approach than Claude Code
REM It supports custom agents via configuration files
REM For now, we'll use the default interactive mode
REM To configure custom behavior, use: opencode agent command

REM --- Start OpenCode ---
echo Starting OpenCode Autonomous Agent...
echo.
echo NOTE: OpenCode uses interactive TUI mode
echo Configure custom agents with: opencode agent
echo Documentation stored in: C:\scripts\claude.md
echo.
echo Available capabilities:
echo   - Full file system access
echo   - Git worktree management (see C:\scripts\claude.md)
echo   - Cross-repo dependency tracking
echo   - CI/CD troubleshooting
echo.

REM Start OpenCode in current directory (C:\scripts)
opencode

pause
