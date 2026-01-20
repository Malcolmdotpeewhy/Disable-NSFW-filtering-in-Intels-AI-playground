$ErrorActionPreference = "Stop"

# Setup
$ScriptDir = $PSScriptRoot
. (Join-Path $ScriptDir "setup_mock.ps1")

$MockRoot = Join-Path $ScriptDir "mock_env"
$CoreScript = Join-Path $ScriptDir "..\scripts\core.ps1"

# --- Test 1: Dry Run ---
Write-Host "`n[TEST] Running Dry Run..." -ForegroundColor Cyan
pwsh -File $CoreScript -Path $MockRoot -DryRun -Silent
if ($LASTEXITCODE -ne 0) { throw "Dry Run failed with exit code $LASTEXITCODE" }

# Verify NO changes
$pyContent = Get-Content (Join-Path $MockRoot "resources/ComfyUI/custom_nodes/comfyui-reactor/scripts/reactor_sfw.py") -Raw
if ($pyContent -match "STARK-Surgical") { throw "Dry Run modified files!" }

# --- Test 2: Apply Patch ---
Write-Host "`n[TEST] Applying Patch..." -ForegroundColor Cyan
# We simulate the patching by running the script targeting the mock root
# Note: We must be careful about the env var since it's user-scoped.
# Ideally we mock [System.Environment], but since we are spawning a process,
# we will just accept that it sets the env var on this machine for the test user.
pwsh -File $CoreScript -Path $MockRoot -Silent

if ($LASTEXITCODE -ne 0) { throw "Patch failed with exit code $LASTEXITCODE" }

# Verify Python Content
$pyContent = Get-Content (Join-Path $MockRoot "resources/ComfyUI/custom_nodes/comfyui-reactor/scripts/reactor_sfw.py") -Raw
if ($pyContent -notmatch "STARK-Surgical") { throw "Patch did not inject STARK marker!" }
if ($pyContent -notmatch "REACTOR_NSFW_DISABLED") { throw "Patch did not inject logic!" }

# Verify JSON Content
$jsonContent = Get-Content (Join-Path $MockRoot "resources/ComfyUI/models/nsfw_detector/vit-base-nsfw-detector/config.json") -Raw
if ($jsonContent -notmatch '"nsfw_bypass":\s*true') { throw "JSON config not patched!" }

# --- Test 3: Idempotency (Run again) ---
Write-Host "`n[TEST] Checking Idempotency..." -ForegroundColor Cyan
pwsh -File $CoreScript -Path $MockRoot -Silent
$pyContent2 = Get-Content (Join-Path $MockRoot "resources/ComfyUI/custom_nodes/comfyui-reactor/scripts/reactor_sfw.py") -Raw
# Check for double injection (naive check: count occurrences)
$count = ([regex]::Matches($pyContent2, "STARK-Surgical Bypass Start")).Count
if ($count -gt 1) { throw "Patch was applied twice!" }

# --- Test 4: Restore ---
Write-Host "`n[TEST] Restoring..." -ForegroundColor Cyan
pwsh -File $CoreScript -Path $MockRoot -Restore -Silent

$pyContent3 = Get-Content (Join-Path $MockRoot "resources/ComfyUI/custom_nodes/comfyui-reactor/scripts/reactor_sfw.py") -Raw
if ($pyContent3 -match "STARK-Surgical") { throw "Restore failed to remove patch!" }

Write-Host "`n[SUCCESS] All tests passed." -ForegroundColor Green
