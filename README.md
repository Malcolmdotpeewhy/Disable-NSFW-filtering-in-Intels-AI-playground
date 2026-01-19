# NSFW FILTER DISABLER for AI Playground (Evolver-Upgraded) 🧬

This utility disables the NSFW content filtering in ComfyUI-ReActor within the AI Playground environment with maximum efficiency.

## 🚀 Enhancements by Evolver

- **Interactive GUI**: Provides visual progress feedback during execution.
- **Silent Mode**: Support for headless automation via `-s` or `--silent` flags.
- **Environment Diagnostics**: Validates path existence and write permissions before patching.
- **Persistent Settings**: Sets system-level environment variables to ensure the filter remains disabled across sessions.
- **Clean Code**: Refactored to eliminate logic duplication and improve maintainability.

## 🛠 Usage

### Standard Interactive Run
Simply double-click `NSFW DISABLE.bat` in the AI Playground root folder.

### Command Line Options
You can run the script with the following flags for automation:

```batch
NSFW_DISABLE.bat --silent
NSFW_DISABLE.bat --path "C:\Path\To\AI_Playground"
```

## 📂 Automation Scripts

Located in the `scripts/` directory:

- **`scripts/bootstrap.bat`**: Validates that the AI Playground environment is correctly structured.
- **`scripts/run_checks.bat`**: Verifies if the patch is currently active and the environment variable is set.

## ⚠️ Requirements
- Windows OS
- PowerShell 5.1+
- Administrator privileges (for setting environment variables and patching files)

---
*Optimized for AI Playground Bolt & Evolver* ⚡🧬
