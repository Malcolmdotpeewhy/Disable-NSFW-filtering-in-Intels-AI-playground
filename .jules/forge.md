## 2024-05-23 — [PowerShell] Inline Optimization Regression
**Learning:** Legacy inline code in `core.ps1` contained a hot-path optimization (checking a global variable `REACTOR_NSFW_DISABLED`) which was missing from the "modern" modular library `Patcher.ps1`, which used a slower `os.environ.get` call in the loop.
**Action:** When refactoring legacy scripts into modules, always diff the logic to ensure subtle optimizations (like variable caching) are preserved.
