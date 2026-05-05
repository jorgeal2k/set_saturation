# shellcheck shell=sh
# Helpers compartidos entre customize.sh y service.sh.
# No incluye resolve_sdroot ni la escritura atomica: cada fase mantiene su copia
# para no acoplar uninstall ni mezclar logica con permisos especificos de fase.

# shellcheck disable=SC2034
# These constants are consumed by sourcing scripts; shellcheck cannot see that
# when linting common.sh in isolation.
MIN_SAT="0.50"
MAX_SAT="2.00"
DEFAULT_SAT="1.0"

is_valid_float() {
  printf '%s\n' "$1" | grep -Eq '^[0-9]+(\.[0-9]+)?$'
}

in_range() {
  awk -v x="$1" -v min="$MIN_SAT" -v max="$MAX_SAT" \
    'BEGIN{ exit !(x>=min && x<=max) }'
}

read_first_line_trim() {
  head -n 1 "$1" 2>/dev/null | tr -d '[:space:]'
}
