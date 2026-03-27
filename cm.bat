@echo off
REM Quick launcher for Client Manager Frontend
REM Usage: CTRL+R → cm
REM Auto-validates node_modules before starting

start "Client Manager Frontend" cmd /k "cd /d C:\Projects\your-project\ClientManagerFrontend && (echo Checking node_modules... && npm list --depth=0 >nul 2>&1 || (echo [WARNING] Running npm install... && npm install)) && echo [OK] Starting dev server... && npm run dev"
