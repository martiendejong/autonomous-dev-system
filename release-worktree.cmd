@echo off
REM release-worktree.cmd - Commit, push, create PR, and release agent worktree
REM Usage: release-worktree.cmd <agent-seat> <pr-title> [pr-description]
REM Example: release-worktree.cmd agent-001 "feat: Add new feature" "Implements feature X with Y and Z"
REM
REM This script:
REM 1. Commits all changes in both client-manager and hazina worktrees
REM 2. Pushes branches to origin
REM 3. Creates PRs for both repos (if changes exist)
REM 4. Removes the worktrees
REM 5. Marks the agent as FREE in the pool
REM 6. Logs the release in worktrees.activity.md
REM
REM WARNING: This will commit ALL changes in the worktree.
REM          Review your changes with git status before running this script.

setlocal enabledelayedexpansion

REM === PARAMETER VALIDATION ===
if "%~1"=="" (
    echo ERROR: Agent seat is required
    echo Usage: release-worktree.cmd ^<agent-seat^> ^<pr-title^> [pr-description]
    echo Example: release-worktree.cmd agent-001 "feat: Add new feature" "Implements feature X"
    exit /b 1
)

if "%~2"=="" (
    echo ERROR: PR title is required
    echo Usage: release-worktree.cmd ^<agent-seat^> ^<pr-title^> [pr-description]
    exit /b 1
)

set AGENT_SEAT=%~1
set PR_TITLE=%~2
set PR_DESC=%~3
if "%PR_DESC%"=="" set PR_DESC=%PR_TITLE%

REM === PATHS ===
set POOL_FILE=C:\scripts\_machine\worktrees.pool.md
set ACTIVITY_FILE=C:\scripts\_machine\worktrees.activity.md
set BASE_CLIENT_MANAGER=C:\Projects\client-manager
set BASE_HAZINA=C:\Projects\hazina
set WORKTREE_ROOT=C:\Projects\worker-agents
set AGENT_PATH=%WORKTREE_ROOT%\%AGENT_SEAT%

REM === VERIFY AGENT EXISTS ===
if not exist "%AGENT_PATH%" (
    echo ERROR: Agent path not found: %AGENT_PATH%
    echo Check that %AGENT_SEAT% is a valid agent seat
    exit /b 1
)

REM === VERIFY POOL FILE ===
if not exist "%POOL_FILE%" (
    echo ERROR: Pool file not found: %POOL_FILE%
    exit /b 1
)

REM === GET BRANCH NAME FROM POOL ===
echo.
echo === Getting branch name from pool ===
set BRANCH_NAME=
REM Pool columns: 1=Seat, 2=Agent start branch, 3=Base repo, 4=Worktree root, 5=Status, 6=Current repo, 7=Branch
for /f "tokens=7 delims=|" %%a in ('findstr /c:"| %AGENT_SEAT% |" "%POOL_FILE%"') do (
    set "BRANCH_NAME=%%a"
    set "BRANCH_NAME=!BRANCH_NAME: =!"
)

if "%BRANCH_NAME%"=="" (
    echo ERROR: Could not determine branch name for %AGENT_SEAT%
    echo The agent may not be allocated in the pool
    exit /b 1
)

if "%BRANCH_NAME%"=="-" (
    echo ERROR: Agent %AGENT_SEAT% is not currently allocated (branch is -)
    exit /b 1
)

echo Branch: %BRANCH_NAME%

REM === STEP 1: COMMIT CHANGES IN CLIENT-MANAGER ===
echo.
echo === STEP 1: Committing changes in client-manager ===

set CLIENT_MANAGER_PATH=%AGENT_PATH%\client-manager
if not exist "%CLIENT_MANAGER_PATH%" (
    echo WARNING: client-manager worktree not found, skipping
    set HAS_CLIENT_MANAGER=0
) else (
    set HAS_CLIENT_MANAGER=1
    cd /d "%CLIENT_MANAGER_PATH%"

    REM Check for changes
    git status --short >nul 2>&1
    for /f %%i in ('git status --short ^| find /c /v ""') do set CHANGES=%%i

    if !CHANGES! gtr 0 (
        echo Found !CHANGES! changed files in client-manager
        echo Staging all changes...
        git add -A || (
            echo ERROR: Failed to stage changes in client-manager
            exit /b 1
        )

        echo Committing changes...
        git commit -m "%PR_TITLE%" -m "%PR_DESC%" -m "" -m "Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>" || (
            echo ERROR: Failed to commit changes in client-manager
            exit /b 1
        )

        echo Committed successfully
        set CLIENT_MANAGER_HAS_COMMIT=1
    ) else (
        echo No changes to commit in client-manager
        set CLIENT_MANAGER_HAS_COMMIT=0
    )
)

REM === STEP 2: COMMIT CHANGES IN HAZINA ===
echo.
echo === STEP 2: Committing changes in hazina ===

set HAZINA_PATH=%AGENT_PATH%\hazina
if not exist "%HAZINA_PATH%" (
    echo WARNING: hazina worktree not found, skipping
    set HAS_HAZINA=0
) else (
    set HAS_HAZINA=1
    cd /d "%HAZINA_PATH%"

    REM Check for changes
    git status --short >nul 2>&1
    for /f %%i in ('git status --short ^| find /c /v ""') do set CHANGES=%%i

    if !CHANGES! gtr 0 (
        echo Found !CHANGES! changed files in hazina
        echo Staging all changes...
        git add -A || (
            echo ERROR: Failed to stage changes in hazina
            exit /b 1
        )

        echo Committing changes...
        git commit -m "%PR_TITLE%" -m "%PR_DESC%" -m "" -m "Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>" || (
            echo ERROR: Failed to commit changes in hazina
            exit /b 1
        )

        echo Committed successfully
        set HAZINA_HAS_COMMIT=1
    ) else (
        echo No changes to commit in hazina
        set HAZINA_HAS_COMMIT=0
    )
)

REM === STEP 3: PUSH TO ORIGIN ===
echo.
echo === STEP 3: Pushing to origin ===

if %HAS_CLIENT_MANAGER%==1 (
    if %CLIENT_MANAGER_HAS_COMMIT%==1 (
        echo Pushing client-manager...
        cd /d "%CLIENT_MANAGER_PATH%"
        git push -u origin %BRANCH_NAME% || (
            echo ERROR: Failed to push client-manager
            exit /b 1
        )
        echo Pushed client-manager successfully
    )
)

if %HAS_HAZINA%==1 (
    if %HAZINA_HAS_COMMIT%==1 (
        echo Pushing hazina...
        cd /d "%HAZINA_PATH%"
        git push -u origin %BRANCH_NAME% || (
            echo ERROR: Failed to push hazina
            exit /b 1
        )
        echo Pushed hazina successfully
    )
)

REM === STEP 4: CREATE PULL REQUESTS ===
echo.
echo === STEP 4: Creating pull requests ===

set CLIENT_MANAGER_PR=
set HAZINA_PR=

if %HAS_CLIENT_MANAGER%==1 (
    if %CLIENT_MANAGER_HAS_COMMIT%==1 (
        echo Creating client-manager PR...
        cd /d "%CLIENT_MANAGER_PATH%"

        REM Create PR body
        set "PR_BODY=%PR_DESC%"

        REM Check if there's a Hazina PR dependency
        if %HAZINA_HAS_COMMIT%==1 (
            set "PR_BODY=## ⚠️ DEPENDENCY ALERT ⚠️\n\nThis PR depends on the corresponding Hazina PR.\n**Merge order:** Merge Hazina PR first, then this PR.\n\n---\n\n%PR_DESC%"
        )

        REM Create PR
        for /f "delims=" %%i in ('gh pr create --base develop --title "%PR_TITLE%" --body "!PR_BODY!" 2^>^&1') do set PR_OUTPUT=%%i
        echo !PR_OUTPUT! | findstr /c:"https://github.com" >nul
        if !errorlevel! equ 0 (
            for /f "tokens=*" %%a in ("!PR_OUTPUT!") do set CLIENT_MANAGER_PR=%%a
            echo Created client-manager PR: !CLIENT_MANAGER_PR!
        ) else (
            echo WARNING: Could not create client-manager PR
            echo Output: !PR_OUTPUT!
        )
    )
)

if %HAS_HAZINA%==1 (
    if %HAZINA_HAS_COMMIT%==1 (
        echo Creating hazina PR...
        cd /d "%HAZINA_PATH%"

        REM Create PR body
        set "PR_BODY=%PR_DESC%"

        REM Check if there's a client-manager dependency
        if %CLIENT_MANAGER_HAS_COMMIT%==1 (
            set "PR_BODY=## ⚠️ DOWNSTREAM DEPENDENCIES ⚠️\n\nThe client-manager PR depends on this.\n**Merge this PR first** before the dependent client-manager PR.\n\n---\n\n%PR_DESC%"
        )

        REM Create PR
        for /f "delims=" %%i in ('gh pr create --base develop --title "%PR_TITLE%" --body "!PR_BODY!" 2^>^&1') do set PR_OUTPUT=%%i
        echo !PR_OUTPUT! | findstr /c:"https://github.com" >nul
        if !errorlevel! equ 0 (
            for /f "tokens=*" %%a in ("!PR_OUTPUT!") do set HAZINA_PR=%%a
            echo Created hazina PR: !HAZINA_PR!
        ) else (
            echo WARNING: Could not create hazina PR
            echo Output: !PR_OUTPUT!
        )
    )
)

REM === STEP 5: CLEAN UP WORKTREES ===
echo.
echo === STEP 5: Cleaning up worktrees ===

if %HAS_CLIENT_MANAGER%==1 (
    echo Removing client-manager worktree...
    cd /d "%BASE_CLIENT_MANAGER%"
    git worktree remove "%CLIENT_MANAGER_PATH%" --force || (
        echo WARNING: Could not remove client-manager worktree
    )
)

if %HAS_HAZINA%==1 (
    echo Removing hazina worktree...
    cd /d "%BASE_HAZINA%"
    git worktree remove "%HAZINA_PATH%" --force || (
        echo WARNING: Could not remove hazina worktree
    )
)

REM Delete agent directory
if exist "%AGENT_PATH%" (
    echo Deleting agent directory...
    rd /s /q "%AGENT_PATH%" 2>nul
)

echo Worktrees cleaned up

REM === STEP 6: MARK AGENT AS FREE IN POOL ===
echo.
echo === STEP 6: Updating worktree pool ===

REM Get current timestamp
for /f "tokens=1-6 delims=/:. " %%a in ('echo %date% %time%') do (
    set TIMESTAMP=%%c-%%a-%%bT%%d:%%e:%%fZ
)

REM Create summary note
set "RELEASE_NOTE=✅ Completed: %PR_TITLE%"
if defined CLIENT_MANAGER_PR set "RELEASE_NOTE=!RELEASE_NOTE! (client-manager PR)"
if defined HAZINA_PR set "RELEASE_NOTE=!RELEASE_NOTE! (hazina PR)"

REM Create temporary file with updated pool
set TEMP_POOL=%TEMP%\pool_temp_%RANDOM%.md
type nul > "%TEMP_POOL%"

REM Update the pool file - replace BUSY with FREE for our agent
for /f "usebackq delims=" %%a in ("%POOL_FILE%") do (
    set "LINE=%%a"
    echo !LINE! | findstr /c:"| %AGENT_SEAT% |" >nul
    if !errorlevel! equ 0 (
        echo !LINE! | findstr /c:"| BUSY |" >nul
        if !errorlevel! equ 0 (
            REM This is our agent's line and it's BUSY - update it to FREE
            echo ^| %AGENT_SEAT% ^| %AGENT_SEAT:~0,7% ^| C:\Projects ^| %WORKTREE_ROOT%\%AGENT_SEAT% ^| FREE ^| - ^| - ^| %TIMESTAMP% ^| !RELEASE_NOTE! ^|>> "%TEMP_POOL%"
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

echo Marked %AGENT_SEAT% as FREE in pool

REM === STEP 7: LOG RELEASE IN ACTIVITY FILE ===
echo.
echo === STEP 7: Logging release ===

set "ACTIVITY_NOTE=%PR_TITLE%"
if defined CLIENT_MANAGER_PR set "ACTIVITY_NOTE=!ACTIVITY_NOTE!, client-manager PR created"
if defined HAZINA_PR set "ACTIVITY_NOTE=!ACTIVITY_NOTE!, hazina PR created"

echo %TIMESTAMP% — release — %AGENT_SEAT% — client-manager+hazina — %BRANCH_NAME% — — claude-code — !ACTIVITY_NOTE! >> "%ACTIVITY_FILE%"

echo Logged release to activity file

REM === SUCCESS ===
echo.
echo ========================================
echo WORKTREE RELEASED SUCCESSFULLY
echo ========================================
echo Agent: %AGENT_SEAT% (now FREE)
echo Branch: %BRANCH_NAME%
echo.
if defined CLIENT_MANAGER_PR (
    echo client-manager PR: !CLIENT_MANAGER_PR!
)
if defined HAZINA_PR (
    echo hazina PR: !HAZINA_PR!
)
echo.
echo The agent is now available for new work.
echo ========================================

exit /b 0
