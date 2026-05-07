# shellcheck shell=sh
# Helpers compartidos entre customize.sh y service.sh.
# uninstall.sh mantiene su propia resolve_sdroot para conservar la autonomía.

# shellcheck disable=SC2034
# These constants are consumed by sourcing scripts; shellcheck cannot see that
# when linting common.sh in isolation.
MIN_SAT="0.50"
MAX_SAT="2.00"
DEFAULT_SAT="1.0"

is_valid_float() {
  printf '%s\n' "$1" | grep -Eq '^[0-9]+(\.[0-9]+)?$'
}

_ir_to_int() {
  # Convert "X.YY" to integer X*100+YY for toybox/toolbox portable float comparison.
  _ir_int_part="${1%%.*}"
  _ir_dec_part="${1#*.}"
  [ "$_ir_dec_part" = "$_ir_int_part" ] && _ir_dec_part="00"
  _ir_dec_part="$(printf '%-2s' "$_ir_dec_part" | tr ' ' '0' | cut -c1-2)"
  # Strip leading zeros to avoid octal interpretation (pure POSIX).
  while [ "${_ir_dec_part}" != "0" ] && [ "${_ir_dec_part#"${_ir_dec_part#?}"}" = "$_ir_dec_part" ] && [ "${_ir_dec_part%"${_ir_dec_part%?}"}" != "$_ir_dec_part" ]; do
    _ir_dec_part="${_ir_dec_part#0}"
  done
  printf '%d' "$((_ir_int_part * 100 + _ir_dec_part))"
}

in_range() {
  _ir_val="$1"
  _ir_min="$MIN_SAT"
  _ir_max="$MAX_SAT"

  _ir_val_int="$(_ir_to_int "$_ir_val")"
  _ir_min_int="$(_ir_to_int "$_ir_min")"
  _ir_max_int="$(_ir_to_int "$_ir_max")"

  [ "$_ir_val_int" -ge "$_ir_min_int" ] && [ "$_ir_val_int" -le "$_ir_max_int" ]
}

read_first_line_trim() {
  head -n 1 "$1" 2>/dev/null | tr -d '[:space:]'
}

resolve_sdroot() {
  if [ -n "$EXTERNAL_STORAGE" ] && [ -d "$EXTERNAL_STORAGE" ]; then
    printf '%s\n' "$EXTERNAL_STORAGE"
  elif [ -d "/data/media/0" ]; then
    printf '%s\n' "/data/media/0"
  else
    printf '%s\n' "/sdcard"
  fi
}
