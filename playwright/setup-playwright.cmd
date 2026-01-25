@echo off
setlocal ENABLEDELAYEDEXPANSION

echo === Playwright setup & start ===
echo Folder: %CD%
echo.

REM ---- 1. Check Node.js ----
where node >nul 2>nul
if errorlevel 1 (
    echo ERROR: Node.js not found in PATH.
    echo Install Node.js first: https://nodejs.org/
    goto :EOF
)

node -v
echo.

REM ---- 2. Initialize npm if needed ----
if not exist package.json (
    echo Initializing npm project...
    npm init -y
    if errorlevel 1 goto error
) else (
    echo package.json already exists.
)
echo.

REM ---- 3. Install Playwright if missing ----
if not exist node_modules\playwright (
    echo Installing Playwright...
    npm install playwright
    if errorlevel 1 goto error
) else (
    echo Playwright already installed.
)
echo.

REM ---- 4. Install browser binaries (safe method) ----
echo Installing Playwright browsers...
node node_modules\playwright\cli.js install
if errorlevel 1 goto error
echo.

goto :EOF

:error
echo.
echo ERROR: Setup failed.
echo Check the output above for details.
pause
