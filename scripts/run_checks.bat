@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM NSFW Patch Status Check (Evolver 🧬)
REM Verifies if the NSFW filter disabler patch is active.
REM ============================================================================

set "BASE_DIR=%~dp0..\"
if "!BASE_DIR:~-2!"=="\\" set "BASE_DIR=!BASE_DIR:~0,-1!"

set "REACTOR_SFW=%BASE_DIR%\resources\ComfyUI\custom_nodes\comfyui-reactor\scripts\reactor_sfw.py"

echo [Evolver] Checking patch status...

if not exist "%REACTOR_SFW%" (
    echo [!] ReActor script not found at: %REACTOR_SFW%
    exit /b 1
)

findstr /C:"Bolt-Optimized" "%REACTOR_SFW%" >nul 2>&1
if errorlevel 1 (
    echo [ ] Patch status: INACTIVE
    exit /b 1
) else (
    echo [✓] Patch status: ACTIVE (Bolt-Optimized)
)

echo [Evolver] Checking environment variable...
powershell -Command "if ([System.Environment]::GetEnvironmentVariable('REACTOR_NSFW_DISABLED', 'User') -eq 'true') { Write-Host '[✓] Environment variable: ACTIVE' } else { Write-Host '[ ] Environment variable: INACTIVE'; exit 1 }"

if errorlevel 1 exit /b 1

echo.
echo [✓] SUCCESS: All NSFW disable components are active.
exit /b 0
