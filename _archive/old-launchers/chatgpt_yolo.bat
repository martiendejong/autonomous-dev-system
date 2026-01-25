@echo off

REM --- Git checkpoint ---
git add .
git commit -m "checkpoint before YOLO" >nul 2>&1

REM --- Optional branch creation ---
set /p BRANCHNAME=Enter new branch name (leave empty to skip):
if not "%BRANCHNAME%"=="" (
    git checkout -b "%BRANCHNAME%"
)

echo.
echo =============================================
echo   Starting Codex YOLO mode...
echo   Using model and system prompt from config.toml
echo =============================================
echo.

codex

pause