@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM  Windrose Captain's Chest - one-click release
REM  Creates a git tag, pushes it, builds a clean distribution
REM  zip, and (if gh CLI is installed) publishes the release.
REM ============================================================

set "VERSION=v1.0.1"
set "REPO=1r0nch3f/Windrose-Captain-Chest"
set "DIST_ZIP=CaptainsChest-%VERSION%.zip"
set "DIST_DIR=_dist"

echo.
echo ============================================================
echo   Windrose Captain's Chest - release %VERSION%
echo ============================================================
echo   Repo:     %REPO%
echo   Tag:      %VERSION%
echo   Zip out:  %DIST_ZIP%
echo ============================================================
echo.

REM --- Check we're in the right folder --------------------------
if not exist "CaptainsChest.ps1" (
    echo [ERROR] CaptainsChest.ps1 not found in this folder.
    echo Run release.bat from the repo root.
    echo Current folder: %CD%
    echo.
    pause
    exit /b 1
)

REM --- Check git is installed -----------------------------------
where git >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Git is not installed or not on PATH.
    echo Install from https://git-scm.com/download/win
    echo.
    pause
    exit /b 1
)

REM --- Make sure we're in a git repo ----------------------------
if not exist ".git" (
    echo [ERROR] This folder is not a git repo yet.
    echo Run push.bat first to initialize and push the repo.
    echo.
    pause
    exit /b 1
)

REM --- Warn if there are uncommitted changes --------------------
echo [1/6] Checking for uncommitted changes...
git diff --quiet && git diff --cached --quiet
if errorlevel 1 (
    echo.
    echo [WARN] You have uncommitted changes in the working tree.
    echo        Commit or stash them first, or the release will not
    echo        reflect the current state of the files.
    echo.
    set /p CONTINUE="Continue anyway? (y/N): "
    if /i not "!CONTINUE!"=="y" (
        echo Aborted.
        pause
        exit /b 1
    )
) else (
    echo       Working tree clean.
)

REM --- Check the tag doesn't already exist ----------------------
echo.
echo [2/6] Checking tag %VERSION% doesn't already exist...
git rev-parse "%VERSION%" >nul 2>nul
if not errorlevel 1 (
    echo.
    echo [WARN] Tag %VERSION% already exists locally.
    set /p RETAG="Delete and recreate it? (y/N): "
    if /i "!RETAG!"=="y" (
        git tag -d %VERSION%
        git push origin :refs/tags/%VERSION% 2>nul
        echo       Old tag removed.
    ) else (
        echo Aborted.
        pause
        exit /b 1
    )
) else (
    echo       Tag is free.
)

REM --- Create the tag -------------------------------------------
echo.
echo [3/6] Creating annotated tag %VERSION%...
git tag -a %VERSION% -m "Release %VERSION%"
if errorlevel 1 goto fail

REM --- Push the tag ---------------------------------------------
echo.
echo [4/6] Pushing tag to GitHub...
git push origin %VERSION%
if errorlevel 1 goto fail

REM --- Build clean distribution zip -----------------------------
echo.
echo [5/6] Building distribution zip...

if exist "%DIST_DIR%" rmdir /s /q "%DIST_DIR%"
mkdir "%DIST_DIR%"

REM Always include README, LICENSE, CHANGELOG
copy /y "README.md"         "%DIST_DIR%\" >nul
copy /y "LICENSE"           "%DIST_DIR%\" >nul
copy /y "CHANGELOG.md"      "%DIST_DIR%\" >nul

REM Prefer the compiled exe if it exists (one-click for users).
REM Otherwise fall back to the .ps1 script.
if exist "CaptainsChest.exe" (
    echo       Including CaptainsChest.exe (compiled, one-click)
    copy /y "CaptainsChest.exe" "%DIST_DIR%\" >nul
    REM Also include the .ps1 so users can inspect the source if they want
    copy /y "CaptainsChest.ps1" "%DIST_DIR%\" >nul
) else (
    echo       No CaptainsChest.exe found - including .ps1 only.
    echo       Tip: run build-exe.bat first to compile a one-click exe.
    copy /y "CaptainsChest.ps1" "%DIST_DIR%\" >nul
)

if exist "%DIST_ZIP%" del /q "%DIST_ZIP%"

REM Use PowerShell to zip (built into every modern Windows)
powershell -NoProfile -Command "Compress-Archive -Path '%DIST_DIR%\*' -DestinationPath '%DIST_ZIP%' -Force"
if errorlevel 1 goto fail

rmdir /s /q "%DIST_DIR%"
echo       Created %DIST_ZIP%

REM --- Publish release via gh CLI if available ------------------
echo.
echo [6/6] Publishing GitHub release...
where gh >nul 2>nul
if errorlevel 1 (
    echo.
    echo       [INFO] GitHub CLI 'gh' not installed.
    echo              Tag pushed successfully, but you'll need to finish
    echo              the release manually on the web.
    echo.
    echo       Do this:
    echo         1. Open https://github.com/%REPO%/releases/new?tag=%VERSION%
    echo         2. Set title to: Windrose Captain's Chest %VERSION%
    echo         3. Copy the contents of RELEASE_NOTES.md into the description
    echo         4. Drag %DIST_ZIP% into the "Attach binaries" area
    echo         5. Click "Publish release"
    echo.
    echo       To automate this next time, install GitHub CLI:
    echo         https://cli.github.com/
    echo.
    goto done
)

echo       gh CLI detected. Publishing...

REM Check gh is authenticated
gh auth status >nul 2>nul
if errorlevel 1 (
    echo.
    echo       [WARN] gh CLI is installed but not authenticated.
    echo              Run: gh auth login
    echo              Then re-run this script.
    goto done
)

REM Create the release
if exist "RELEASE_NOTES.md" (
    gh release create %VERSION% "%DIST_ZIP%" --repo %REPO% --title "Windrose Captain's Chest %VERSION%" --notes-file RELEASE_NOTES.md
) else (
    gh release create %VERSION% "%DIST_ZIP%" --repo %REPO% --title "Windrose Captain's Chest %VERSION%" --generate-notes
)
if errorlevel 1 goto fail

echo.
echo       [OK] Release published.
echo       View it at: https://github.com/%REPO%/releases/tag/%VERSION%

:done
echo.
echo ============================================================
echo   DONE - %VERSION% tagged and pushed.
echo   Distribution zip: %DIST_ZIP%
echo ============================================================
echo.
pause
exit /b 0

:fail
echo.
echo ============================================================
echo   Something went wrong. Scroll up for the error.
echo ============================================================
echo.
echo Common fixes:
echo   - "tag already exists"     : say Y when prompted to recreate it
echo   - "Authentication failed"  : run 'git push' manually once to prime creds
echo   - "gh: command not found"  : install from https://cli.github.com/
echo                                or finish the release on the web (instructions
echo                                print above if gh is missing)
echo.
pause
exit /b 1
