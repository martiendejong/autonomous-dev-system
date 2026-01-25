@echo off
echo ========================================
echo Brand2Boost Nightly Backup Setup
echo ========================================
echo.
echo This will set up a nightly backup at 3:00 AM
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0register-backup-task.ps1"
echo.
echo Press any key to exit...
pause >nul
