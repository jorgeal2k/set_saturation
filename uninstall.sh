#!/system/bin/sh
# shellcheck shell=sh

# uninstall.sh — cleanup on module removal

LEGACY_SD_CFG="/data/media/0/saturation.cfg"
FALLBACK_SD_CFG="/sdcard/saturation.cfg"
OWNER_MARKER_NAME=".set_saturation_boot.saturation.cfg.created"
LEGACY_SD_MARKER="/data/media/0/$OWNER_MARKER_NAME"
FALLBACK_SD_MARKER="/sdcard/$OWNER_MARKER_NAME"

# Shared storage resolution is duplicated on purpose across lifecycle scripts
# to avoid introducing a new sourced dependency into uninstall.
resolve_sdroot() {
  if [ -n "$EXTERNAL_STORAGE" ] && [ -d "$EXTERNAL_STORAGE" ]; then
    printf '%s\n' "$EXTERNAL_STORAGE"
  elif [ -d "/data/media/0" ]; then
    printf '%s\n' "/data/media/0"
  else
    printf '%s\n' "/sdcard"
  fi
}

remove_user_config() {
  # Removes only configs explicitly marked as module-created; skips symlinks.
  cfg_path="$1"
  marker_path="$2"

  [ -n "$cfg_path" ] || return 1
  [ -n "$marker_path" ] || return 1
  [ ! -L "$cfg_path" ] || return 1
  [ ! -L "$marker_path" ] || return 1
  [ -f "$cfg_path" ] || return 0
  [ -f "$marker_path" ] || return 0

  if rm -f "$cfg_path"; then
    rm -f "$marker_path" 2>/dev/null
  fi
}

remove_user_configs() {
  # Removes only marked SD config copies; preserves user-created configs.
  sdroot="$(resolve_sdroot)"
  resolved_cfg="$sdroot/saturation.cfg"
  resolved_marker="$sdroot/$OWNER_MARKER_NAME"

  # Remove resolved path first; skip legacy/fallback if they resolve to the same path.
  remove_user_config "$resolved_cfg" "$resolved_marker"
  [ "$resolved_cfg" = "$LEGACY_SD_CFG" ]   || remove_user_config "$LEGACY_SD_CFG" "$LEGACY_SD_MARKER"
  [ "$resolved_cfg" = "$FALLBACK_SD_CFG" ] || remove_user_config "$FALLBACK_SD_CFG" "$FALLBACK_SD_MARKER"
}

# Remove only module-owned user-facing config copies.
remove_user_configs

# Note: $MODDIR/saturation.cfg is automatically removed by Magisk
# when it deletes the module directory.
