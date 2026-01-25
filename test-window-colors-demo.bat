@echo off
echo ========================================
echo Dynamic Window Color Demo
echo ========================================
echo.
echo This demo shows all 4 window states:
echo - BLUE icon   = Work in progress
echo - RED icon    = Problem/blocked
echo - GREEN icon  = Task complete
echo - WHITE icon  = Idle/ready
echo.
echo Watch the window title and background color change!
echo.
pause

echo.
echo [1/4] Setting to RUNNING state (BLUE)...
call C:\scripts\color-running.bat
echo Window should now be BLUE with blue circle icon
timeout /t 3 /nobreak

echo.
echo [2/4] Setting to BLOCKED state (RED)...
call C:\scripts\color-blocked.bat
echo Window should now be RED with red circle icon
timeout /t 3 /nobreak

echo.
echo [3/4] Setting to COMPLETE state (GREEN)...
call C:\scripts\color-complete.bat
echo Window should now be GREEN with green circle icon
timeout /t 3 /nobreak

echo.
echo [4/4] Setting to IDLE state (BLACK)...
call C:\scripts\color-idle.bat
echo Window should now be BLACK with white circle icon
timeout /t 3 /nobreak

echo.
echo ========================================
echo Demo complete!
echo ========================================
echo.
echo You can manually trigger these states using:
echo   C:\scripts\color-running.bat   - When starting work
echo   C:\scripts\color-blocked.bat   - When waiting for user input
echo   C:\scripts\color-complete.bat  - When task is done
echo   C:\scripts\color-idle.bat      - When ready for next task
echo.
pause
