#!/system/bin/sh
# Magisk service script (late_start service)
# Applies SurfaceFlinger color saturation from a DE (device-encrypted) config file.
#
# Goals:
# - Apply saturation ASAP (no arbitrary delays like "sleep 2")
# - Work before first unlock (FBE-safe) by using /data/adb
# - Be "recovery-proof": config lives in /data/adb, which is typically available in recovery

MODDIR="${0%/*}"

# Shared storage resolution is duplicated on purpose across lifecycle scripts
# to avoid coupling boot logic to an extra sourced helper.
resolve_sdroot() {
  if [ -n "$EXTERNAL_STORAGE" ] && [ -d "$EXTERNAL_STORAGE" ]; then
    printf '%s\n' "$EXTERNAL_STORAGE"
  elif [ -d "/data/media/0" ]; then
    printf '%s\n' "/data/media/0"
  else
    printf '%s\n' "/sdcard"
  fi
}

# --- Paths ---
# Root-only, recovery-friendly, FBE-safe config (authoritative)
SAT_FILE_DE="$MODDIR/saturation.cfg"

# Optional user-facing config (may be unavailable until first unlock on FBE devices)
SDROOT="$(resolve_sdroot)"
SAT_FILE_SD="$SDROOT/saturation.cfg"

# --- SurfaceFlinger saturation service call ---
SF_SERVICE="SurfaceFlinger"
SAT_CODE="1022"

# --- Safety bounds ---
# Keep these conservative to avoid extreme color distortion
MIN_SAT="0.50"
MAX_SAT="2.00"
DEFAULT_SAT="1.0"

# --- Helpers ---
is_valid_float() {
  # Accepts: 1, 1.0, 0.75, 2.00 (no negatives, no exponent)
  echo "$1" | grep -Eq '^[0-9]+(\.[0-9]+)?$'
}

in_range() {
  # awk is commonly available (toybox/box). Exit 0 if in range.
  awk -v x="$1" -v min="$MIN_SAT" -v max="$MAX_SAT" 'BEGIN{ exit !(x>=min && x<=max) }'
}

read_first_line_trim() {
  # Read first line, strip whitespace
  head -n 1 "$1" 2>/dev/null | tr -d '[:space:]'
}

write_de_value() {
  wd_value="$1"
  wd_tmp="${SAT_FILE_DE}.tmp.$$"

  if ! printf '%s\n' "$wd_value" > "$wd_tmp"; then
    rm -f "$wd_tmp" 2>/dev/null
    return 1
  fi

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
  # Wait until SurfaceFlinger is running.
  # No fixed delay; we just wait for readiness.
  wf_i=0
  wf_max=300  # 300 * 0.1s = 30s max

  while [ "$wf_i" -lt "$wf_max" ]; do
    if [ "$(getprop init.svc.surfaceflinger)" = "running" ]; then
      return 0
    fi
    sleep 0.1
    wf_i=$((wf_i+1))
  done
  return 1
}

apply_value() {
  # Apply saturation via binder service call
  # Returns 0 on success
  av_i=0
  av_max=10

  while [ "$av_i" -lt "$av_max" ]; do
    if service call "$SF_SERVICE" "$SAT_CODE" f "$1" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
    av_i=$((av_i+1))
  done

  return 1
}

apply_from_file() {
  # Validate and apply saturation from a file
  af_file="$1"
  [ -s "$af_file" ] || return 1

  af_val="$(read_first_line_trim "$af_file")"
  [ -n "$af_val" ] || return 1

  is_valid_float "$af_val" || return 1
  in_range "$af_val" || return 1

  apply_value "$af_val" || return 1
  return 0
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

  write_de_value "$sd_v" || return 1
  return 0
}

wait_for_boot_completed() {
  i=0
  max_wait_boot=120

  while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt "$max_wait_boot" ]; do
    sleep 1
    i=$((i+1))
  done

  if [ "$i" -lt "$max_wait_boot" ]; then
    return 0
  fi

  return 1
}

poll_user_config_sync() {
  i=0
  max=60  # 60 * 2s = 2 minutes

  while [ "$i" -lt "$max" ]; do
    if sync_sd_to_de_if_possible; then
      # If we successfully synced, also apply the new value immediately (no extra delays).
      apply_from_file "$SAT_FILE_DE" >/dev/null 2>&1
      return 0
    fi
    sleep 2
    i=$((i+1))
  done

  return 1
}

sync_shared_config_after_boot_window() {
  # Prefer boot_completed when the ROM reports it, but still keep the sync attempt
  # for the same bounded window on devices where that property is unreliable.
  wait_for_boot_completed || :

  poll_user_config_sync
}

# --- Main ---
ensure_de_file

# Wait until SurfaceFlinger is actually running, then apply immediately.
if wait_surfaceflinger; then
  apply_from_file "$SAT_FILE_DE" >/dev/null 2>&1
fi

# Try to sync from shared storage ASAP (some devices allow it early),
# otherwise keep checking for a while until it becomes readable post-unlock.
# This does NOT block applying early saturation, it only improves future boots.
# Wait for boot to complete before polling when possible.
# Timeout avoids waiting forever on ROMs that never report boot_completed=1.
sync_shared_config_after_boot_window

exit 0
