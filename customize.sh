#!/system/bin/sh
# shellcheck shell=sh

# customize.sh — Magisk module installer script

ui_print " "
ui_print "========================================"
ui_print " Set Saturation after System boot"
ui_print "========================================"
ui_print " "

get_module_id() {
  # Reads the module ID from $MODULE_PROP; must be called after MODULE_PROP is set.
  [ -f "$MODULE_PROP" ] || return 1
  sed -n 's/^id=//p' "$MODULE_PROP" | head -n 1
}

config_is_valid() {
  # Returns 0 if file exists, is readable, and contains a valid in-range float.
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
  # Prints config state to installer output; returns 0 only if valid.
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

# Paths
SAT_FILE_DE="$MODPATH/saturation.cfg"
MODULE_PROP="$MODPATH/module.prop"
OLD_SAT_FILE=""
MODID="$(get_module_id)"

# Load shared helpers (constants and validators). Abort cleanly if missing or unloadable.
# shellcheck source=common.sh
if ! . "$MODPATH/common.sh" 2>/dev/null; then
  ui_print "! Failed to load common.sh"
  abort   "! Aborting install"
fi

SDROOT="$(resolve_sdroot)"
SAT_FILE_SD="$SDROOT/saturation.cfg"

if [ -n "$MODID" ]; then
  OLD_SAT_FILE="/data/adb/modules/$MODID/saturation.cfg"
fi

write_default_de_config() {
  # Writes DEFAULT_SAT to DE config atomically (tmp → mv + set_perm).
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
  # Validates src, then copies it atomically into DE config.
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
  # Validates src, then copies it to shared storage (best-effort).
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
    # When writing directly to /data/media (bypassing FUSE/MediaProvider), the
    # file must belong to media_rw (1023) or user apps may not see or edit it.
    case "$SDROOT" in
      /data/media/*)
        chown 1023:1023 "$SAT_FILE_SD" 2>/dev/null || ui_print "! Failed to chown: $SAT_FILE_SD"
        ;;
    esac
    return 0
  fi

  rm -f "$cp_sd_tmp" 2>/dev/null
  ui_print "! Failed to update shared config: $SAT_FILE_SD"
  return 1
}

ensure_valid_module_config() {
  # Guarantees a valid DE config exists; priority: new > old installed > default.
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

# Keep permissions explicit for the files that the root manager executes or
# reads directly. boot-completed.sh is only run by managers that provide that
# stage (KernelSU and forks); Magisk ignores it, but it still needs to be
# executable because service.sh is exec'd from it.
set_installed_permissions() {
  ui_print "- Setting script permissions..."
  set_perm "$MODPATH/customize.sh" 0 0 0755
  set_perm "$MODPATH/service.sh" 0 0 0755
  set_perm "$MODPATH/boot-completed.sh" 0 0 0755
  set_perm "$MODPATH/module.prop" 0 0 0644
  set_perm "$MODPATH/common.sh" 0 0 0644
}

set_installed_permissions

# SD config present: use it as source of truth. Otherwise bootstrap from module config.
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
