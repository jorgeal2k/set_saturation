#!/system/bin/sh
# uninstall.sh — cleanup on module removal

LEGACY_SD_CFG="/data/media/0/saturation.cfg"
FALLBACK_SD_CFG="/sdcard/saturation.cfg"

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
  cfg_path="$1"
  [ -n "$cfg_path" ] || return 1
  [ ! -L "$cfg_path" ] || return 1
  [ -f "$cfg_path" ] || return 0
  rm -f "$cfg_path"
}

remove_user_configs() {
  sdroot="$(resolve_sdroot)"
  resolved_cfg="$sdroot/saturation.cfg"

  # Remove resolved path first; skip legacy/fallback if they resolve to the same file.
  remove_user_config "$resolved_cfg"
  [ "$resolved_cfg" = "$LEGACY_SD_CFG" ]   || remove_user_config "$LEGACY_SD_CFG"
  [ "$resolved_cfg" = "$FALLBACK_SD_CFG" ] || remove_user_config "$FALLBACK_SD_CFG"
}

# Remove user-facing config copies.
remove_user_configs

# Note: $MODDIR/saturation.cfg is automatically removed by Magisk
# when it deletes the module directory.
