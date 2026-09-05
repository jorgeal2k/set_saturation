#!/system/bin/sh
# shellcheck shell=sh

# boot-completed.sh — post-boot stage.
#
# Only root managers that implement this stage run it (KernelSU and forks).
# Magisk has no boot-completed stage and simply ignores this file: there the
# same work is done by the fallback path at the end of service.sh.
#
# This is deliberately a thin wrapper. The saturation helpers live in
# service.sh; duplicating them here would let the two copies drift apart.
# service.sh guards the work with an atomic claim, so it runs once per boot
# no matter which side reaches it first.

MODDIR="${0%/*}"
case "$MODDIR" in
  /*) ;;
  *) MODDIR="/data/adb/modules/set_saturation_boot" ;;
esac

# Nothing to do if service.sh is missing or not executable; service.sh owns
# the error log, so there is no way to report it from here.
[ -x "$MODDIR/service.sh" ] || exit 0

exec "$MODDIR/service.sh" post-boot
