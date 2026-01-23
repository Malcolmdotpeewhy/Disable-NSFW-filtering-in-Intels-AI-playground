## 2024-10-24 — [Legacy Code Redundancy]
**Learning:** `scripts/core.ps1` contained a mix of modular imports and duplicated, broken inline logic that shadowed the modules. This created a fragile state where the script appeared to work but was likely failing or using incorrect paths if the inline logic was triggered.
**Action:** Always verify that imported modules are actually being used and that legacy code is removed after refactoring to modular architectures.
