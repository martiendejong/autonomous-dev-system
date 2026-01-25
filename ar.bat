@echo off
REM Quick launcher for ArtRevisionist Frontend
REM Usage: CTRL+R → ar
REM Auto-validates node_modules before starting

start "ArtRevisionist Frontend" cmd /k "cd /d C:\Projects\artrevisionist\artrevisionist && (echo Checking node_modules... && npm list --depth=0 >nul 2>&1 || (echo [WARNING] Running npm install... && npm install)) && echo [OK] Starting dev server... && npm run dev"
