<#
.SYNOPSIS
    STARK Controller Script (Transformation)
.DESCRIPTION
    Orchestrates the NSFW Disable process using modular libraries.
    Refactored by Forge to eliminate redundancy and use optimized library logic.
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
    # Validate environment (delegated to Patcher lib)
    if (Test-ComfyEnvironment -BasePath $Path) {
        Write-Status "Bootstrap complete: Environment valid." "Green"
        exit 0
    } else {
        exit 1
    }
}

if ($Restore) {
    Invoke-StarkRestore -BasePath $Path
    exit 0
}

# If Silent or DryRun, we patch immediately without UI
if ($DryRun -or (-not $Check -and $Silent)) {
    Invoke-StarkPatch -BasePath $Path -DryRun:$DryRun
    exit 0
}

# Default: Launch GUI
# Define actions for the UI buttons
$actionPatch = { Invoke-StarkPatch -BasePath $Path }
$actionRestore = { Invoke-StarkRestore -BasePath $Path }

Show-StarkUI -BasePath $Path -PatchAction $actionPatch -RestoreAction $actionRestore
