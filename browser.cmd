@echo off
setlocal ENABLEDELAYEDEXPANSION

REM ================================
REM  Playwright Command Bridge
REM ================================

if "%~1"=="" (
    echo ERROR: No command file provided.
    echo Usage: browser.cmd ^<command.json^>
    exit /b 1
)

set CMD_FILE=%~1

if not exist "%CMD_FILE%" (
    echo ERROR: Command file not found: %CMD_FILE%
    exit /b 1
)

REM ---- Basic validation ----
findstr /R /C:"\"action\"" "%CMD_FILE%" >nul
if errorlevel 1 (
    echo ERROR: JSON file must contain an "action" field.
    exit /b 1
)

REM ---- Send command to Playwright agent ----
curl -s -X POST http://localhost:3333/cmd ^
  -H "Content-Type: application/json" ^
  --data-binary "@%CMD_FILE%"

exit /b %ERRORLEVEL%
