@echo off
echo ========================================
echo  Dynamic Window Color Test
echo ========================================
echo.
echo This script demonstrates the color changes
echo for different Claude Code execution states.
echo.
pause

echo.
echo [1/4] Testing IDLE state (Black background)...
call C:\scripts\color-idle.bat
timeout /t 2 >nul

echo.
echo [2/4] Testing RUNNING state (Blue background)...
call C:\scripts\color-running.bat
timeout /t 2 >nul

echo.
echo [3/4] Testing BLOCKED state (Red background)...
call C:\scripts\color-blocked.bat
timeout /t 2 >nul

echo.
echo [4/4] Testing COMPLETE state (Green background)...
call C:\scripts\color-complete.bat
timeout /t 2 >nul

echo.
echo Test complete! Returning to IDLE state...
timeout /t 1 >nul
call C:\scripts\color-idle.bat

echo.
echo ========================================
echo  All color states tested successfully!
echo ========================================
echo.
pause
