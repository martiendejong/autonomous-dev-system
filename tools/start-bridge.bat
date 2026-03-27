@echo off
echo Starting Claude Bridge Server...
echo.
cd /d C:\scripts\tools
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "claude-bridge-server.ps1" -Debug
pause
