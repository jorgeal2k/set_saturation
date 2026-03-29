# CLAUDE.md — Saturation Magisk Module

This file documents the codebase structure, conventions, and workflows for AI assistants
working in this repository.

## Project Overview

**Name:** Set Saturation at boot (`set_saturation_boot`)
**Version:** 1.03 (versionCode 103)
**Author:** jorge2k
**Platform:** Android via [Magisk](https://github.com/topjohnwu/Magisk) (v20.4+ required)

This is a Magisk module that applies a SurfaceFlinger display color saturation value at Android
boot time. The key design goals are:

- Apply saturation **as early as possible** — no arbitrary `sleep` delays; waits on real
  system properties instead.
- **FBE-safe** (Full Disk Encryption): stores the authoritative config in `/data/adb`, which
  is accessible before the user unlocks the device.
- **Recovery-proof**: `/data/adb` is typically available from recovery mode.
- **Syncs with user-facing shared storage** (`/sdcard/saturation.cfg`) after first unlock,
  giving the user a convenient place to change the value.

---

## Repository Structure

```
saturation/
├── META-INF/
│   └── com/google/android/
│       ├── update-binary      # Magisk installation entry point (shell, runs install_module)
│       └── updater-script     # Empty metadata marker required by Magisk
├── module.prop                # Module metadata: id, name, version, author, description
├── customize.sh               # Installer script: config sync, permission setup
├── service.sh                 # Runtime service (late_start): applies saturation at boot
├── uninstall.sh               # Cleanup: removes user-facing config files on uninstall
└── .gitignore                 # Ignores .codex, AGENTS.md, *.zip
```

There is no build system, no package manager, no test runner, and no CI configuration.
All scripts are plain POSIX-compatible shell (`#!/system/bin/sh` or `#!/sbin/sh`).

---

## Key Concepts

### SurfaceFlinger Saturation Call

Saturation is applied via Android's binder service mechanism:

```sh
service call SurfaceFlinger 1022 f <value>
```

- `SF_SERVICE="SurfaceFlinger"` — the target binder service
- `SAT_CODE="1022"` — the transaction code for saturation
- `f <value>` — a float argument

### DE Storage vs. Shared Storage

| Location | Variable | Purpose |
|---|---|---|
| `$MODDIR/saturation.cfg` | `SAT_FILE_DE` | Authoritative config, device-encrypted, available before unlock |
| `$SDROOT/saturation.cfg` | `SAT_FILE_SD` | User-facing copy on shared storage, only readable after unlock |

`SDROOT` is resolved by `resolve_sdroot()`: prefers `$EXTERNAL_STORAGE`, falls back to
`/data/media/0`, then `/sdcard`.

### FBE (Full Disk Encryption) Safety

The authoritative config lives in the module folder under `/data/adb/modules/`. This path is
in the device-encrypted (DE) partition and is available immediately at boot before the user
enters their PIN/password. Shared storage (`/sdcard`) is credential-encrypted (CE) and only
becomes readable after first unlock.

---

## Configuration

**File name:** `saturation.cfg`

**Format:** A single line containing one floating-point number:

```
1.25
```

**Valid range:** `0.50` to `2.00` (inclusive)
**Default:** `1.0` (neutral — no change from Android default)

### Config Locations

1. **Module config (authoritative):** `/data/adb/modules/set_saturation_boot/saturation.cfg`
   — permissions `0600`, owned by root
2. **User-facing copy:** `/sdcard/saturation.cfg` (or `$EXTERNAL_STORAGE/saturation.cfg`)
   — permissions `0644`

To change saturation: edit `/sdcard/saturation.cfg` and reboot, or flash the module again.

---

## Lifecycle and Boot Flow

### 1. Installation — `customize.sh`

Triggered by Magisk when the module ZIP is flashed.

1. Resolves shared storage path via `resolve_sdroot()`.
2. Detects any existing installed module config at `/data/adb/modules/<id>/saturation.cfg`.
3. **Config sync with `/sdcard` priority:**
   - If `/sdcard/saturation.cfg` exists → validates and copies it into the module folder.
   - Otherwise → ensures the module config is valid (restores from old install or writes
     default `1.0`) and exports a copy to `/sdcard`.
4. Sets explicit permissions:
   - `service.sh` → `0755`
   - `module.prop` → `0644`
   - `saturation.cfg` → `0600`

### 2. Boot — `service.sh`

Triggered by Magisk as a `late_start` service after the system boots.

1. `ensure_de_file()` — guarantees a valid DE config exists; writes default `1.0` if not.
2. `wait_surfaceflinger()` — polls `init.svc.surfaceflinger` every 0.1s, up to 30s.
3. `apply_from_file()` — validates DE config and calls `apply_value()` (up to 10 retries,
   0.2s apart).
4. `sync_shared_config_after_boot_window()` — waits for `sys.boot_completed=1` (up to 120s),
   then polls shared storage every 2s for up to 2 minutes to sync any user-updated value
   and re-apply it immediately.

### 3. Uninstall — `uninstall.sh`

Triggered by Magisk when the user removes the module.

- Removes `/sdcard/saturation.cfg` (and legacy/fallback paths).
- The module folder (including the DE config) is automatically deleted by Magisk.

---

## Code Conventions

### Shell Scripting Style

- **Shebang:** `#!/system/bin/sh` for module scripts, `#!/sbin/sh` for the installer entry point.
- **POSIX-only:** No bashisms. All constructs must work on Android's toybox/busybox shell.
- **Local variables:** Shell has no `local` keyword in POSIX mode — functions use short
  prefixed variable names (e.g., `wf_i`, `av_max`, `cfg_path`) to avoid namespace collisions.
- **Return codes:** Functions return `0` for success, `1` for failure. Callers check with
  `if func; then` or `func || fallback`.
- **Atomic writes:** Config files are written via a temp file (`<name>.tmp.$$`) then renamed
  with `mv -f` to avoid partial writes.
- **No fixed delays:** Use property-based polling (`getprop`) instead of `sleep <n>`.
  Short `sleep 0.1` / `sleep 0.2` polling intervals in retry loops are acceptable.

### Intentional Code Duplication

`resolve_sdroot()`, `read_first_line_trim()`, `is_valid_float()`, and `in_range()` are
**deliberately duplicated** across `service.sh`, `customize.sh`, and `uninstall.sh`.

**Reason:** Each script runs in a different lifecycle context. Sourcing a shared helper
file would introduce a dependency that could break if the file is unavailable. The duplication
is intentional and should be preserved.

### Key Constants (defined in both `service.sh` and `customize.sh`)

| Variable | Value | Meaning |
|---|---|---|
| `MIN_SAT` | `0.50` | Minimum allowed saturation |
| `MAX_SAT` | `2.00` | Maximum allowed saturation |
| `DEFAULT_SAT` | `1.0` | Default saturation (neutral) |
| `SF_SERVICE` | `SurfaceFlinger` | Binder service name |
| `SAT_CODE` | `1022` | Binder transaction code for saturation |

---

## Git Conventions

- **Commit message language:** Spanish
- **Commit message format:** `feat: <description in Spanish>`
  - Example: `feat: Mejorar la sincronización de configuración entre el módulo y el almacenamiento compartido`
- **Branch naming:** `claude/<short-description>-<suffix>` for AI-generated branches
- **Main branch:** `main`

When making commits, follow the Spanish `feat:` convention used throughout the project history.

---

## Development Notes

### No Build System

There is no Makefile, npm, Gradle, or any other build tool. The "build output" is a ZIP file
containing the module files. ZIPs are excluded from version control via `.gitignore`.

To package for distribution:
```sh
zip -r set_saturation_boot.zip META-INF module.prop customize.sh service.sh uninstall.sh
```

### No Automated Tests

There is no test suite. Validation logic is inline within each script (`config_is_valid()`,
`is_valid_float()`, `in_range()`). Testing requires a rooted Android device with Magisk.

### Manual Testing Approach

1. Flash the module ZIP via Magisk Manager or recovery.
2. Edit `/sdcard/saturation.cfg` with a value like `1.5`.
3. Reboot and observe display color shift.
4. Check `logcat` or Magisk logs for any error output from `service.sh`.

### Modifying Scripts

- **Saturation range:** Change `MIN_SAT` and `MAX_SAT` in both `service.sh` and `customize.sh`.
- **SurfaceFlinger call:** Change `SAT_CODE` in `service.sh` if the binder transaction code
  differs on a target Android version.
- **Timeouts:** `wait_surfaceflinger` max is 30s (`wf_max=300` at 0.1s each);
  `poll_user_config_sync` max is 2 minutes (`max=60` at 2s each);
  `wait_for_boot_completed` max is 120s.
- **Default value:** Change `DEFAULT_SAT` in both `service.sh` and `customize.sh`.

### `.gitignore` Entries

| Entry | Reason |
|---|---|
| `.codex` | AI assistant working directory |
| `AGENTS.md` | AI assistant instructions (not committed) |
| `*.zip` | Packaged module ZIPs — built artifacts, not source |
