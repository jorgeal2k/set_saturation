#!/system/bin/sh
# customize.sh — Magisk module installer script

ui_print " "
ui_print "========================================"
ui_print " Set Saturation after System boot"
ui_print "========================================"
ui_print " "

# Shared storage resolution is duplicated on purpose across lifecycle scripts
# to avoid introducing a new sourced dependency into the installer path.
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

read_first_line_trim() {
  head -n 1 "$1" 2>/dev/null | tr -d '[:space:]'
}

is_valid_float() {
  printf '%s\n' "$1" | grep -Eq '^[0-9]+(\.[0-9]+)?$'
}

in_range() {
  awk -v x="$1" -v min="$MIN_SAT" -v max="$MAX_SAT" 'BEGIN{ exit !(x>=min && x<=max) }'
}

config_is_valid() {
  cfg_path="$1"
  [ -s "$cfg_path" ] || return 1
  [ -r "$cfg_path" ] || return 1

  cfg_value="$(read_first_line_trim "$cfg_path")"
  [ -n "$cfg_value" ] || return 1
  is_valid_float "$cfg_value" || return 1
  in_range "$cfg_value" || return 1
  return 0
}

report_config_state() {
  cfg_label="$1"
  cfg_path="$2"

  [ -f "$cfg_path" ] || return 1

  if config_is_valid "$cfg_path"; then
    ui_print "- Found $cfg_label config: $cfg_path"
    return 0
  fi

  ui_print "! Found invalid $cfg_label config: $cfg_path"
  return 1
}

SAT_FILE_DE="$MODPATH/saturation.cfg"
DEFAULT_SAT="1.0"
MIN_SAT="0.50"
MAX_SAT="2.00"
MODULE_PROP="$MODPATH/module.prop"
SDROOT="$(resolve_sdroot)"
SAT_FILE_SD="$SDROOT/saturation.cfg"
OLD_SAT_FILE=""
MODID="$(get_module_id)"

if [ -n "$MODID" ]; then
  OLD_SAT_FILE="/data/adb/modules/$MODID/saturation.cfg"
fi

write_default_de_config() {
  wdd_tmp="${SAT_FILE_DE}.tmp.$$"
  wdd_old_umask="$(umask)"

  umask 0177
  if ! printf '%s\n' "$DEFAULT_SAT" > "$wdd_tmp"; then
    umask "$wdd_old_umask"
    rm -f "$wdd_tmp" 2>/dev/null
    ui_print "! Failed to write DE config: $SAT_FILE_DE"
    return 1
  fi
  umask "$wdd_old_umask"

  if ! mv -f "$wdd_tmp" "$SAT_FILE_DE" 2>/dev/null; then
    rm -f "$wdd_tmp" 2>/dev/null
    ui_print "! Failed to write DE config: $SAT_FILE_DE"
    return 1
  fi

  set_perm "$SAT_FILE_DE" 0 0 0600
  return 0
}

copy_to_module_config() {
  src="$1"

  if ! config_is_valid "$src"; then
    ui_print "! Ignoring invalid config: $src"
    return 1
  fi

  cp_tmp="${SAT_FILE_DE}.tmp.$$"
  if cp -f "$src" "$cp_tmp" && chmod 0600 "$cp_tmp" 2>/dev/null && mv -f "$cp_tmp" "$SAT_FILE_DE" 2>/dev/null; then
    set_perm "$SAT_FILE_DE" 0 0 0600
    return 0
  fi

  rm -f "$cp_tmp" 2>/dev/null
  ui_print "! Failed to update module config from: $src"
  return 1
}

copy_to_shared_config() {
  src="$1"

  if ! config_is_valid "$src"; then
    ui_print "! Not exporting invalid config: $src"
    return 1
  fi

  if [ ! -d "$SDROOT" ] || [ ! -w "$SDROOT" ]; then
    ui_print "- Shared storage not writable during install; keeping module config only."
    return 1
  fi

  cp_sd_tmp="${SAT_FILE_SD}.tmp.$$"
  if cp -f "$src" "$cp_sd_tmp" && mv -f "$cp_sd_tmp" "$SAT_FILE_SD" 2>/dev/null; then
    chmod 0644 "$SAT_FILE_SD" 2>/dev/null || ui_print "! Failed to chmod: $SAT_FILE_SD"
    return 0
  fi

  rm -f "$cp_sd_tmp" 2>/dev/null
  ui_print "! Failed to update shared config: $SAT_FILE_SD"
  return 1
}

ensure_valid_module_config() {
  if [ -f "$SAT_FILE_DE" ] && config_is_valid "$SAT_FILE_DE"; then
    return 0
  fi

  if [ -f "$SAT_FILE_DE" ]; then
    ui_print "! Ignoring invalid module config: $SAT_FILE_DE"
  fi

  if [ -n "$OLD_SAT_FILE" ] && [ -f "$OLD_SAT_FILE" ] && config_is_valid "$OLD_SAT_FILE"; then
    ui_print "- Restoring installed module config: $OLD_SAT_FILE"
    copy_to_module_config "$OLD_SAT_FILE" || write_default_de_config
    return 0
  fi

  if [ -n "$OLD_SAT_FILE" ] && [ -f "$OLD_SAT_FILE" ]; then
    ui_print "! Ignoring invalid installed module config: $OLD_SAT_FILE"
  fi

  ui_print "- Creating module config (default $DEFAULT_SAT)"
  write_default_de_config
}

# Keep permissions explicit for the files that Magisk executes or reads directly.
set_installed_permissions() {
  ui_print "- Setting script permissions..."
  set_perm "$MODPATH/service.sh" 0 0 0755
  set_perm "$MODPATH/module.prop" 0 0 0644
}

set_installed_permissions

# Sync configs with shared storage priority when both files exist
if [ -f "$SAT_FILE_SD" ]; then
  if report_config_state "module" "$SAT_FILE_DE" || report_config_state "installed module" "$OLD_SAT_FILE"; then
    ui_print "- Found shared config (priority): $SAT_FILE_SD"
  else
    ui_print "- Found shared config: $SAT_FILE_SD"
  fi

  if ! copy_to_module_config "$SAT_FILE_SD"; then
    ensure_valid_module_config
  fi
else
  report_config_state "module" "$SAT_FILE_DE" || report_config_state "installed module" "$OLD_SAT_FILE" || :

  if ensure_valid_module_config; then
    ui_print "- Copying module config to shared storage: $SAT_FILE_SD"
    copy_to_shared_config "$SAT_FILE_DE"
  fi
fi

ui_print " "
ui_print "- Install steps completed."
ui_print "  Reboot to apply."
ui_print " "
