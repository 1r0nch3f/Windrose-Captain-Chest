@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM  Windrose Captain's Chest - build EXE via ps2exe
REM  Run this ONCE on your Windows machine to compile the
REM  PowerShell script into a self-elevating .exe
REM ============================================================

echo.
echo ============================================================
echo   Windrose Captain's Chest - EXE builder
echo ============================================================
echo.

REM --- Check source script exists -------------------------------
if not exist "CaptainsChest.ps1" (
    echo [ERROR] CaptainsChest.ps1 not found in this folder.
    echo Run build-exe.bat from the repo root.
    echo Current folder: %CD%
    echo.
    pause
    exit /b 1
)

REM --- Install ps2exe if needed ---------------------------------
echo [1/3] Checking for ps2exe module...
powershell -NoProfile -Command "if (-not (Get-Module -ListAvailable -Name ps2exe)) { Write-Host 'Installing ps2exe from PSGallery...'; Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber } else { Write-Host 'ps2exe already installed.' }"
if errorlevel 1 (
    echo.
    echo [ERROR] Failed to install ps2exe.
    echo You may need to run this as Administrator, or run:
    echo   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
    echo in PowerShell first.
    echo.
    pause
    exit /b 1
)

REM --- Build the exe --------------------------------------------
echo.
echo [2/3] Compiling CaptainsChest.ps1 to CaptainsChest.exe...
echo       (requesting admin privileges, console mode, with icon if present)
echo.

REM Delete old exe if present
if exist "CaptainsChest.exe" del /q "CaptainsChest.exe"

REM Build ps2exe command. Notable flags:
REM   -requireAdmin : embeds manifest so exe prompts UAC on launch
REM   -noConsole    : OFF (we want console - this is a diagnostic tool)
REM   -title / -company / etc : metadata shown in file properties
set "PS2EXE_CMD=Invoke-PS2EXE -inputFile 'CaptainsChest.ps1' -outputFile 'CaptainsChest.exe' -requireAdmin -title 'Windrose Captain''s Chest' -description 'Diagnostic toolkit for Windrose crews' -company '1r0nch3f' -product 'Windrose Captain''s Chest' -copyright '(c) 2026 1r0nch3f' -version '1.0.0.0'"

REM Add icon if the user dropped one in
if exist "chest.ico" (
    set "PS2EXE_CMD=!PS2EXE_CMD! -iconFile 'chest.ico'"
    echo       Using chest.ico for the icon.
) else (
    echo       No chest.ico found - using default icon. To customize,
    echo       drop a chest.ico file next to this script and re-run.
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "!PS2EXE_CMD!"
if errorlevel 1 goto fail

if not exist "CaptainsChest.exe" (
    echo.
    echo [ERROR] Build reported success but CaptainsChest.exe was not created.
    goto fail
)

REM --- Verify ---------------------------------------------------
echo.
echo [3/3] Verifying the exe...
for %%F in ("CaptainsChest.exe") do set "EXE_SIZE=%%~zF"
echo       Created CaptainsChest.exe (!EXE_SIZE! bytes)

echo.
echo ============================================================
echo   SUCCESS - CaptainsChest.exe is ready.
echo ============================================================
echo.
echo HEADS UP about antivirus:
echo.
echo   Windows Defender and other AV products sometimes flag
echo   ps2exe-compiled binaries as false positives because
echo   malware authors use the same tool. Your crew may see:
echo.
echo     - SmartScreen warning on first download
echo     - Defender flagging it as "Trojan:Win32/Wacatac" or similar
echo     - Some AVs silently deleting the file
echo.
echo   Recommended: include a note in your release that users may
echo   need to click "More info" then "Run anyway" on SmartScreen,
echo   or add an AV exception. The source .ps1 is always in the
echo   repo so they can inspect it before trusting the exe.
echo.
pause
exit /b 0

:fail
echo.
echo ============================================================
echo   Build failed. Scroll up for the error.
echo ============================================================
echo.
pause
exit /b 1
