@echo off
REM ============================================================
REM codex_yolo.cmd — Autonomous Codex CLI Runner for Windows
REM ============================================================
REM - Forces Codex CLI into full YOLO mode
REM - No confirmations ever
REM - Autonomous shell + file writes
REM - Auto-commits each step (from codex.toml config)
REM - Uses your codex.toml system prompt automatically
REM ============================================================

SETLOCAL ENABLEDELAYEDEXPANSION

REM Show active directory
echo [codex_yolo] Working directory: %CD%

REM Forward all arguments to codex in YOLO mode
codex

ENDLOCAL