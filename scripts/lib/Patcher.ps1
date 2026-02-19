<#
.SYNOPSIS
    Core Patching Logic for STARK.
.DESCRIPTION
    Handles environment validation, surgical patching, and restoration.
#>

function Get-ComfyPaths {
    param($BasePath)

    # Ensure BasePath ends with / for Linux compatibility in path joining if strictly string based,
    # but Join-Path handles it.

    # On Linux/Mock environment, we need to be careful with backslashes vs forward slashes if strictly checking strings.
    # Join-Path uses OS separator.

    return @{
        Config = Join-Path $BasePath "resources/ComfyUI/models/nsfw_detector/vit-base-nsfw-detector/config.json"
        Preprocessor = Join-Path $BasePath "resources/ComfyUI/models/nsfw_detector/vit-base-nsfw-detector/preprocessor_config.json"
        ReactorSfw = Join-Path $BasePath "resources/ComfyUI/custom_nodes/comfyui-reactor/scripts/reactor_sfw.py"
        BackupRoot = Join-Path $BasePath "backups/nsfw_disable"
    }
}

function Test-ComfyEnvironment {
    param($BasePath)

    Write-Status "Validating environment at: $BasePath" "Cyan"

    $paths = Get-ComfyPaths -BasePath $BasePath
    $required = @(
        (Split-Path $paths.Config -Parent),
        (Split-Path $paths.ReactorSfw -Parent)
    )

    $allFound = $true
    foreach ($p in $required) {
        if (-not (Test-Path $p)) {
            Write-Status "MISSING: $p" "Red"
            $allFound = $false
        }
    }

    return $allFound
}

function Create-Backup {
    param($File, $BackupRoot)

    if (-not (Test-Path $BackupRoot)) { New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $fileName = Split-Path $file -Leaf
    $dest = Join-Path $BackupRoot "$fileName.$timestamp.bak"

    Copy-Item $File $dest -Force
    Write-Status "Backup created: $fileName" "Gray"
}

function Invoke-StarkPatch {
    param(
        [string]$BasePath,
        [switch]$DryRun
    )

    $paths = Get-ComfyPaths -BasePath $BasePath

    if (-not (Test-ComfyEnvironment -BasePath $BasePath)) {
        Write-Status "Environment check failed. Aborting." "Red"
        return
    }

    # 1. Patch JSON Configs
    $jsonFiles = @($paths.Config, $paths.Preprocessor)
    foreach ($file in $jsonFiles) {
        if (-not (Test-Path $file)) { continue }

        Write-Status "Patching $(Split-Path $file -Leaf)..." "Cyan"

        try {
            $jsonContent = Get-Content -Raw $file
            $json = $jsonContent | ConvertFrom-Json

            # Add bypass keys
            $json | Add-Member -NotePropertyMembers @{
                "nsfw_bypass"            = $true
                "nsfw_disabled"          = $true
                "bypass_safety_check"    = $true
                "safety_check_threshold" = 9999.0
                "STARK_MARKER"           = "STARK-Surgical"
            } -Force

            if (-not $DryRun) {
                Create-Backup -File $file -BackupRoot $paths.BackupRoot
                $json | ConvertTo-Json -Depth 20 | Set-Content $file
            }
        } catch {
            Write-Status "Error patching JSON: $_" "Red"
        }
    }

    # 2. Patch Python
    Write-Status "Injecting bypass into reactor_sfw.py..." "Cyan"
    if (Test-Path $paths.ReactorSfw) {
        $content = Get-Content -Raw $paths.ReactorSfw

        if ($content -match "STARK-Surgical") {
            Write-Status "ReActor script already patched." "Green"
        } else {
            # Header Injection
            $injection = @"

# --- STARK-Surgical Bypass Start ---
# Optimized by STARK 🦾
import os
REACTOR_NSFW_DISABLED = os.environ.get("REACTOR_NSFW_DISABLED", "false").lower() == "true"
# --- STARK-Surgical Bypass End ---

"@
            $newContent = $injection + $content

            # Function Body Injection
            # We look for the function definition and inject the check immediately after
            # STARK Robustness: Detect indentation from the def line to better guess body indentation (usually +4 spaces)
            $pattern = "([ \t]*)def nsfw_image\(.*?\):"

            if ($newContent -match $pattern) {
                $baseIndent = $matches[1]
                $bodyIndent = $baseIndent + "    " # Assume 4 spaces standard for Python

                # Check if the file uses tabs (naive check on first few lines)
                if ($content.Substring(0, [math]::Min(200, $content.Length)) -match "\t") {
                    $bodyIndent = $baseIndent + "`t"
                }

                # Construct replacement using dynamic indentation
                $replacement = "$&`r`n$bodyIndent" + "if os.environ.get('REACTOR_NSFW_DISABLED', 'false').lower() == 'true': return False # STARK-Surgical"

                $newContent = $newContent -replace $pattern, $replacement

                if (-not $DryRun) {
                    Create-Backup -File $paths.ReactorSfw -BackupRoot $paths.BackupRoot
                    # Atomic Write
                    $tempFile = $paths.ReactorSfw + ".tmp"
                    $newContent | Set-Content $tempFile -Encoding utf8
                    Move-Item $tempFile $paths.ReactorSfw -Force
                    Write-Status "Python bypass injected successfully." "Green"
                } else {
                     Write-Status "[DryRun] Would write python patch." "Gray"
                }
            } else {
                Write-Status "FAILED to find nsfw_image function signature!" "Red"
            }
        }
    }

    # 3. Environment Variable (User Scope)
    # Optimized to handle platform differences
    if (-not $DryRun) {
        try {
            [System.Environment]::SetEnvironmentVariable('REACTOR_NSFW_DISABLED', 'true', 'User')
            Write-Status "Environment variable set: REACTOR_NSFW_DISABLED=true" "Green"
        } catch {
             Write-Status "Warning: Could not set persistent environment variable (Likely Non-Windows). Setting for session." "Yellow"
             $env:REACTOR_NSFW_DISABLED = 'true'
        }
    }
}

function Invoke-StarkRestore {
    param([string]$BasePath)

    $paths = Get-ComfyPaths -BasePath $BasePath
    Write-Status "Restoring from backups at $($paths.BackupRoot)..." "Cyan"

    if (-not (Test-Path $paths.BackupRoot)) {
        Write-Status "No backups found." "Red"
        return
    }

    $targets = @{
        "config.json" = $paths.Config
        "preprocessor_config.json" = $paths.Preprocessor
        "reactor_sfw.py" = $paths.ReactorSfw
    }

    foreach ($key in $targets.Keys) {
        $targetPath = $targets[$key]
        $backups = Get-ChildItem -Path $paths.BackupRoot -Filter "$key.*.bak" | Sort-Object LastWriteTime -Descending

        if ($backups.Count -gt 0) {
            $latest = $backups[0]
            Write-Status "Restoring $key from $($latest.Name)..." "Gray"
            Copy-Item $latest.FullName $targetPath -Force
        } else {
            Write-Status "No backup found for $key" "Yellow"
        }
    }

    try {
        [System.Environment]::SetEnvironmentVariable('REACTOR_NSFW_DISABLED', $null, 'User')
        Write-Status "Environment variable cleared." "Green"
    } catch {
        Write-Status "Warning: Could not clear persistent environment variable." "Yellow"
    }
}
