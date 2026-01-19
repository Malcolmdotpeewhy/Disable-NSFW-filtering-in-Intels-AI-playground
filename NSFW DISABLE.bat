@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM NSFW Filter Disable Script for ComfyUI-ReActor in AI Playground
REM Optimized by Evolver 🧬 (Bolt-Enhanced)
REM ============================================================================

set "BASE_DIR=%~dp0"
set "LOG_FILE=%BASE_DIR%nsfw_disable_log.txt"

(
  echo ============================================================================
  echo NSFW Filter Disable - Execution Log
  echo Date: %date% %time%
  echo ============================================================================
) > "%LOG_FILE%"

set "SILENT=0"
set "CUSTOM_PATH="

:args_loop
if "%~1"=="" goto :args_done
if "%~1"=="-s" set "SILENT=1" & shift & goto :args_loop
if "%~1"=="--silent" set "SILENT=1" & shift & goto :args_loop
if "%~1"=="-p" set "CUSTOM_PATH=%~2" & shift & shift & goto :args_loop
if "%~1"=="--path" set "CUSTOM_PATH=%~2" & shift & shift & goto :args_loop
if "%~1"=="-h" goto :help
if "%~1"=="--help" goto :help
shift
goto :args_loop
:args_done

if defined CUSTOM_PATH (
    set "BASE_DIR=%CUSTOM_PATH%\"
    if "!BASE_DIR:~-2!"=="\\" set "BASE_DIR=!BASE_DIR:~0,-1!"
)

set "NSFW_CONFIG=%BASE_DIR%resources\ComfyUI\models\nsfw_detector\vit-base-nsfw-detector\config.json"
set "NSFW_PREPROCESSOR=%BASE_DIR%resources\ComfyUI\models\nsfw_detector\vit-base-nsfw-detector\preprocessor_config.json"
set "REACTOR_SFW=%BASE_DIR%resources\ComfyUI\custom_nodes\comfyui-reactor\scripts\reactor_sfw.py"

if not exist "%NSFW_CONFIG%" set "MISSING=1"
if not exist "%NSFW_PREPROCESSOR%" set "MISSING=1"
if not exist "%REACTOR_SFW%" set "MISSING=1"

if defined MISSING (
  echo ERROR: Required files not found in: %BASE_DIR%
  if "%SILENT%"=="0" pause
  exit /b 1
)

copy /y nul "%BASE_DIR%perm_test.tmp" >nul 2>&1
if errorlevel 1 (
  echo ERROR: No write permission in %BASE_DIR%
  if "%SILENT%"=="0" pause
  exit /b 1
)
del "%BASE_DIR%perm_test.tmp" >nul 2>&1

set "BACKUP_DIR=%BASE_DIR%backups\nsfw_disable_%time:~0,2%%time:~3,2%%time:~6,2%"
set "BACKUP_DIR=%BACKUP_DIR: =0%"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%" 2>nul

copy "%NSFW_CONFIG%" "%BACKUP_DIR%\config.json.bak" >nul
copy "%NSFW_PREPROCESSOR%" "%BACKUP_DIR%\preprocessor_config.json.bak" >nul
copy "%REACTOR_SFW%" "%BACKUP_DIR%\reactor_sfw.py.bak" >nul

REM --- Define Core Patching Logic ---
set "PATCH_LOGIC=try { "
set "PATCH_LOGIC=!PATCH_LOGIC! if (Select-String -Path '%REACTOR_SFW%' -Pattern 'Bolt-Optimized') { if ($l) { $l.Text = 'Already patched.'; Start-Sleep -s 1 } exit 0; } "
set "PATCH_LOGIC=!PATCH_LOGIC! $paths = @('%NSFW_CONFIG%','%NSFW_PREPROCESSOR%'); "
set "PATCH_LOGIC=!PATCH_LOGIC! foreach($p in $paths) { if ($l) { $l.Text = \"Patching $(Split-Path $p -Leaf)...\"; $f.Refresh() } $j = Get-Content -Raw $p | ConvertFrom-Json; $j.nsfw_bypass = $true; $j.nsfw_disabled = $true; $j.bypass_safety_check = $true; $j.safety_check_threshold = 9999.0; $j.NSFW_DISABLED_MARKER = 'Bolt-Optimized'; $j | ConvertTo-Json -Depth 20 | Set-Content $p; } "
set "PATCH_LOGIC=!PATCH_LOGIC! if ($l) { $l.Text = 'Injecting optimized Python code...'; $f.Refresh() } "
set "PATCH_LOGIC=!PATCH_LOGIC! $py = '# NSFW_DISABLED_MARKER - Modified by Bolt ' + [char]9889 + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += 'import os' + [char]10 + 'from scripts.reactor_logger import logger' + [char]10 + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += 'NSFW_DISABLED = os.environ.get(\"REACTOR_NSFW_DISABLED\", \"false\").lower() == \"true\"' + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += 'if NSFW_DISABLED: logger.status(\"ReActor: NSFW filter is disabled\")' + [char]10 + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += '_pipeline_cache = {}' + [char]10 + 'SCORE = 0.965' + [char]10 + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += 'def nsfw_image(img_path: str, model_path: str):' + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += '    if NSFW_DISABLED: return False' + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += '    try:' + [char]10 + '        global _pipeline_cache' + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += '        if model_path not in _pipeline_cache:' + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += '            from transformers import pipeline' + [char]10 + '            import logging' + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += '            logging.getLogger(\"transformers\").setLevel(logging.ERROR)' + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += '            _pipeline_cache[model_path] = pipeline(\"image-classification\", model=model_path)' + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += '        from PIL import Image' + [char]10 + '        with Image.open(img_path) as img:' + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += '            result = _pipeline_cache[model_path](img)' + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += '            for item in result:' + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += '                if item.get(\"label\") == \"nsfw\": return item.get(\"score\", 0.0) > SCORE' + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += '            return False' + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += '    except Exception as e:' + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += '        logger.warning(f\"NSFW detection error: {e} - allowing content\")' + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py += '        return False' + [char]10; "
set "PATCH_LOGIC=!PATCH_LOGIC! $py | Set-Content -Path '%REACTOR_SFW%' -Encoding utf8; "
set "PATCH_LOGIC=!PATCH_LOGIC! [System.Environment]::SetEnvironmentVariable('REACTOR_NSFW_DISABLED', 'true', 'User'); "
set "PATCH_LOGIC=!PATCH_LOGIC! if ($l) { $l.Text = 'Success'; $f.Refresh(); Start-Sleep -s 1 } "
set "PATCH_LOGIC=!PATCH_LOGIC! } catch { if ($f) { [Windows.Forms.MessageBox]::Show('Error: ' + $_.Exception.Message) } else { throw $_.Exception.Message } exit 1; } "

if "%SILENT%"=="1" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; $l=$null; $f=$null; %PATCH_LOGIC%" >> "%LOG_FILE%" 2>&1
) else (
    set "GUI_CMD=Add-Type -AssemblyName System.Windows.Forms; $f = New-Object Windows.Forms.Form; $f.Text = 'NSFW Disabler'; $f.Size = New-Object Drawing.Size(400,150); $f.StartPosition = 'CenterScreen'; $f.FormBorderStyle = 'FixedDialog'; "
    set "GUI_CMD=!GUI_CMD! $l = New-Object Windows.Forms.Label; $l.Location = New-Object Drawing.Point(20,20); $l.Size = New-Object Drawing.Size(350,30); $l.Text = 'Starting...'; $f.Controls.Add($l); $f.Show(); $f.Refresh(); "
    set "GUI_CMD=!GUI_CMD! %PATCH_LOGIC% $f.Close(); "
    powershell -NoProfile -ExecutionPolicy Bypass -Command "!GUI_CMD!" >> "%LOG_FILE%" 2>&1
)

if errorlevel 1 (
  echo ERROR: Optimization failed. See %LOG_FILE%
  if "%SILENT%"=="0" pause
  exit /b 1
)

if "%SILENT%"=="0" (
  echo.
  echo ============================================================================
  echo ✓ SUCCESS: NSFW filter disabled with Evolver upgrades
  echo ============================================================================
  echo.
  pause
)
exit /b 0

:help
echo Usage: NSFW_DISABLE.bat [options]
echo Options:
echo   -s, --silent    Run without user interaction
echo   -p, --path PATH Specify the AI Playground root directory
echo.
if "%SILENT%"=="0" pause
exit /b 0
