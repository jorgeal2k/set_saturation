#!/system/bin/sh
# uninstall.sh — cleanup on module removal

# Remove user-facing config from shared storage
rm -f /data/media/0/saturation.cfg
rm -f /sdcard/saturation.cfg

# Note: $MODDIR/saturation.cfg is automatically removed by Magisk
# when it deletes the module directory.
