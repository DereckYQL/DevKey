# DevKey 2.0 implementation status

## Completed in this reconstruction

- Rebuilt the PowerShell 5.1 launcher as a modular entry point while retaining its terminal menu style and routing all ten main-menu choices.
- Added dynamic USB/DevKey path discovery, central JSON configuration, safe configuration backups, bounded/redacted logs, and consistent error handling.
- Implemented PBKDF2-SHA256 password setup, login and change; legacy record verification/migration; persisted progressive lockout; and a one-use recovery key.
- Added local integrity manifests with explicit review, Guardian identity checks, a visible monitor, per-session process tracking, cooperative close, and opt-in visible current-user AutoLaunch.
- Implemented application detection, project operations, Git workflows, templates, prompt library, profiles, system information, portable-app status, OS utilities, and verified project backup/restore.
- Application lookup now prefers USB copies and falls back to detected host installations. On this host, Kiro 1.2.56, OpenCode 1.18.25, Git 2.55.0, and Node.js 24.19.0 were found. OpenCode's configuration directory is redirected per process to `Data\OpenCode\Config`; its credential database remains in the normal host user-data location.
- Added `Tests\Invoke-DevKeySmokeTests.ps1`. On 2026-10-23 it passed **34 tests** under Windows PowerShell 5.1. The PowerShell parser reported no syntax errors in 32 scripts.
- Before the reconstruction, copied the 37-file project snapshot to `Backups\pre-reconstruction-20261023-214943`. The earlier `Backups\legacy-v1-20261023-214553` was preserved.

## Verification limits and intentionally unavailable features

- A new 32-byte cryptographically random `D:\unlock.k3y` was generated at the user's request. Its digest matches both the launcher pin and `config.json`; the prior config and launcher were backed up. `Config\auth.json` is still absent, so the first real launch will ask the user to create a password. No password was created by the agent.
- The USB `Apps` directories remain empty. Kiro, OpenCode, Git, and Node.js were found as host installations and path/version detection was checked; actual interactive app sessions and close behavior were not tested. Docker Desktop 4.96.3 and CLI 29.9.2 are installed in the current user's profile and are found by DevKey. `docker info --format '{{.ServerVersion}}'` now succeeds and reports server 29.9.2. No test image or container was downloaded or run.
- USB insertion/removal, device serial matching on the target USB, real process shutdown, and AutoLaunch registry installation/removal require a disposable Windows host and the original device. AutoLaunch remains disabled by default.
- A signed updater is not enabled because no authenticated release source or trusted signing key exists in this workspace.
- Project encryption and independent second-factor authentication remain unavailable. See `SECURITY-STATUS.md` for the platform and key-custody requirements; DevKey does not claim these protections.
- The local integrity manifest is unsigned and detects changes only relative to its locally approved baseline. It is not proof of publisher identity.

## Audit history

`AUDIT.md` records the Phase 0 inventory before reconstruction. Its original findings describe that point in time; the implementation and verification status above supersede its “not implemented” and “not tested” statements where they conflict. The original audit file is retained as history.
