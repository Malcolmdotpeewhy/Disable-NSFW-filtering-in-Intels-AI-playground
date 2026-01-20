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

if ($Setup) {
    if (Test-ComfyEnvironment -BasePath $Path) {
        Write-Status "Bootstrap complete: Environment valid." "Green"
        exit 0
    } else {
        exit 1
    }
}

if ($Check) {
    if (Test-ComfyEnvironment -BasePath $Path) {
        # Todo: Deep check of patch status
        Write-Status "Environment exists." "Green"
        exit 0
    }
    exit 1
}

# Define Actions for UI/CLI
$actionPatch = { Invoke-StarkPatch -BasePath $Path -DryRun:$DryRun }
$actionRestore = { Invoke-StarkRestore -BasePath $Path }

if ($Restore) {
    & $actionRestore
    exit 0
}

# Default Flow
if ($Silent) {
    & $actionPatch
} else {
    # If environment is blatantly missing, warn before UI?
    # UI handles logging, so we just launch it.
    Show-StarkUI -BasePath $Path -PatchAction $actionPatch -RestoreAction $actionRestore
}
