@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM NSFW Filter Disable Wrapper (STARK-Transformed 🦾)
REM Delegates all logic to the PowerShell core.
REM ============================================================================

set "BASE_DIR=%~dp0"
set "CORE_SCRIPT=%BASE_DIR%scripts\core.ps1"

if not exist "%CORE_SCRIPT%" (
    echo [!] ERROR: Core script missing at %CORE_SCRIPT%
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%CORE_SCRIPT%" %*

if errorlevel 1 (
    echo.
    echo [!] STARK: Execution encountered an error.
    if "%~1" neq "-s" if "%~1" neq "--silent" pause
    exit /b 1
)

exit /b 0
