@echo off
REM ============================================================================
REM STARK Bootstrap Script
REM Checks environment health before main execution.
REM ============================================================================

set "BASE_DIR=%~dp0..\"
set "CORE_SCRIPT=%~dp0core.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%CORE_SCRIPT%" -Setup -Path "%BASE_DIR%"
if errorlevel 1 (
    echo [!] Bootstrap Failed: Environment validation failed.
    echo [!] Check that this script is inside 'scripts/' and the 'resources/' folder exists nearby.
    pause
    exit /b 1
)

echo [STARK] Bootstrap Successful.
exit /b 0
