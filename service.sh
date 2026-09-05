#!/system/bin/sh
# shellcheck shell=sh

# Magisk service script (late_start service)
# Applies SurfaceFlinger color saturation from a DE (device-encrypted) config file.
#
# Goals:
# - Apply saturation ASAP (no unconditional delays; polls for readiness)
# - Work before first unlock (FBE-safe) by using /data/adb

MODDIR="${0%/*}"
case "$MODDIR" in
  /*) ;;
  *) MODDIR="/data/adb/modules/set_saturation_boot" ;;
esac

# Inline log helper: must stay here so we can report a failed common.sh load
# without depending on common.sh itself.
log_error() {
  _log="$MODDIR/error.log"
  _lines="$(wc -l < "$_log" 2>/dev/null)"
  [ $(( _lines + 0 )) -gt 100 ] && printf '' > "$_log"
  printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" >> "$_log"
}

# Load shared helpers (constants and validators). Abort cleanly if missing.
# shellcheck source=common.sh
if ! . "$MODDIR/common.sh" 2>/dev/null; then
  log_error "common.sh missing or unloadable; aborting service"
  exit 0
fi

# --- Paths ---
# DE config: root-only, FBE-safe, authoritative
SAT_FILE_DE="$MODDIR/saturation.cfg"

# Claim marker for the post-boot stage (see claim_post_boot)
POSTBOOT_LOCK="$MODDIR/.postboot.lock"

# Optional user-facing config (may be unavailable until first unlock on FBE devices)
SDROOT="$(resolve_sdroot)"
SAT_FILE_SD="$SDROOT/saturation.cfg"

# --- SurfaceFlinger saturation service call ---
SF_SERVICE="SurfaceFlinger"
SAT_CODE="1022"

write_de_value() {
  # Atomic write: write to tmp, chmod 0600, mv into place.
  wd_value="$1"
  wd_tmp="${SAT_FILE_DE}.tmp.$$"
  wd_old_umask="$(umask)"

  umask 0177
  if ! printf '%s\n' "$wd_value" > "$wd_tmp"; then
    umask "$wd_old_umask"
    rm -f "$wd_tmp" 2>/dev/null
    return 1
  fi
  umask "$wd_old_umask"

  if ! chmod 0600 "$wd_tmp" 2>/dev/null; then
    rm -f "$wd_tmp" 2>/dev/null
    return 1
  fi

  if ! mv -f "$wd_tmp" "$SAT_FILE_DE" 2>/dev/null; then
    rm -f "$wd_tmp" 2>/dev/null
    return 1
  fi

  return 0
}

ensure_de_file() {
  # Ensure DE config exists and contains a valid value so we can apply early even before unlock.
  if [ ! -s "$SAT_FILE_DE" ]; then
    write_de_value "$DEFAULT_SAT"
    return 0
  fi

  edf_val="$(read_first_line_trim "$SAT_FILE_DE")"
  if [ -z "$edf_val" ] || ! is_valid_float "$edf_val" || ! in_range "$edf_val"; then
    write_de_value "$DEFAULT_SAT"
  fi
}

wait_surfaceflinger() {
  # Poll init.svc.surfaceflinger up to 30 s (1 s intervals).
  wf_i=0
  wf_max=30  # 30 * 1s = 30s max

  while [ "$wf_i" -lt "$wf_max" ]; do
    if [ "$(getprop init.svc.surfaceflinger)" = "running" ]; then
      return 0
    fi
    sleep 1
    wf_i=$((wf_i+1))
  done
  return 1
}

apply_value() {
  # Binder service call; retries up to 5 times on failure.
  av_i=0
  av_max=5  # 5 * 1s = 5s max

  while [ "$av_i" -lt "$av_max" ]; do
    if service call "$SF_SERVICE" "$SAT_CODE" f "$1" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    av_i=$((av_i+1))
  done

  return 1
}

apply_from_file() {
  af_file="$1"
  [ -s "$af_file" ] || return 1

  af_val="$(read_first_line_trim "$af_file")"
  [ -n "$af_val" ] || return 1

  is_valid_float "$af_val" || return 1
  in_range "$af_val" || return 1

  apply_value "$af_val"
}

sync_sd_to_de_if_possible() {
  # If user config on shared storage exists (after unlock on FBE),
  # validate it and copy it into the DE config so next boot applies early.
  [ -r "$SAT_FILE_SD" ] || return 1
  [ -s "$SAT_FILE_SD" ] || return 1

  sd_v="$(read_first_line_trim "$SAT_FILE_SD")"
  [ -n "$sd_v" ] || return 1
  is_valid_float "$sd_v" || return 1
  in_range "$sd_v" || return 1

  write_de_value "$sd_v"
}

wait_for_boot_completed() {
  # Poll sys.boot_completed up to 60 s; returns 1 on timeout.
  wfbc_i=0
  wfbc_max=60

  while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$wfbc_i" -lt "$wfbc_max" ]; do
    sleep 1
    wfbc_i=$((wfbc_i+1))
  done

  if [ "$wfbc_i" -lt "$wfbc_max" ]; then
    return 0
  fi

  return 1
}

poll_user_config_sync() {
  # Poll for a readable SD config up to 2 min; re-applies only if value changed.
  pcs_i=0
  pcs_max=60  # 60 * 2s = 2 minutes

  while [ "$pcs_i" -lt "$pcs_max" ]; do
    old_de="$(read_first_line_trim "$SAT_FILE_DE" 2>/dev/null)"
    if sync_sd_to_de_if_possible; then
      new_de="$(read_first_line_trim "$SAT_FILE_DE" 2>/dev/null)"
      # Only re-apply if the value actually changed to avoid unnecessary binder calls.
      if [ "$new_de" != "$old_de" ]; then
        apply_from_file "$SAT_FILE_DE" >/dev/null 2>&1
      fi
      return 0
    fi
    sleep 2
    pcs_i=$((pcs_i+1))
  done

  return 1
}

reapply_after_boot() {
  # SurfaceFlinger may reset its color matrix during init; re-apply once boot is stable.
  apply_from_file "$SAT_FILE_DE" >/dev/null 2>&1
}

claim_post_boot() {
  # Atomic claim so the post-boot work runs exactly once per boot, whether it
  # is reached through boot-completed.sh (KernelSU) or through the service.sh
  # fallback (Magisk). mkdir either creates the directory or fails, atomically,
  # so exactly one caller can win.
  mkdir "$POSTBOOT_LOCK" 2>/dev/null
}

run_post_boot() {
  # Post-boot work: re-apply saturation, then try to sync the user config.
  # Re-apply unconditionally: SurfaceFlinger may have reset its color matrix
  # during its own initialization after we applied early.
  reapply_after_boot

  poll_user_config_sync
}

# --- Main ---

# Post-boot entry point, used by boot-completed.sh on root managers that
# provide that stage. The early-boot work below has already run by then.
if [ "$1" = "post-boot" ]; then
  claim_post_boot || exit 0
  # Re-validate: normally service.sh already did this at late_start, but the
  # post-boot stage must not depend on that having succeeded.
  ensure_de_file
  run_post_boot
  exit 0
fi

# Drop a claim left behind by the previous boot. As a late_start service this
# always runs before sys.boot_completed, so it cannot race boot-completed.sh.
rmdir "$POSTBOOT_LOCK" 2>/dev/null
# Defensive: if anything left a non-directory in its place, mkdir would keep
# failing and the post-boot stage would never run again. Fixed path, no glob.
[ -e "$POSTBOOT_LOCK" ] && rm -f "$POSTBOOT_LOCK" 2>/dev/null

ensure_de_file

# Wait until SurfaceFlinger is actually running, then apply immediately.
if wait_surfaceflinger; then
  apply_from_file "$SAT_FILE_DE" >/dev/null 2>&1 \
    || log_error "saturation: apply failed at boot"
fi

# Fallback post-boot path for managers without a boot-completed stage (Magisk).
# On KernelSU boot-completed.sh usually claims first and this exits right away.
wait_for_boot_completed || :  # continue even if boot_completed never fires

if claim_post_boot; then
  run_post_boot
fi

exit 0
