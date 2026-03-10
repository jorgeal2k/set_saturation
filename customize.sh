#!/system/bin/sh
# customize.sh — Magisk module installer script

ui_print " "
ui_print "========================================"
ui_print " Set Saturation after System boot"
ui_print "========================================"
ui_print " "

SDROOT="/data/media/0"
[ -d "$SDROOT" ] || SDROOT="/sdcard"
SAT_FILE_SD="$SDROOT/saturation.cfg"

SAT_FILE_DE="$MODPATH/saturation.cfg"
OLD_SAT_FILE="/data/adb/modules/set_saturation_boot/saturation.cfg"
DEFAULT_SAT="1.0"
CFG_MARKER="# set_saturation_boot"

ui_print "- Setting script permissions..."
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/module.prop" 0 0 0644

# Create DE config (recovery-proof + works before first unlock)
if [ -s "$OLD_SAT_FILE" ]; then
  ui_print "- Found DE config (preserving): $OLD_SAT_FILE"
  cp "$OLD_SAT_FILE" "$SAT_FILE_DE" 2>/dev/null
  chmod 0600 "$SAT_FILE_DE" 2>/dev/null
else
  ui_print "- Creating DE config (default $DEFAULT_SAT)"
  echo "$DEFAULT_SAT" > "$SAT_FILE_DE" 2>/dev/null
  chmod 0600 "$SAT_FILE_DE" 2>/dev/null
fi

# Create user-facing config on shared storage if possible (best-effort)
if [ -f "$SAT_FILE_SD" ]; then
  ui_print "- Found existing saturation.cfg (leaving as-is): $SAT_FILE_SD"
else
  if [ -d "$SDROOT" ] && [ -w "$SDROOT" ]; then
    ui_print "- Creating user config: $SAT_FILE_SD (default $DEFAULT_SAT)"
    {
      echo "$DEFAULT_SAT"
      echo "$CFG_MARKER"
    } > "$SAT_FILE_SD" 2>/dev/null
    chmod 0644 "$SAT_FILE_SD" 2>/dev/null
  else
    ui_print "- Shared storage not writable during install; DE config will be used."
  fi
fi

ui_print " "
ui_print "- Install steps completed."
ui_print "  Reboot to apply."
ui_print " "
