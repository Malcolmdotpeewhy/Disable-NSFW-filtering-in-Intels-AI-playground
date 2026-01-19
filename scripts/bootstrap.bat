@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM AI Playground Environment Bootstrap (Evolver 🧬)
REM Validates prerequisites and prepares the environment.
REM ============================================================================

set "BASE_DIR=%~dp0..\"
if "!BASE_DIR:~-2!"=="\\" set "BASE_DIR=!BASE_DIR:~0,-1!"

echo [Evolver] Bootstrapping AI Playground environment...

set "REQ_DIRS=resources\ComfyUI\models resources\ComfyUI\custom_nodes"
set "FAILED=0"

for %%d in (%REQ_DIRS%) do (
    if not exist "%BASE_DIR%\%%d" (
        echo [!] MISSING DIRECTORY: %%d
        set "FAILED=1"
    ) else (
        echo [✓] Found: %%d
    )
)

if "%FAILED%"=="1" (
    echo [!] Bootstrap failed. Please ensure you are running this from the AI Playground root.
    exit /b 1
)

echo [✓] Environment validated successfully.
exit /b 0
