@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM  Windrose Captain's Chest - one-click GitHub push
REM  Double-click this in the folder with CaptainsChest.ps1
REM ============================================================

set "REPO_URL=https://github.com/1r0nch3f/Windrose-Captain-Chest.git"
set "BRANCH=main"
set "COMMIT_MSG=Initial commit: Captain's Chest diagnostic toolkit"

echo.
echo ============================================================
echo   Windrose Captain's Chest - GitHub push
echo ============================================================
echo   Repo:    %REPO_URL%
echo   Branch:  %BRANCH%
echo   Folder:  %CD%
echo ============================================================
echo.

REM --- Check git is installed -----------------------------------
where git >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Git is not installed or not on PATH.
    echo.
    echo Install it from: https://git-scm.com/download/win
    echo After install, close this window and run the .bat again.
    echo.
    pause
    exit /b 1
)

REM --- Verify expected files exist ------------------------------
if not exist "CaptainsChest.ps1" (
    echo [ERROR] CaptainsChest.ps1 not found in this folder.
    echo Make sure push.bat is sitting next to the script files.
    echo Current folder: %CD%
    echo.
    pause
    exit /b 1
)

REM --- Initialize repo if needed --------------------------------
if not exist ".git" (
    echo [1/6] Initializing new git repo...
    git init -b %BRANCH%
    if errorlevel 1 goto fail
) else (
    echo [1/6] Git repo already initialized, skipping init.
)

REM --- Set identity if missing (local scope only) ---------------
for /f "tokens=*" %%a in ('git config user.name 2^>nul') do set "GIT_USER=%%a"
for /f "tokens=*" %%a in ('git config user.email 2^>nul') do set "GIT_EMAIL=%%a"

if "!GIT_USER!"=="" (
    echo.
    echo [2/6] No git user.name set. Setting to "1r0nch3f" for this repo.
    git config user.name "1r0nch3f"
) else (
    echo [2/6] Git user.name: !GIT_USER!
)

if "!GIT_EMAIL!"=="" (
    echo.
    set /p GIT_EMAIL_INPUT="Enter the email on your GitHub account: "
    git config user.email "!GIT_EMAIL_INPUT!"
) else (
    echo       Git user.email: !GIT_EMAIL!
)

REM --- Stage all files ------------------------------------------
echo.
echo [3/6] Staging files...
git add .
if errorlevel 1 goto fail

REM --- Commit ---------------------------------------------------
echo.
echo [4/6] Committing...
git diff --cached --quiet
if errorlevel 1 (
    git commit -m "%COMMIT_MSG%"
    if errorlevel 1 goto fail
) else (
    echo       Nothing to commit, working tree clean.
)

REM --- Configure remote -----------------------------------------
echo.
echo [5/6] Configuring remote 'origin'...
git remote get-url origin >nul 2>nul
if errorlevel 1 (
    git remote add origin %REPO_URL%
) else (
    git remote set-url origin %REPO_URL%
)

REM --- Push -----------------------------------------------------
echo.
echo [6/6] Pushing to GitHub...
echo       If this is your first push, Git may pop a browser window
echo       asking you to log in to GitHub. That's normal.
echo.
git push -u origin %BRANCH%
if errorlevel 1 goto fail

echo.
echo ============================================================
echo   SUCCESS - chest is aboard GitHub.
echo   View it at: https://github.com/1r0nch3f/Windrose-Captain-Chest
echo ============================================================
echo.
pause
exit /b 0

:fail
echo.
echo ============================================================
echo   Something went wrong. Scroll up for the error message.
echo ============================================================
echo.
echo Common fixes:
echo   - "Authentication failed"      : run 'git config --global credential.helper manager'
echo                                    then try again, login prompt should appear.
echo   - "Repository not found"       : make sure you created the empty repo on GitHub first,
echo                                    at https://github.com/new
echo   - "fatal: remote origin exists": already fine, just re-run this .bat.
echo.
pause
exit /b 1
