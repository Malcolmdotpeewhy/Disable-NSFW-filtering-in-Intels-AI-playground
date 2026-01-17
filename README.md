<img width="644" height="534" alt="image" src="https://github.com/user-attachments/assets/8b4310a3-1351-4eda-b04c-7eb1d93301a1" />


{
@echo off
REM ============================================================================
REM NSFW Filter Disable Script for ComfyUI-ReActor in AI Playground
REM ============================================================================
REM
REM EASY TO USE:
REM   1. Download this file to: AI Playground\
REM   2. Double-click to run
REM   3. Follow the prompts
REM   4. Restart AI Playground
REM
REM WHAT IT DOES:
REM   - Disables NSFW content filtering in ComfyUI-ReActor
REM   - Creates automatic backups before modifying files
REM   - Sets up environment variable for persistence
REM   - Shows clear status messages at each step
REM
REM ============================================================================

setlocal enabledelayedexpansion

REM Log file for troubleshooting
set "LOG_FILE=%~dp0nsfw_disable_log.txt"

REM Clear previous log
if exist "%LOG_FILE%" del "%LOG_FILE%"

echo. >> "%LOG_FILE%"
echo ============================================================================ >> "%LOG_FILE%"
echo NSFW Filter Disable - Execution Log >> "%LOG_FILE%"
echo Date: %date% %time% >> "%LOG_FILE%"
echo ============================================================================ >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

REM Welcome banner
cls
echo.
echo ============================================================================
echo.
echo   NSFW FILTER DISABLER for AI Playground
echo   ComfyUI-ReActor
echo.
echo ============================================================================
echo.
echo This script will disable NSFW content filtering.
echo.
echo What happens:
echo   ✓ Backups created automatically
echo   ✓ 3 configuration files modified
echo   ✓ Environment variable set permanently
echo   ✓ Takes about 30 seconds
@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

REM Optimized NSFW Filter Disabler for AI Playground (single-file, idempotent)
REM Usage: place this file in the AI Playground root and run it (double-click or from PowerShell/CMD)
REM Options: -h or --help for usage

set "BASE_DIR=%~dp0"
set "LOG_FILE=%BASE_DIR%nsfw_disable_log.txt"

if "%1"=="-h" goto :help
if "%1"=="--help" goto :help

echo ============================================================================
echo NSFW Filter Disabler - AI Playground
echo ============================================================================
echo Location: %BASE_DIR%
echo Log: %LOG_FILE%
echo.

rem Paths (relative to script location)
set "NSFW_CONFIG=%BASE_DIR%resources\ComfyUI\models\nsfw_detector\vit-base-nsfw-detector\config.json"
set "NSFW_PREPROCESSOR=%BASE_DIR%resources\ComfyUI\models\nsfw_detector\vit-base-nsfw-detector\preprocessor_config.json"
set "REACTOR_SFW=%BASE_DIR%resources\ComfyUI\custom_nodes\comfyui-reactor\scripts\reactor_sfw.py"

rem Basic validation
if not exist "%NSFW_CONFIG%" (
  echo ERROR: Missing file: %NSFW_CONFIG%
  echo Make sure this script is in the AI Playground root and ComfyUI is installed under resources\ComfyUI
  pause
  exit /b 1
)
if not exist "%NSFW_PREPROCESSOR%" (
  echo ERROR: Missing file: %NSFW_PREPROCESSOR%
  pause
  exit /b 1
)
if not exist "%REACTOR_SFW%" (
  echo ERROR: Missing file: %REACTOR_SFW%
  pause
  exit /b 1
)

rem Idempotency check: look for marker in python file or NSFW_DISABLED_MARKER in JSON
findstr /M /C:"NSFW_DISABLED_MARKER" "%REACTOR_SFW%" >nul 2>&1
if !errorlevel! equ 0 (
  echo NSFW filter appears already disabled (marker found in reactor_sfw.py). Nothing to do.
  pause
  exit /b 0
)

rem Create backup folder with timestamp
for /f "tokens=1-5 delims=/:, " %%a in ("%date% %time%") do (
  set "DT=%%e%%b%%c_%%d%%e"
)
set "BACKUP_DIR=%BASE_DIR%backups\nsfw_disable_%random%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "BACKUP_DIR=%BACKUP_DIR: =0%"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
echo Backing up original files to: %BACKUP_DIR%

copy "%NSFW_CONFIG%" "%BACKUP_DIR%\config.json.bak" >nul
copy "%NSFW_PREPROCESSOR%" "%BACKUP_DIR%\preprocessor_config.json.bak" >nul
copy "%REACTOR_SFW%" "%BACKUP_DIR%\reactor_sfw.py.bak" >nul

rem Update config and preprocessor JSONs using PowerShell (adds marker and bypass keys)
echo Updating JSON configuration files...
powershell -NoProfile -ExecutionPolicy Bypass -Command "^
  $paths = @('%NSFW_CONFIG%','%NSFW_PREPROCESSOR%'); ^
  foreach($p in $paths) { ^
    try { ^
      $j = Get-Content $p | ConvertFrom-Json; ^
      $j.nsfw_bypass = $true; ^
      $j.nsfw_disabled = $true; ^
      $j.bypass_safety_check = $true; ^
      $j.safety_check_threshold = 9999.0; ^
      $j.NSFW_DISABLED_MARKER = 'Modified by disable_nsfw_filter.bat'; ^
      $j | ConvertTo-Json -Depth 20 | Set-Content $p; ^
      Write-Host "Updated: $p"; ^
    } catch { Write-Host "Failed: $p -> $_"; exit 1 } ^
  } ^
"  > "%LOG_FILE%" 2>&1

if errorlevel 1 (
  echo ERROR: JSON updates failed. See %LOG_FILE%
  pause
  exit /b 1
)

rem Replace reactor_sfw.py with a safe, idempotent implementation
echo Writing patched reactor_sfw.py...
powershell -NoProfile -ExecutionPolicy Bypass -Command "^
  $out = @'
# NSFW_DISABLED_MARKER - Modified by disable_nsfw_filter.bat
import os
import logging
from PIL import Image
from scripts.reactor_logger import logger

SCORE = 0.965
NSFW_DISABLED = os.environ.get('REACTOR_NSFW_DISABLED','false').lower() == 'true'
logging.getLogger('transformers').setLevel(logging.ERROR)

def nsfw_image(img_path: str, model_path: str):
    """Return True if image is NSFW, False otherwise. If detection fails, returns False (allow).
    This function respects the environment variable REACTOR_NSFW_DISABLED to force allow all content.
    """
    if NSFW_DISABLED:
        logger.status('NSFW detection disabled via REACTOR_NSFW_DISABLED')
        return False
    try:
        with Image.open(img_path) as img:
            from transformers import pipeline
            predict = pipeline('image-classification', model=model_path)
            result = predict(img)
            logger.status(result)
            for item in result:
                if item.get('label') == 'nsfw':
                    return True if item.get('score',0.0) > SCORE else False
            return False
    except Exception as e:
        logger.warning(f'NSFW detection error: {e} - allowing content')
        return False
'@
  $out | Set-Content -Path '%REACTOR_SFW%' -Encoding utf8; ^
  Write-Host 'Replaced reactor_sfw.py'; ^
" >> "%LOG_FILE%" 2>&1

if errorlevel 1 (
  echo ERROR: Failed to write reactor_sfw.py (check permissions)
  echo Restoring backups...
  copy "%BACKUP_DIR%\reactor_sfw.py.bak" "%REACTOR_SFW%" >nul
  pause
  exit /b 1
)

rem Persist environment variable for current user
echo Setting persistent environment variable REACTOR_NSFW_DISABLED=true
powershell -NoProfile -ExecutionPolicy Bypass -Command "[System.Environment]::SetEnvironmentVariable('REACTOR_NSFW_DISABLED','true','User')" >> "%LOG_FILE%" 2>&1
setx REACTOR_NSFW_DISABLED true >nul 2>&1

echo.
echo ============================================================================
echo ✓ SUCCESS: NSFW filter disabled (idempotent patch applied)
echo Modified files:
echo   - %NSFW_CONFIG%
echo   - %NSFW_PREPROCESSOR%
echo   - %REACTOR_SFW%
echo Backups saved to: %BACKUP_DIR%
echo Environment variable: REACTOR_NSFW_DISABLED = true
echo IMPORTANT: Restart AI Playground for changes to take effect
echo ============================================================================

pause
exit /b 0

:help
echo Usage: disable_nsfw_filter.bat
echo Place the batch file in the AI Playground root and run it.
echo Options:
echo   -h, --help    Show this help message
pause
exit /b 0
    $config | Add-Member -NotePropertyName 'bypass_safety_check' -NotePropertyValue $true -Force; ^}
