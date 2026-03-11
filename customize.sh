#!/system/bin/sh
# customize.sh — Magisk module installer script

ui_print " "
ui_print "========================================"
ui_print " Set Saturation after System boot"
ui_print "========================================"
ui_print " "

resolve_sdroot() {
  if [ -n "$EXTERNAL_STORAGE" ] && [ -d "$EXTERNAL_STORAGE" ]; then
    printf '%s\n' "$EXTERNAL_STORAGE"
  elif [ -d "/data/media/0" ]; then
    printf '%s\n' "/data/media/0"
  else
    printf '%s\n' "/sdcard"
  fi
}

get_module_id() {
  [ -f "$MODULE_PROP" ] || return 1
  sed -n 's/^id=//p' "$MODULE_PROP" | head -n 1
}

SAT_FILE_DE="$MODPATH/saturation.cfg"
DEFAULT_SAT="1.0"
CFG_MARKER="# set_saturation_boot"
MODULE_PROP="$MODPATH/module.prop"
SDROOT="$(resolve_sdroot)"
SAT_FILE_SD="$SDROOT/saturation.cfg"
MODID=""
OLD_SAT_FILE=""

MODID="$(get_module_id)"

if [ -n "$MODID" ]; then
  OLD_SAT_FILE="/data/adb/modules/$MODID/saturation.cfg"
fi

write_default_de_config() {
  if printf '%s\n' "$DEFAULT_SAT" > "$SAT_FILE_DE"; then
    set_perm "$SAT_FILE_DE" 0 0 0600
    return 0
  fi

  ui_print "! Failed to write DE config: $SAT_FILE_DE"
  return 1
}

set_installed_permissions() {
  ui_print "- Setting script permissions..."
  set_perm "$MODPATH/service.sh" 0 0 0755
  set_perm "$MODPATH/module.prop" 0 0 0644
}

set_installed_permissions

# Create DE config (recovery-proof + works before first unlock)
if [ -n "$OLD_SAT_FILE" ] && [ -s "$OLD_SAT_FILE" ]; then
  ui_print "- Found DE config (preserving): $OLD_SAT_FILE"
  if cp -f "$OLD_SAT_FILE" "$SAT_FILE_DE"; then
    set_perm "$SAT_FILE_DE" 0 0 0600
  else
    ui_print "! Failed to preserve old config; creating default."
    write_default_de_config
  fi
else
  ui_print "- Creating DE config (default $DEFAULT_SAT)"
  write_default_de_config
fi

# Create user-facing config on shared storage if possible (best-effort)
if [ -f "$SAT_FILE_SD" ]; then
  ui_print "- Found existing saturation.cfg (leaving as-is): $SAT_FILE_SD"
else
  if [ -d "$SDROOT" ] && [ -w "$SDROOT" ]; then
    ui_print "- Creating user config: $SAT_FILE_SD (default $DEFAULT_SAT)"
    if {
      echo "$DEFAULT_SAT"
      echo "$CFG_MARKER"
    } > "$SAT_FILE_SD"; then
      chmod 0644 "$SAT_FILE_SD" 2>/dev/null || ui_print "! Failed to chmod: $SAT_FILE_SD"
    else
      ui_print "! Failed to create user config: $SAT_FILE_SD"
    fi
  else
    ui_print "- Shared storage not writable during install; DE config will be used."
  fi
fi

ui_print " "
ui_print "- Install steps completed."
ui_print "  Reboot to apply."
ui_print " "
