#!/system/bin/sh
# shellcheck shell=sh

# uninstall.sh — cleanup on module removal

# La configuración saturation.cfg en el almacenamiento compartido (/sdcard)
# se preserva intencionadamente para que el usuario no pierda sus valores
# personalizados si reinstala o actualiza el módulo en el futuro.
#
# Nota: La configuración interna del módulo en /data/adb/modules/set_saturation_boot
# es eliminada de forma automática por el gestor root (Magisk/KernelSU) al desinstalar.
