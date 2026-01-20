<#
.SYNOPSIS
    Centralized Logging and Status Feedback for STARK.
.DESCRIPTION
    Provides Write-Status and logging capabilities that can bridge to UI or Console.
#>

$Script:StatusCallback = $null

function Register-StatusCallback {
    param([scriptblock]$Callback)
    $Script:StatusCallback = $Callback
}

function Write-Status {
    param(
        [string]$Message,
        [string]$Color = "White",
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    $formattedMsg = "[$timestamp] $Message"

    # Console Output
    Write-Host "[STARK] $Message" -ForegroundColor $Color

    # UI Callback if registered
    if ($Script:StatusCallback) {
        $eventArgs = @{
            Message = $formattedMsg
            Color = $Color
            Level = $Level
        }
        & $Script:StatusCallback $eventArgs
    }
}
