@echo off
REM Quick launcher for Bugatti Insights Frontend
REM Usage: CTRL+R → bi
REM Auto-validates node_modules before starting

start "Bugatti Insights Frontend" cmd /k "cd /d C:\Projects\bugattiinsights\sourcecode\frontend && (echo Checking node_modules... && npm list --depth=0 >nul 2>&1 || (echo [WARNING] Running npm install... && npm install)) && echo [OK] Starting dev server... && npm run dev"
