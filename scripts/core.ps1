<#
.SYNOPSIS
    Core logic for NSFW Filter Disabler in AI Playground.
    Optimized by STARK 🦾

.DESCRIPTION
    Handles environment validation, surgical patching of ComfyUI-ReActor,
    and GUI management.
#>

Param(
    [Parameter(Mandatory=$false)]
    [Alias("s")]
    [switch]$Silent,

    [Parameter(Mandatory=$false)]
    [Alias("p")]
    [string]$Path = (Get-Item -Path $PSScriptRoot).Parent.FullName,

    [Parameter(Mandatory=$false)]
    [switch]$Check,

    [Parameter(Mandatory=$false)]
    [switch]$Setup,

    [Parameter(Mandatory=$false)]
    [switch]$Restore,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [switch]$Help
)

if ($Help) {
    Write-Host "NSFW Filter Disabler Core (STARK Transformation)" -ForegroundColor Cyan
    Write-Host "Usage: powershell -File scripts/core.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Silent, -s   Run without GUI"
    Write-Host "  -Path, -p     AI Playground root directory (defaults to parent of scripts/)"
    Write-Host "  -Check        Validate environment and patch status"
    Write-Host "  -Setup        Run initial bootstrap checks"
    Write-Host "  -Restore      Revert patches using backups"
    Write-Host "  -DryRun       Simulate patching without writing to files"
    Write-Host "  -Help         Show this help message"
    exit 0
}

# Ensure Path ends with a backslash if it doesn't
if (-not $Path.EndsWith("\")) { $Path += "\" }

Write-Host "[STARK] Initialized core with base path: $Path" -ForegroundColor Gray

# --- Constants & Paths ---
$NSFW_CONFIG = Join-Path $Path "resources\ComfyUI\models\nsfw_detector\vit-base-nsfw-detector\config.json"
$NSFW_PREPROCESSOR = Join-Path $Path "resources\ComfyUI\models\nsfw_detector\vit-base-nsfw-detector\preprocessor_config.json"
$REACTOR_SFW = Join-Path $Path "resources\ComfyUI\custom_nodes\comfyui-reactor\scripts\reactor_sfw.py"
$BACKUP_ROOT = Join-Path $Path "backups\nsfw_disable"

# --- Utility Functions ---
function Write-Status ($message, $color = "White") {
    Write-Host "[STARK] $message" -ForegroundColor $color
}

function Test-Environment {
    Write-Status "Validating environment..." "Cyan"
    $requiredPaths = @(
        "resources\ComfyUI\models",
        "resources\ComfyUI\custom_nodes",
        (Split-Path $NSFW_CONFIG -Parent),
        (Split-Path $REACTOR_SFW -Parent)
    )

    $allFound = $true
    foreach ($rp in $requiredPaths) {
        $fullPath = Join-Path $Path $rp
        if (-not (Test-Path $fullPath)) {
            Write-Status "MISSING: $fullPath" "Red"
            $allFound = $false
        } else {
            Write-Status "Found: $rp" "Green"
        }
    }

    if (-not $allFound) {
        Write-Status "Environment validation FAILED." "Red"
        return $false
    }

    # Test write permission
    try {
        $testFile = Join-Path $Path "stark_perm_test.tmp"
        New-Item -Path $testFile -ItemType File -Force | Out-Null
        Remove-Item $testFile -Force
        Write-Status "Write permissions: OK" "Green"
    } catch {
        Write-Status "PERMISSION DENIED: Cannot write to $Path" "Red"
        return $false
    }

    return $true
}

function Get-PatchStatus {
    Write-Status "Checking patch status..." "Cyan"
    $isPatched = $false
    if (Test-Path $REACTOR_SFW) {
        if (Select-String -Path $REACTOR_SFW -Pattern "STARK-Surgical|Bolt-Optimized") {
            $isPatched = $true
        }
    }

    $envVar = [System.Environment]::GetEnvironmentVariable('REACTOR_NSFW_DISABLED', 'User')
    $isEnvSet = ($envVar -eq 'true')

    if ($isPatched) { Write-Status "Patch status: ACTIVE" "Green" }
    else { Write-Status "Patch status: INACTIVE" "Yellow" }

    if ($isEnvSet) { Write-Status "Environment variable: ACTIVE" "Green" }
    else { Write-Status "Environment variable: INACTIVE" "Yellow" }

    return ($isPatched -and $isEnvSet)
}

# --- Main Execution Logic ---
if ($Check) {
    $envOk = Test-Environment
    $patchOk = Get-PatchStatus
    if ($envOk -and $patchOk) {
        Write-Status "SUCCESS: System is healthy and patched." "Green"
        exit 0
    } else {
        Write-Status "System check encountered issues." "Yellow"
        exit 1
    }
}

function Create-Backup ($file) {
    if (-not (Test-Path $BACKUP_ROOT)) { New-Item -ItemType Directory -Path $BACKUP_ROOT -Force | Out-Null }
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $fileName = Split-Path $file -Leaf
    $dest = Join-Path $BACKUP_ROOT "$fileName.$timestamp.bak"
    Copy-Item $file $dest -Force
    Write-Status "Backup created: $fileName" "Gray"
}

function Invoke-Patch {
    Write-Status "Starting surgical patch..." "Cyan"

    if (-not (Test-Environment)) { return }

    if ($DryRun) { Write-Status "DRY RUN: No changes will be written." "Yellow" }

    # 1. Patch JSON Configs
    $jsonFiles = @($NSFW_CONFIG, $NSFW_PREPROCESSOR)
    foreach ($file in $jsonFiles) {
        Write-Status "Patching $(Split-Path $file -Leaf)..."
        $json = Get-Content -Raw $file | ConvertFrom-Json
        $json | Add-Member -Name "nsfw_bypass" -Value $true -Force
        $json | Add-Member -Name "nsfw_disabled" -Value $true -Force
        $json | Add-Member -Name "bypass_safety_check" -Value $true -Force
        $json | Add-Member -Name "safety_check_threshold" -Value 9999.0 -Force
        $json | Add-Member -Name "STARK_MARKER" -Value "STARK-Surgical" -Force

        $newJson = $json | ConvertTo-Json -Depth 20
        if (-not $DryRun) {
            Create-Backup $file
            $newJson | Set-Content $file
        }
    }

    # 2. Surgical Python Patching
    Write-Status "Injecting bypass into reactor_sfw.py..."
    $content = Get-Content -Raw $REACTOR_SFW

    if ($content -like "*STARK-Surgical*") {
        Write-Status "ReActor script already patched." "Green"
    } else {
        $injection = @"

# --- STARK-Surgical Bypass Start ---
# Optimized by STARK 🦾
import os
REACTOR_NSFW_DISABLED = os.environ.get("REACTOR_NSFW_DISABLED", "false").lower() == "true"
# --- STARK-Surgical Bypass End ---

"@
        $content = $injection + $content

        # Inject "if REACTOR_NSFW_DISABLED: return False" into nsfw_image function
        $pattern = "(def nsfw_image\(.*?\):)"
        $replacement = "`$1`r`n    if os.environ.get('REACTOR_NSFW_DISABLED', 'false').lower() == 'true': return False # STARK-Surgical"

        if ($content -match $pattern) {
            $content = $content -replace $pattern, $replacement
            if (-not $DryRun) {
                Create-Backup $REACTOR_SFW
                $content | Set-Content $REACTOR_SFW -Encoding utf8
            }
            Write-Status "Python bypass injected successfully." "Green"
        } else {
            Write-Status "FAILED to find nsfw_image function signature!" "Red"
            if (-not $DryRun) { exit 1 }
        }
    }

    # 3. Environment Variable
    Write-Status "Setting environment variable..."
    if (-not $DryRun) {
        [System.Environment]::SetEnvironmentVariable('REACTOR_NSFW_DISABLED', 'true', 'User')
    }
    Write-Status "Environment variable set: REACTOR_NSFW_DISABLED=true" "Green"

    Write-Status "PATCH COMPLETE" "Cyan"
}

function Invoke-Restore {
    Write-Status "Restoring from backups..." "Cyan"
    if (-not (Test-Path $BACKUP_ROOT)) {
        Write-Status "No backup directory found at $BACKUP_ROOT" "Red"
        return
    }

    $targets = @("config.json", "preprocessor_config.json", "reactor_sfw.py")
    foreach ($t in $targets) {
        $backups = Get-ChildItem -Path $BACKUP_ROOT -Filter "$t.*.bak" | Sort-Object LastWriteTime -Descending
        if ($backups.Count -gt 0) {
            $latest = $backups[0]
            $dest = ""
            if ($t -like "*.json") {
                $dest = if ($t -eq "config.json") { $NSFW_CONFIG } else { $NSFW_PREPROCESSOR }
            } else {
                $dest = $REACTOR_SFW
            }

            Write-Status "Restoring $t from $($latest.Name)..."
            Copy-Item $latest.FullName $dest -Force
        } else {
            Write-Status "No backups found for $t" "Yellow"
        }
    }

    Write-Status "Removing environment variable..."
    [System.Environment]::SetEnvironmentVariable('REACTOR_NSFW_DISABLED', $null, 'User')

    Write-Status "RESTORE COMPLETE" "Green"
}

if ($Restore) {
    Invoke-Restore
    exit 0
}

function Invoke-GUI {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object Windows.Forms.Form
    $form.Text = "STARK: NSFW Disabler"
    $form.Size = New-Object Drawing.Size(500, 350)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false

    $label = New-Object Windows.Forms.Label
    $label.Location = New-Object Drawing.Point(20, 20)
    $label.Size = New-Object Drawing.Size(460, 30)
    $label.Text = "AI Playground NSFW Disabler (STARK Transformation)"
    $label.Font = New-Object Drawing.Font("Segoe UI", 12, [Drawing.FontStyle]::Bold)
    $form.Controls.Add($label)

    $logBox = New-Object Windows.Forms.TextBox
    $logBox.Location = New-Object Drawing.Point(20, 60)
    $logBox.Size = New-Object Drawing.Size(445, 180)
    $logBox.Multiline = $true
    $logBox.ReadOnly = $true
    $logBox.ScrollBars = "Vertical"
    $logBox.Font = New-Object Drawing.Font("Consolas", 9)
    $logBox.BackColor = "Black"
    $logBox.ForeColor = "LightGreen"
    $form.Controls.Add($logBox)

    $btnPatch = New-Object Windows.Forms.Button
    $btnPatch.Location = New-Object Drawing.Point(20, 260)
    $btnPatch.Size = New-Object Drawing.Size(140, 35)
    $btnPatch.Text = "Apply Patch"
    $form.Controls.Add($btnPatch)

    $btnRestore = New-Object Windows.Forms.Button
    $btnRestore.Location = New-Object Drawing.Point(170, 260)
    $btnRestore.Size = New-Object Drawing.Size(140, 35)
    $btnRestore.Text = "Restore Original"
    $form.Controls.Add($btnRestore)

    $btnClose = New-Object Windows.Forms.Button
    $btnClose.Location = New-Object Drawing.Point(325, 260)
    $btnClose.Size = New-Object Drawing.Size(140, 35)
    $btnClose.Text = "Exit"
    $form.Controls.Add($btnClose)

    # Override Write-Status for GUI
    $script:oldWriteStatus = Get-Item function:Write-Status
    function Write-Status ($message, $color = "White") {
        $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $message`r`n")
        $logBox.SelectionStart = $logBox.Text.Length
        $logBox.ScrollToCaret()
    }

    $btnPatch.Add_Click({
        $btnPatch.Enabled = $false
        $btnRestore.Enabled = $false
        Invoke-Patch
        $form.Refresh()
        $btnPatch.Enabled = $true
        $btnRestore.Enabled = $true
    })

    $btnRestore.Add_Click({
        $btnPatch.Enabled = $false
        $btnRestore.Enabled = $false
        Invoke-Restore
        $form.Refresh()
        $btnPatch.Enabled = $true
        $btnRestore.Enabled = $true
    })

    $btnClose.Add_Click({ $form.Close() })

    $form.ShowDialog() | Out-Null
}

if ($DryRun -or (-not $Check -and -not $Setup -and -not $Restore -and $Silent)) {
    Invoke-Patch
    exit 0
}

if (-not $Silent -and -not $Check -and -not $Setup -and -not $Restore) {
    Invoke-GUI
    exit 0
}

if ($Setup) {
    if (Test-Environment) {
        Write-Status "Bootstrap complete." "Green"
        exit 0
    } else {
        exit 1
    }
}
