$ErrorActionPreference = "Stop"

$MockRoot = Join-Path $PSScriptRoot "mock_env"
if (Test-Path $MockRoot) { Remove-Item $MockRoot -Recurse -Force }
New-Item -ItemType Directory -Path $MockRoot -Force | Out-Null

$DetectorPath = Join-Path $MockRoot "resources\ComfyUI\models\nsfw_detector\vit-base-nsfw-detector"
$ReactorPath = Join-Path $MockRoot "resources\ComfyUI\custom_nodes\comfyui-reactor\scripts"

New-Item -ItemType Directory -Path $DetectorPath -Force | Out-Null
New-Item -ItemType Directory -Path $ReactorPath -Force | Out-Null

# Mock Config JSON
$configJson = @{
    "architectures" = @("VitForImageClassification")
    "model_type" = "vit"
} | ConvertTo-Json
$configJson | Set-Content (Join-Path $DetectorPath "config.json")

# Mock Preprocessor Config JSON
$prepJson = @{
    "do_normalize" = $true
    "size" = 224
} | ConvertTo-Json
$prepJson | Set-Content (Join-Path $DetectorPath "preprocessor_config.json")

# Mock Python Script
$pyScript = @"
import os
import torch
from PIL import Image

def load_model():
    print("Loading model...")

def nsfw_image(image):
    # Original logic
    if not image:
        return False
    # ... complex logic ...
    return True

def main():
    pass
"@
$pyScript | Set-Content (Join-Path $ReactorPath "reactor_sfw.py") -Encoding UTF8

Write-Host "Mock environment created at: $MockRoot"
