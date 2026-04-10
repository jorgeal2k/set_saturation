# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

`set_saturation` is a Magisk/KernelSU module that applies SurfaceFlinger color saturation at boot via a binder service call (`service call SurfaceFlinger 1022 f <value>`). It maintains two copies of the config: a DE (device-encrypted) copy in the module directory (`$MODDIR/saturation.cfg`, root-only, available before first unlock) and a user-facing copy on shared storage (`/sdcard/saturation.cfg`, readable by the user).

Saturation value is a float in the range `[0.50, 2.00]`. Default is `1.0`.

## Script lifecycle

| Script | Phase | Notes |
|---|---|---|
| `customize.sh` | Installation (TWRP/Magisk) | Syncs configs; shared storage has priority |
| `service.sh` | Late-start boot | Applies saturation early, then polls for SD sync |
| `uninstall.sh` | Module removal | Cleans up shared storage copies |

`META-INF/com/google/android/update-binary` bootstraps Magisk's `install_module`; `updater-script` contains only `#MAGISK`.

## Key design decisions

- **`resolve_sdroot()` is intentionally duplicated** across all three scripts — no shared helper is sourced, to avoid coupling between installer, boot, and uninstall paths.
- **Two-file config strategy**: DE config (`$MODDIR/saturation.cfg`) is applied at boot before unlock. SD config is synced post-boot and overwrites the DE copy for future boots.
- **No fixed `sleep` delays** for SurfaceFlinger readiness — `service.sh` polls `getprop init.svc.surfaceflinger` up to 30 s, then retries the service call up to 5 times.
- **SD sync is non-blocking**: saturation is applied from DE config first; SD sync happens in background after `sys.boot_completed=1` (with 2-minute fallback window).

## Shell scripting constraints

This runs under toybox/toolbox on Android, not GNU. Follow POSIX strictly:
- No bash-isms: no arrays, no `[[ ]]`, no `$'...'`, no `local`
- Always quote variables: `"$var"`
- Use `printf '%s\n'` instead of `echo` for values that may contain special chars
- `awk` is available (toybox); use it for float comparisons
- `grep -E` for regex; `sed` for line extraction
- `set_perm` is a Magisk helper (only available in `customize.sh`)
- Atomic file writes: write to `.tmp.$$`, chmod, then `mv -f` into place

## Config validation

All three scripts share the same validation logic (duplicated by design):
- `is_valid_float`: `^[0-9]+(\.[0-9]+)?$` — no negatives, no exponents
- `in_range`: awk check against `MIN_SAT=0.50` / `MAX_SAT=2.00`
- Any invalid or empty config falls back to `DEFAULT_SAT=1.0`

## Audit checklist (from AGENTS.md)

When reviewing changes, always check:
- Unquoted variables
- Unsafe use of `rm`/`cp`/`mv`/`chmod`/`chown`
- Race conditions or boot-timing assumptions
- Access to shared storage that may not be mounted yet
- Paths that could be empty strings before destructive operations

Group proposed changes as: **must fix now** / **recommended hardening** / **optional improvements**.
