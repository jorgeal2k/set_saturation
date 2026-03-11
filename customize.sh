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

copy_to_module_config() {
  src="$1"

  if cp -f "$src" "$SAT_FILE_DE"; then
    set_perm "$SAT_FILE_DE" 0 0 0600
    return 0
  fi

  ui_print "! Failed to update module config from: $src"
  return 1
}

copy_to_shared_config() {
  src="$1"

  if [ ! -d "$SDROOT" ] || [ ! -w "$SDROOT" ]; then
    ui_print "- Shared storage not writable during install; keeping module config only."
    return 1
  fi

  if cp -f "$src" "$SAT_FILE_SD"; then
    chmod 0644 "$SAT_FILE_SD" 2>/dev/null || ui_print "! Failed to chmod: $SAT_FILE_SD"
    return 0
  fi

  ui_print "! Failed to update shared config: $SAT_FILE_SD"
  return 1
}

set_installed_permissions() {
  ui_print "- Setting script permissions..."
  set_perm "$MODPATH/service.sh" 0 0 0755
  set_perm "$MODPATH/module.prop" 0 0 0644
}

set_installed_permissions

# Sync configs with shared storage priority when both files exist
if [ -f "$SAT_FILE_SD" ]; then
  if [ -f "$SAT_FILE_DE" ]; then
    ui_print "- Found module config: $SAT_FILE_DE"
    ui_print "- Found shared config (priority): $SAT_FILE_SD"
  elif [ -n "$OLD_SAT_FILE" ] && [ -f "$OLD_SAT_FILE" ]; then
    ui_print "- Found installed module config: $OLD_SAT_FILE"
    ui_print "- Found shared config (priority): $SAT_FILE_SD"
  else
    ui_print "- Found shared config: $SAT_FILE_SD"
  fi

  if ! copy_to_module_config "$SAT_FILE_SD"; then
    if [ -f "$SAT_FILE_DE" ]; then
      ui_print "- Keeping existing module config: $SAT_FILE_DE"
    elif [ -n "$OLD_SAT_FILE" ] && [ -f "$OLD_SAT_FILE" ]; then
      ui_print "- Restoring installed module config: $OLD_SAT_FILE"
      copy_to_module_config "$OLD_SAT_FILE" || write_default_de_config
    else
      ui_print "- Creating module config (default $DEFAULT_SAT)"
      write_default_de_config
    fi
  fi
elif [ -f "$SAT_FILE_DE" ]; then
  ui_print "- Found module config: $SAT_FILE_DE"
  ui_print "- Copying module config to shared storage: $SAT_FILE_SD"
  copy_to_shared_config "$SAT_FILE_DE"
elif [ -n "$OLD_SAT_FILE" ] && [ -f "$OLD_SAT_FILE" ]; then
  ui_print "- Found installed module config: $OLD_SAT_FILE"
  if copy_to_module_config "$OLD_SAT_FILE"; then
    ui_print "- Copying module config to shared storage: $SAT_FILE_SD"
    copy_to_shared_config "$SAT_FILE_DE"
  else
    ui_print "- Creating module config (default $DEFAULT_SAT)"
    if write_default_de_config; then
      ui_print "- Copying module config to shared storage: $SAT_FILE_SD"
      copy_to_shared_config "$SAT_FILE_DE"
    fi
  fi
else
  ui_print "- Creating module config (default $DEFAULT_SAT)"
  if write_default_de_config; then
    ui_print "- Copying module config to shared storage: $SAT_FILE_SD"
    copy_to_shared_config "$SAT_FILE_DE"
  fi
fi

ui_print " "
ui_print "- Install steps completed."
ui_print "  Reboot to apply."
ui_print " "
