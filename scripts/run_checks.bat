@echo off
REM ============================================================================
REM STARK Diagnostic Runner
REM Runs system checks.
REM ============================================================================

set "BASE_DIR=%~dp0..\"
set "CORE_SCRIPT=%~dp0core.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%CORE_SCRIPT%" -Check -Path "%BASE_DIR%"
pause
