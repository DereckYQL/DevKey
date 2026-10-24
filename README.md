# DevKey 2.0

DevKey is a PowerShell 5.1 launcher for a portable Windows development workspace. The launcher keeps the existing terminal style and calculates the USB and DevKey roots from its own location.

## USB layout

The current layout keeps `DevKey` beside the USB's `Apps`, `Data`, and `Projects` folders. `unlock.k3y` stays at the USB root.

```text
USB root\
  unlock.k3y
  Apps\Kiro\Kiro.exe
  Apps\OpenCode\opencode.exe
  Apps\Git\cmd\git.exe
  Apps\Node\node.exe
  Data\KiroUser\
  Data\Vault\devkey.kdbx
  Projects\
  DevKey\
    Launcher\DevKey.ps1
    Config\config.json
    Config\auth.json          created on first use
    Config\manifests\integrity.json  created only on request
    Core\
    Security\
    Guardian\
    Modules\
    Logs\
    Backups\
```

Moving the USB to another drive letter is supported. A new 32-byte random `unlock.k3y` was generated at the user's request; its SHA-256 is pinned in the launcher and configuration. The pre-enrollment launcher and config are backed up under `DevKey\Backups\token-enrollment-*`. The first launch still requires the user to create the DevKey password.

## Start and menu

Run `Launcher\DevKey.bat` or `Launcher\DevKey.ps1`. The batch file does not bypass Windows execution policy. If the host blocks scripts, follow that computer's approved policy; DevKey does not change it.

After token verification and sign-in, the main menu provides:

1. Kiro
2. OpenCode
3. Kiro and OpenCode
4. Projects: list, create, open, rename, delete with explicit confirmation, terminal, Git init, templates, and prompts
5. Git / GitHub: status, clone, safe pull, push, commit, branches, history, credentials, backups, and sync history
6. System status
7. Security and KeePass
8. Maintenance, integrity, authentication, recovery, backups, and Guardian
9. Configuration and themes
0. Exit

Missing applications are reported and do not stop the launcher. Application paths can be changed in `Config\config.json`; relative application paths resolve from the USB root. DevKey prefers the configured USB copy, then detects Kiro in the current user's LocalAppData install, OpenCode's npm-installed native executable, and Git/Node/Docker on standard system paths. These fallbacks work on this computer but are not copied to the USB, so they are not portable to another host.

When DevKey starts OpenCode, it sets `XDG_CONFIG_HOME` for that child process to `Data\OpenCode\Config` on the USB, avoiding a dependency on a fixed `.config` path. OpenCode keeps its own authentication and session database in its normal per-user data directory; DevKey does not redirect those credentials to the USB. Avoid putting API keys directly in USB configuration files.

## Authentication and recovery

On first use, DevKey asks for a password and stores a salted PBKDF2-SHA256 record in `Config\auth.json`. Existing legacy PBKDF2-SHA256 hex records and PBKDF2-SHA1 records are verified; after a successful legacy login, DevKey writes a new record and backs up the prior file. Invalid authentication files are never silently replaced.

Failed attempts persist in `Config\lockout.json`. The progressive wait begins at 30 seconds after the third accumulated failure, five minutes after the fifth, and 30 minutes after the tenth. A successful sign-in or recovery clears the counter. Changing a password requires the current password.

The recovery key is generated from the cryptographic random-number generator, shown once, and stored as a verifier in `Config\recovery.json`. Keep the displayed value outside the USB. Successful recovery sets a new password and consumes the recovery key. The verifier is on the same USB as the authentication file, so this does not protect against an attacker who can rewrite DevKey files. The password gate does not encrypt projects or other USB contents.

## Integrity

The token file is compared with a SHA-256 value pinned in both the launcher and initial configuration. This checks possession of that exact file; it does not authenticate the launcher itself if someone can modify the launcher and its configuration together.

The optional local manifest covers DevKey PowerShell scripts. Create it only after reviewing the current code from **Maintenance > Create local manifest**. A mismatch blocks application launching until it is reviewed. The manifest is explicitly marked `UNSIGNED-LOCAL`: it detects accidental or one-sided edits but cannot prove who supplied the files or resist coordinated changes to code and manifest.

## Guardian and AutoLaunch

Guardian identifies a volume by its configured volume serial and verifies the token hash. It starts a separate, visible PowerShell monitor after authentication when Guardian is enabled and a volume identity has been registered. It tracks only process IDs started by that DevKey session, then checks PID, start time, and executable path before requesting a cooperative close. Per-application AutoClose is configurable. Forced termination is off by default.

AutoLaunch is optional and off by default. The configuration menu can install a visible current-user watcher after explicit confirmation. It copies `Guardian\HostWatcher.ps1` and a non-secret device identity file to `%LOCALAPPDATA%\DevKey\Guardian` and adds a `DevKeyGuardian` value under the current user's Run key. The watcher polls for the expected removable volume, verifies the token and any configured local manifest, and launches the normal authenticated launcher once per insertion. The menu can remove the Run value and watcher files. Its local log is retained at `%LOCALAPPDATA%\DevKey\Guardian\guardian-host.log`.

Sudden removal can interrupt saves or leave application-owned temporary data behind. Guardian requests orderly closes; it cannot guarantee that applications save successfully.

## Git, projects, backups, and prompts

Project names are validated and resolved below the configured Projects directory. Windows device names, path traversal, and existing project symlinks that resolve outside Projects are rejected. Delete requires typing `ELIMINAR`.

Git prefers portable Git and falls back to `git.exe` from PATH. Pull is refused when the worktree has changes; push and commits require confirmation. Git identity defaults to repository-local scope; host-global scope is separate and confirmed. Credentials must use an installed credential helper; tokens are not placed in DevKey config or logs.

Project backups are written to `DevKey\Backups`, hashed and verified before being reported as successful. Ordinary backups omit `.env` files, private-key patterns, recovery paths, and `.git\config`; therefore a restored repository may need its remote configured again. Restore verifies the archive and extracts into a new directory without overwriting projects.

Templates create source files only; they do not install packages. Each generated README lists the runtime/dependencies. Prompts are stored as text files under `Data\Prompts`; their content is not written to access logs.

## Logs and configuration

`Config\config.json` is validated at startup. Missing optional properties receive safe defaults in memory; invalid JSON or unsafe values stop startup without replacing the file. The configuration menu backs up the current JSON before saving changes.

DevKey writes bounded logs under `DevKey\Logs`. It redacts common GitHub token forms and credential-bearing URLs. It does not alter Windows event logs or claim to remove all traces from the host. `auth.json`, projects, logs, and other files on FAT32/exFAT do not receive Windows ACL protection from this launcher.

## Current implementation limits

- A trusted signed updater is not enabled: this checkout has no trusted update source/signing key. The legacy Git updater is intentionally not exposed as a verified updater.
- The project-encryption feature is not enabled. PowerShell 5.1's standard .NET Framework does not provide the requested AES-GCM API; DevKey does not substitute an unreviewed cipher design.
- A second login factor is not enabled. A local PIN would not be independent, and this checkout has no protected portable TOTP seed or external hardware factor configured.
- Docker Desktop is installed per-user on the current host, and `docker info` confirms that the local engine responds. The installation is host-specific, not portable; this verification did not download or run a container image.
- A local SHA-256 manifest is unsigned and is not a substitute for a signed release.
- USB extraction, actual Kiro/OpenCode builds, volume serial detection, registry AutoLaunch installation/removal, and physical-disconnect process closure require validation on the original USB and a disposable Windows test host.

## Verification

Run the PowerShell 5.1 smoke suite:

```powershell
powershell.exe -NoProfile -File .\Tests\Invoke-DevKeySmokeTests.ps1
```

The suite uses temporary folders and mock input. It exercises config validation/preservation, PBKDF2 setup/login/change/recovery, lockout persistence, log redaction, path validation, application resolution, backup verification/restoration, templates, process ownership, local-manifest mismatch detection, dynamic root calculation, and the main-menu routes. It does not substitute for the physical USB tests listed above.
