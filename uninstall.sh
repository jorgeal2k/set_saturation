#!/system/bin/sh
# uninstall.sh — cleanup on module removal

CFG_MARKER="# set_saturation_boot"

remove_if_module_owned() {
  cfg_path="$1"
  [ -f "$cfg_path" ] || return 0

  if grep -Fq "$CFG_MARKER" "$cfg_path" 2>/dev/null; then
    rm -f "$cfg_path"
  fi
}

# Remove user-facing config only if it was created by this module
remove_if_module_owned /data/media/0/saturation.cfg
remove_if_module_owned /sdcard/saturation.cfg

# Note: $MODDIR/saturation.cfg is automatically removed by Magisk
# when it deletes the module directory.
