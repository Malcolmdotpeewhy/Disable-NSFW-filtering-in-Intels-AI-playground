# STARK Journal - NSFW Disabler Transformation

## 2025-05-14 – Initial Diagnosis
**Learning:** The current architecture relies on Batch scripts containing giant PowerShell strings. This creates a "technical debt trap" where logic is hard to maintain, debug, or evolve due to quoting and escaping complexities. The patching method is also destructive (overwriting files), which is risky for upstream compatibility.
**Action:** STARK will move the core logic to a standalone PowerShell script (`scripts/core.ps1`) and implement surgical patching (regex-based) to improve reliability and DX.

## 2025-05-14 – Architecture Strategy
**Learning:** Consolidating bootstrap, check, and patch logic into a single PowerShell module reduces process spawning overhead and provides a unified "source of truth" for the system state.
**Action:** Implement a unified CLI/GUI interface in `scripts/core.ps1` that handles all phases of the lifecycle.

## 2025-05-14 – Surgical vs Destructive Patching
**Learning:** Overwriting core system files is a major risk for maintenance. Using regex-based surgical injection allows the tool to coexist with upstream updates while still providing the required bypass logic.
**Action:** Transitioned from full file overwrites to targeted string replacement for `reactor_sfw.py`.

## 2025-05-14 – GUI/CLI Unified Interface
**Learning:** Power users need CLI flags for automation, but typical users prefer a GUI. Building both into the same PowerShell core ensures that the logic is identical across both interfaces.
**Action:** Developed a WinForms-based GUI that exposes the same functionality as the CLI arguments.
