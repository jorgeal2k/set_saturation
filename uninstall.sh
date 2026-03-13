#!/system/bin/sh
# uninstall.sh — cleanup on module removal

CFG_MARKER="set_saturation_boot"
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

owner_marker_path() {
  printf '%s.owner\n' "$1"
}

remove_if_module_owned() {
  cfg_path="$1"
  owner_path="$(owner_marker_path "$cfg_path")"

  if [ ! -f "$cfg_path" ]; then
    rm -f "$owner_path"
    return 0
  fi

  if [ -f "$owner_path" ] && grep -Fxq "$CFG_MARKER" "$owner_path" 2>/dev/null; then
    rm -f "$cfg_path" "$owner_path"
  fi
}

remove_user_configs() {
  sdroot="$(resolve_sdroot)"
  resolved_cfg="$sdroot/saturation.cfg"

  remove_if_module_owned "$resolved_cfg"
  remove_if_module_owned "$LEGACY_SD_CFG"
  remove_if_module_owned "$FALLBACK_SD_CFG"
}

# Remove user-facing config only if it was created by this module
remove_user_configs

# Note: $MODDIR/saturation.cfg is automatically removed by Magisk
# when it deletes the module directory.
