@echo off
setlocal ENABLEDELAYEDEXPANSION

REM ---- 5. Start Playwright agent ----
if not exist playwright.js (
    echo ERROR: playwright.js not found in this folder.
    echo Create your Playwright agent file first.
    goto :EOF
)

echo Starting Playwright agent...
echo (Press Ctrl+C to stop)
echo.

node playwright.js
