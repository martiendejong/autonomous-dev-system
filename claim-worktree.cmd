@echo off
REM claim-worktree.cmd - Claim a FREE agent worktree and checkout git worktrees
REM Usage: claim-worktree.cmd <branch-name> [task-description]
REM Example: claim-worktree.cmd feature/new-feature "Implementing new feature X"
REM
REM This script:
REM 1. Finds a FREE agent from worktrees.pool.md
REM 2. Ensures base repos (client-manager, hazina) are on develop and up-to-date
REM 3. Creates git worktrees for both repos in the agent folder
REM 4. Marks the agent as BUSY in the pool
REM 5. Logs the allocation in worktrees.activity.md
REM
REM WARNING: This script modifies critical worktree pool files.
REM          Only one instance should run at a time to prevent conflicts.

setlocal enabledelayedexpansion

REM === PARAMETER VALIDATION ===
if "%~1"=="" (
    echo ERROR: Branch name is required
    echo Usage: claim-worktree.cmd ^<branch-name^> [task-description]
    echo Example: claim-worktree.cmd feature/new-feature "Implementing new feature X"
    exit /b 1
)

set BRANCH_NAME=%~1
set TASK_DESC=%~2
if "%TASK_DESC%"=="" set TASK_DESC=Working on %BRANCH_NAME%

REM === PATHS ===
set POOL_FILE=C:\scripts\_machine\worktrees.pool.md
set ACTIVITY_FILE=C:\scripts\_machine\worktrees.activity.md
set BASE_CLIENT_MANAGER=C:\Projects\client-manager
set BASE_HAZINA=C:\Projects\hazina
set WORKTREE_ROOT=C:\Projects\worker-agents

REM === VERIFY FILES EXIST ===
if not exist "%POOL_FILE%" (
    echo ERROR: Pool file not found: %POOL_FILE%
    exit /b 1
)
if not exist "%ACTIVITY_FILE%" (
    echo ERROR: Activity file not found: %ACTIVITY_FILE%
    exit /b 1
)

REM === STEP 1: FIND FREE AGENT ===
echo.
echo === STEP 1: Finding FREE agent ===
set AGENT_SEAT=
for /f "tokens=1,5 delims=|" %%a in ('type "%POOL_FILE%"') do (
    set "SEAT=%%a"
    set "SEAT=!SEAT: =!"
    set "STATUS=%%b"
    set "STATUS=!STATUS: =!"
    REM Check if this is a valid agent line (starts with agent-) and is FREE
    echo !SEAT! | findstr /r "^agent-" >nul 2>&1
    if !errorlevel! equ 0 (
        if "!STATUS!"=="FREE" (
            set "AGENT_SEAT=!SEAT!"
            goto :found_agent
        )
    )
)

:found_agent
if "%AGENT_SEAT%"=="" (
    echo ERROR: No FREE agents available in pool
    echo Run: type "%POOL_FILE%" to see current allocations
    echo Consider releasing a BUSY agent or provisioning a new one
    exit /b 1
)

echo Found FREE agent: %AGENT_SEAT%
set AGENT_PATH=%WORKTREE_ROOT%\%AGENT_SEAT%

REM === STEP 2: ENSURE BASE REPOS ON DEVELOP AND UP-TO-DATE ===
echo.
echo === STEP 2: Ensuring base repos are on develop and up-to-date ===

REM --- CLIENT-MANAGER ---
echo Checking client-manager...
cd /d "%BASE_CLIENT_MANAGER%" || (
    echo ERROR: Cannot access %BASE_CLIENT_MANAGER%
    exit /b 1
)

for /f %%i in ('git branch --show-current') do set CURRENT_BRANCH=%%i
if not "%CURRENT_BRANCH%"=="develop" (
    echo WARNING: client-manager on branch %CURRENT_BRANCH%, switching to develop
    git checkout develop || (
        echo ERROR: Failed to checkout develop in client-manager
        exit /b 1
    )
)

echo Fetching latest changes for client-manager...
git fetch origin --prune || (
    echo ERROR: Failed to fetch client-manager
    exit /b 1
)

echo Pulling latest develop for client-manager...
git pull origin develop || (
    echo ERROR: Failed to pull client-manager develop
    exit /b 1
)

REM --- HAZINA ---
echo.
echo Checking hazina...
cd /d "%BASE_HAZINA%" || (
    echo ERROR: Cannot access %BASE_HAZINA%
    exit /b 1
)

for /f %%i in ('git branch --show-current') do set CURRENT_BRANCH=%%i
if not "%CURRENT_BRANCH%"=="develop" (
    echo WARNING: hazina on branch %CURRENT_BRANCH%, switching to develop
    git checkout develop || (
        echo ERROR: Failed to checkout develop in hazina
        exit /b 1
    )
)

echo Fetching latest changes for hazina...
git fetch origin --prune || (
    echo ERROR: Failed to fetch hazina
    exit /b 1
)

echo Pulling latest develop for hazina...
git pull origin develop || (
    echo ERROR: Failed to pull hazina develop
    exit /b 1
)

echo Base repos are ready (both on develop with latest changes)

REM === STEP 3: CREATE WORKTREES ===
echo.
echo === STEP 3: Creating worktrees in %AGENT_PATH% ===

REM Create agent directory if it doesn't exist
if not exist "%AGENT_PATH%" mkdir "%AGENT_PATH%"

REM --- CREATE CLIENT-MANAGER WORKTREE ---
echo Creating client-manager worktree with branch %BRANCH_NAME%...
cd /d "%BASE_CLIENT_MANAGER%"
git worktree add "%AGENT_PATH%\client-manager" -b %BRANCH_NAME% || (
    echo ERROR: Failed to create client-manager worktree
    echo This might mean the branch already exists. Check: git branch -a ^| grep %BRANCH_NAME%
    exit /b 1
)

REM --- CREATE HAZINA WORKTREE ---
echo Creating hazina worktree with branch %BRANCH_NAME%...
cd /d "%BASE_HAZINA%"
git worktree add "%AGENT_PATH%\hazina" -b %BRANCH_NAME% || (
    echo ERROR: Failed to create hazina worktree
    echo This might mean the branch already exists. Check: git branch -a ^| grep %BRANCH_NAME%
    REM Clean up client-manager worktree if hazina fails
    cd /d "%BASE_CLIENT_MANAGER%"
    git worktree remove "%AGENT_PATH%\client-manager" --force
    exit /b 1
)

echo Worktrees created successfully

REM === STEP 4: COPY CONFIG FILES ===
echo.
echo === STEP 4: Copying configuration files ===

REM Copy client-manager configs
if exist "%BASE_CLIENT_MANAGER%\appsettings.json" (
    copy "%BASE_CLIENT_MANAGER%\appsettings.json" "%AGENT_PATH%\client-manager\" >nul 2>&1
    echo Copied appsettings.json to client-manager worktree
)
if exist "%BASE_CLIENT_MANAGER%\.env" (
    copy "%BASE_CLIENT_MANAGER%\.env" "%AGENT_PATH%\client-manager\" >nul 2>&1
    echo Copied .env to client-manager worktree
)

REM Copy hazina configs (if any exist)
if exist "%BASE_HAZINA%\appsettings.json" (
    copy "%BASE_HAZINA%\appsettings.json" "%AGENT_PATH%\hazina\" >nul 2>&1
    echo Copied appsettings.json to hazina worktree
)

REM === STEP 5: MARK AGENT AS BUSY IN POOL ===
echo.
echo === STEP 5: Updating worktree pool ===

REM Get current timestamp in ISO 8601 format
for /f "tokens=1-6 delims=/:. " %%a in ('echo %date% %time%') do (
    set TIMESTAMP=%%c-%%a-%%bT%%d:%%e:%%fZ
)

REM Create temporary file with updated pool
set TEMP_POOL=%TEMP%\pool_temp_%RANDOM%.md
type nul > "%TEMP_POOL%"

REM Update the pool file - replace FREE with BUSY for our agent
for /f "usebackq delims=" %%a in ("%POOL_FILE%") do (
    set "LINE=%%a"
    echo !LINE! | findstr /c:"| %AGENT_SEAT% |" >nul
    if !errorlevel! equ 0 (
        echo !LINE! | findstr /c:"| FREE |" >nul
        if !errorlevel! equ 0 (
            REM This is our agent's line and it's FREE - update it to BUSY
            echo ^| %AGENT_SEAT% ^| %AGENT_SEAT:~0,7% ^| C:\Projects ^| %AGENT_PATH% ^| BUSY ^| client-manager+hazina ^| %BRANCH_NAME% ^| %TIMESTAMP% ^| %TASK_DESC% ^|>> "%TEMP_POOL%"
        ) else (
            REM Keep line as-is
            echo !LINE!>> "%TEMP_POOL%"
        )
    ) else (
        REM Keep line as-is
        echo !LINE!>> "%TEMP_POOL%"
    )
)

REM Replace pool file with updated version
move /y "%TEMP_POOL%" "%POOL_FILE%" >nul

echo Marked %AGENT_SEAT% as BUSY in pool

REM === STEP 6: LOG ALLOCATION IN ACTIVITY FILE ===
echo.
echo === STEP 6: Logging allocation ===

echo %TIMESTAMP% — allocate — %AGENT_SEAT% — client-manager+hazina — %BRANCH_NAME% — — claude-code — %TASK_DESC% >> "%ACTIVITY_FILE%"

echo Logged allocation to activity file

REM === SUCCESS ===
echo.
echo ========================================
echo WORKTREE CLAIMED SUCCESSFULLY
echo ========================================
echo Agent: %AGENT_SEAT%
echo Branch: %BRANCH_NAME%
echo Path: %AGENT_PATH%
echo Repos: client-manager + hazina
echo Status: BUSY
echo Task: %TASK_DESC%
echo.
echo NEXT STEPS:
echo 1. Work in: %AGENT_PATH%\client-manager and %AGENT_PATH%\hazina
echo 2. Make your changes
echo 3. When done, run: release-worktree.cmd %AGENT_SEAT% "PR title" "PR description"
echo.
echo WARNING: Remember to release the worktree when done!
echo ========================================

exit /b 0
