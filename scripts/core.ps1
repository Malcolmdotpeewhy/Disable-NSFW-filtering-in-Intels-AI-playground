<#
.SYNOPSIS
    STARK Controller Script (Transformation)
.DESCRIPTION
    Orchestrates the NSFW Disable process using modular libraries.
#>

Param(
    [Parameter(Mandatory=$false)] [Alias("s")] [switch]$Silent,
    [Parameter(Mandatory=$false)] [Alias("p")] [string]$Path = (Get-Item -Path $PSScriptRoot).Parent.FullName,
    [Parameter(Mandatory=$false)] [switch]$Check,
    [Parameter(Mandatory=$false)] [switch]$Setup,
    [Parameter(Mandatory=$false)] [switch]$Restore,
    [Parameter(Mandatory=$false)] [switch]$DryRun
)

# Initialize Error Handling
$ErrorActionPreference = "Stop"

# Load Modules
try {
    . "$PSScriptRoot\lib\Logger.ps1"
    . "$PSScriptRoot\lib\Patcher.ps1"
    . "$PSScriptRoot\lib\UI.ps1"
} catch {
    Write-Host "[FATAL] Failed to load STARK libraries: $_" -ForegroundColor Red
    exit 1
}

# Normalize Path
if (-not $Path.EndsWith("\") -and -not $Path.EndsWith("/")) { $Path += "\" }

# --- Actions ---

# Define Actions as ScriptBlocks for reuse in UI and CLI
$actionPatch = {
    Invoke-StarkPatch -BasePath $Path -DryRun:$DryRun
}

$actionRestore = {
    Invoke-StarkRestore -BasePath $Path
}

# CLI Flags Logic

if ($Setup) {
    if (Test-ComfyEnvironment -BasePath $Path) {
        Write-Status "Bootstrap complete: Environment valid." "Green"
        exit 0
    } else {
        exit 1
    }
}

if ($Check) {
    Write-Status "Checking environment..." "Cyan"
    if (Test-ComfyEnvironment -BasePath $Path) {
        Write-Status "Environment checks passed." "Green"
        exit 0
    } else {
        Write-Status "Environment checks failed." "Red"
        exit 1
    }
}

if ($Restore) {
    & $actionRestore
    exit 0
}

# Main Execution Flow

if ($Silent) {
    & $actionPatch
    exit 0
}

# Interactive UI Mode
Show-StarkUI -BasePath $Path -PatchAction $actionPatch -RestoreAction $actionRestore
