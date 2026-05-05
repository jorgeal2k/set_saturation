# AGENTS.md

Guía de trabajo para agentes de código que modifiquen, auditen o creen módulos Android root compatibles con **Magisk** y **KernelSU**.

Este documento define reglas de alcance, estilo, seguridad y compatibilidad para scripts de instalación, arranque, desinstalación y estructura general del módulo. Está pensado para proyectos genéricos de módulos root Android, no para un módulo concreto.

---

## 1. Alcance de trabajo

- Trabaja únicamente dentro de la carpeta del módulo o repositorio indicado por el usuario.
- Da prioridad a los archivos abiertos, adjuntos o mencionados explícitamente.
- No escanees todo el repositorio salvo que sea necesario para entender dependencias reales.
- Ignora salvo petición expresa:
  - archivos `.zip`;
  - artefactos de compilación;
  - logs;
  - capturas;
  - backups;
  - archivos temporales;
  - archivos generados;
  - carpetas de herramientas o agentes como `.codex/`, `.claude/`, `.cursor/`, `.github/`, etc.
- No modifiques archivos ajenos al módulo sin permiso explícito.
- No introduzcas dependencias externas sin aprobación explícita.

---

## 2. Objetivo del proyecto

El repositorio contiene un módulo Android root que debe ser compatible, en la medida de lo posible, con:

- Magisk;
- KernelSU;
- KernelSU Next, siempre que no requiera lógica específica incompatible;
- Android moderno con `toybox` / `toolbox`, no GNU/Linux completo.

El código debe priorizar:

1. Evitar bootloops.
2. Evitar pérdida de datos del usuario.
3. Mantener compatibilidad Magisk / KernelSU.
4. Mantener compatibilidad entre ROMs, dispositivos y versiones de Android.
5. Mantener scripts simples, auditables y reversibles.
6. Reducir riesgos sin añadir complejidad innecesaria.

---

## 3. Política general de cambios

- Prioriza cambios pequeños, claros y reversibles.
- Preserva el comportamiento existente salvo que el usuario pida cambiarlo.
- No reestructures, renombres ni dividas archivos sin necesidad clara.
- No reescribas scripts completos si basta con un parche localizado.
- Evita cambios cosméticos masivos.
- No introduzcas nuevas abstracciones si no reducen riesgo o complejidad real.
- Evita introducir dependencias nuevas si no son imprescindibles.
- No asumas rutas, servicios, propiedades o binarios específicos de una ROM concreta.
- En auditorías, muestra primero los hallazgos antes de aplicar cambios.
- Después de modificar, explica:
  - qué cambiaste;
  - por qué era necesario;
  - qué riesgo reduce;
  - qué archivos tocaste;
  - qué queda pendiente de probar.

---

## 4. Compatibilidad Magisk / KernelSU

No asumas que Magisk, KernelSU y KernelSU Next exponen exactamente el mismo entorno de ejecución.

Buenas prácticas:

- Usa `$MODDIR` cuando esté disponible para localizar la ruta real del módulo en tiempo de ejecución.
- Usa rutas relativas al módulo cuando sea posible.
- No dependas de rutas internas específicas de Magisk o KernelSU salvo que sean estándar o el usuario lo solicite.
- No asumas que `MODPATH`, `MODDIR` u otras variables existen en todos los contextos si no están documentadas para esa fase.
- En instalación, usa helpers como `ui_print` y `set_perm` solo en contextos donde existan, normalmente `customize.sh`.
- Comprueba la existencia de archivos y directorios antes de usarlos.
- Evita acoplar la lógica a un único gestor root.
- Mantén el módulo funcional aunque alguna característica opcional no esté disponible.
- No introduzcas lógica destructiva para “detectar” el gestor root.

---

## 5. Ciclo de vida habitual de un módulo

Los scripts de un módulo pueden ejecutarse en fases distintas y con capacidades distintas.

| Archivo | Fase | Consideraciones |
|---|---|---|
| `customize.sh` | Instalación | Puede disponer de helpers de Magisk/KernelSU como `ui_print` y `set_perm`. Puede ejecutarse en recovery o en un entorno limitado. No asumas que Android framework ni `/sdcard` están disponibles. |
| `post-fs-data.sh` | Arranque temprano | El sistema está parcialmente inicializado. Evita depender de `/sdcard`, servicios tardíos o almacenamiento de usuario. |
| `service.sh` | Arranque tardío | Android userspace está más avanzado, pero el usuario puede seguir sin desbloquear el dispositivo y `/sdcard` puede no estar disponible. |
| `uninstall.sh` | Desinstalación | Debe limpiar solo lo que el módulo haya creado y hacerlo con validaciones estrictas. |
| `system.prop` | Propiedades | Evita propiedades innecesarias, frágiles o específicas de ROM si no están justificadas. |
| `sepolicy.rule` | SELinux | Úsalo solo cuando sea necesario. Mantén reglas mínimas, concretas y justificadas. |

Reglas:

- No todos los módulos necesitan todos estos archivos.
- No crees scripts nuevos sin una razón clara.
- No mezcles responsabilidades entre fases sin necesidad.
- No hagas en `post-fs-data.sh` tareas que puedan esperar a `service.sh`.
- No bloquees el arranque con operaciones lentas o no críticas.
- Diseña la desinstalación para ser segura incluso si el módulo quedó en un estado parcial.

---

## 6. Entorno shell Android

El shell objetivo es Android `/system/bin/sh`, normalmente con utilidades `toybox` o `toolbox`. Sigue POSIX siempre que sea posible.

Evita bashisms:

- arrays;
- `[[ ... ]]`;
- process substitution;
- here-strings;
- `$'...'`;
- expansiones avanzadas de Bash;
- `local`, salvo que el entorno objetivo lo soporte explícitamente y el usuario lo acepte;
- `pipefail`, porque no es POSIX;
- dependencias innecesarias en utilidades GNU.

Preferencias:

- `#!/system/bin/sh` cuando corresponda en Android.
- Sintaxis POSIX simple.
- `case` en lugar de expresiones complejas.
- Funciones pequeñas y claras.
- Validaciones explícitas.
- Comandos externos simples y defensivos.

---

## 7. Reglas de scripting shell

- Cita siempre variables y rutas: `"$var"`, `"$path"`.
- Usa `printf '%s\n'` en lugar de `echo` para datos variables.
- Evita word splitting accidental.
- Evita globbing accidental.
- Comprueba que archivos y directorios existen antes de operar sobre ellos.
- Valida entradas antes de usarlas en comandos sensibles.
- Usa `mkdir -p` solo con rutas validadas.
- No uses `set -e` globalmente si puede provocar abortos inesperados en Android.
- Maneja errores sin romper el arranque salvo que la operación sea crítica.
- Evita bucles infinitos.
- Usa timeouts en esperas.
- Mantén las funciones con una responsabilidad clara.

Ejemplo de estilo preferido:

```sh
if [ -f "$cfg" ]; then
    value="$(read_value "$cfg")"
else
    value=""
fi
```

Evita:

```sh
value=$(cat $cfg)
```

---

## 8. Comandos y portabilidad

No asumas un entorno GNU completo.

Antes de usar opciones avanzadas de `grep`, `sed`, `awk`, `find`, `stat`, `readlink`, `date`, `xargs` o similares, considera si existen en `toybox` / `toolbox`.

Evita depender de:

- GNU `sed` avanzado;
- GNU `awk`;
- `realpath`;
- `readlink -f`;
- `stat` con formato GNU;
- `timeout`;
- `flock`;
- `find` con opciones avanzadas;
- `xargs` con opciones no POSIX;
- `perl`, `python`, `bash` u otras dependencias no garantizadas.

Usa comandos externos solo cuando aporten valor claro y de forma defensiva.

---

## 9. Validación de entradas

Toda entrada externa debe validarse:

- archivos en `/sdcard` o almacenamiento compartido;
- valores configurables por el usuario;
- propiedades del sistema;
- salida de comandos Android;
- rutas construidas dinámicamente.

Para valores numéricos:

- elimina espacios si procede;
- acepta solo dígitos si debe ser entero;
- define mínimo y máximo;
- rechaza valores vacíos;
- rechaza valores fuera de rango;
- usa aritmética entera POSIX.

Ejemplo:

```sh
case "$value" in
    ''|*[!0-9]*)
        return 1
        ;;
esac
```

Reglas adicionales:

- No uses `eval`.
- No ejecutes directamente contenido procedente de configuración de usuario.
- Evita `source` / `.` sobre archivos ubicados en almacenamiento compartido o editables por apps.
- No construyas comandos peligrosos con texto no validado.
- Define siempre un fallback seguro.

---

## 10. Manejo de configuración

Cuando el módulo use archivos de configuración:

- Define valores por defecto seguros.
- Crea archivos por defecto solo si no existen o si el comportamiento esperado lo requiere.
- No sobrescribas configuración del usuario sin motivo.
- Valida siempre datos leídos de archivos editables por el usuario.
- Si la configuración está vacía, corrupta o fuera de rango, usa el valor por defecto.
- Si necesitas sincronizar configuración entre almacenamiento temprano y almacenamiento de usuario, hazlo de forma explícita y segura.
- No dependas exclusivamente de `/sdcard` para arrancar.

---

## 11. Escrituras atómicas

Cuando actualices archivos de configuración o caché:

- escribe primero a un archivo temporal;
- valida que la escritura terminó correctamente;
- ajusta permisos si corresponde;
- mueve con `mv -f` al destino final;
- elimina temporales en caso de error.

Patrón recomendado:

```sh
tmp="$target.tmp.$$"

if printf '%s\n' "$value" > "$tmp"; then
    mv -f "$tmp" "$target" || {
        rm -f "$tmp"
        return 1
    }
else
    rm -f "$tmp"
    return 1
fi
```

---

## 12. Arranque, almacenamiento y timing

Durante el arranque Android, muchos recursos no están disponibles inmediatamente.

No asumas que están listos:

- `/sdcard`;
- `/storage/emulated/0`;
- `/data/media/0`;
- servicios del framework;
- propiedades finales del sistema;
- comandos que dependen de Android userspace;
- ajustes que la ROM puede sobrescribir más tarde.

Buenas prácticas:

- Espera propiedades del sistema solo con timeout.
- Usa reintentos cortos y limitados.
- Evita sleeps fijos largos como solución principal.
- Prefiere comprobar condiciones reales con timeout.
- No bloquees indefinidamente el arranque.
- Vuelve a aplicar ajustes si la ROM puede sobrescribirlos y está justificado.
- Separa lógica temprana y tardía.
- Considera que el usuario puede no haber desbloqueado el dispositivo todavía.

Ejemplo de espera con límite:

```sh
tries=0
while [ "$tries" -lt 60 ]; do
    state="$(getprop sys.boot_completed 2>/dev/null)"
    [ "$state" = "1" ] && break
    tries=$((tries + 1))
    sleep 1
done
```

---

## 13. Almacenamiento protegido y `/sdcard`

El almacenamiento del usuario puede no estar disponible hasta después del primer desbloqueo.

Reglas:

- No dependas de `/sdcard` para tareas críticas de arranque.
- Usa una copia o caché en almacenamiento del módulo si necesitas valores tempranos.
- Sincroniza con `/sdcard` solo cuando esté disponible.
- Si una operación depende del almacenamiento compartido:
  - usa reintentos limitados;
  - incluye timeout;
  - evita bucles infinitos;
  - no bloquees el arranque por tareas no críticas;
  - falla de forma segura.

---

## 14. Sincronización, race conditions e idempotencia

Los módulos root pueden ejecutarse mientras Android todavía está inicializando.

Revisa siempre:

- orden de ejecución;
- disponibilidad de servicios;
- archivos que aparecen tarde;
- propiedades que cambian durante boot;
- configuraciones sobrescritas por la ROM;
- ejecución repetida del mismo script;
- escrituras simultáneas sobre el mismo archivo.

Preferencias:

- operaciones idempotentes;
- comprobaciones antes de aplicar cambios;
- archivos temporales únicos con `$$`;
- reintentos limitados;
- procesos en segundo plano solo si tienen límites claros;
- evitar procesos persistentes innecesarios.

Una segunda ejecución del script no debería:

- duplicar entradas;
- corromper archivos;
- borrar configuraciones válidas;
- aplicar cambios incompatibles;
- dejar temporales;
- producir estados imposibles.

---

## 15. Seguridad en operaciones de archivos

Sé extremadamente conservador con operaciones destructivas.

Antes de usar `rm`, `cp`, `mv`, `chmod`, `chown`, `ln` o similares:

- verifica que la ruta no esté vacía;
- verifica que la ruta pertenece al ámbito esperado;
- evita comodines peligrosos en rutas críticas;
- evita `rm -rf` salvo que exista una validación previa muy clara;
- no borres rutas genéricas como `/data`, `/system`, `/vendor`, `/product`, `/sdcard` o similares;
- no sigas symlinks peligrosos cuando pueda afectar a rutas sensibles;
- limpia solo archivos que el módulo haya creado.

Regla especial para desinstalación:

- elimina solo archivos creados por el módulo;
- si el archivo pudo haber sido editado o creado por el usuario, valida una marca de propiedad;
- si hay duda, conserva el archivo.

Es preferible dejar un archivo inocuo que borrar algo que no pertenece al módulo.

---

## 16. Permisos y propiedad

- Aplica permisos mínimos necesarios.
- En `customize.sh`, usa `set_perm` cuando sea apropiado y esté disponible.
- Scripts ejecutables: normalmente `0755`.
- Archivos de configuración no sensibles: normalmente `0644`.
- Configuración sensible: `0600` o lo más restrictivo posible según necesidad.
- Directorios: normalmente `0755`.
- Propietario habitual: `root:root`, salvo necesidad concreta.
- No hagas `chmod -R` o `chown -R` sobre rutas amplias sin validación y justificación.

---

## 17. SELinux

- No añadas reglas SELinux si el módulo puede funcionar sin ellas.
- Si `sepolicy.rule` es necesario, mantén reglas mínimas, concretas y justificadas.
- Evita reglas amplias que concedan permisos excesivos.
- No uses SELinux como atajo para ocultar errores de rutas, permisos o timing.
- Documenta brevemente por qué una regla es necesaria si se añade o modifica.

---

## 18. Modificación del sistema

- Evita modificar particiones reales del sistema si el overlay del módulo es suficiente.
- No remountes particiones como lectura/escritura salvo petición explícita y justificación fuerte.
- Evita cambios irreversibles.
- Mantén la lógica compatible con system-as-root, dynamic partitions y esquemas modernos de Android.
- No dependas de rutas específicas de fabricante salvo que el módulo esté declarado como específico para ese fabricante.
- No uses cambios destructivos para “arreglar” problemas de timing, permisos o SELinux.

---

## 19. Instalador

En `customize.sh`:

- muestra información clara con `ui_print` si está disponible;
- valida entorno y archivos necesarios;
- no asumas que Android framework está disponible;
- no asumas que `/sdcard` existe;
- crea archivos por defecto solo si faltan;
- no sobrescribas configuración del usuario sin motivo;
- aplica permisos explícitos a scripts y archivos relevantes;
- evita lógica pesada;
- no hagas operaciones que pertenezcan al arranque.

Los mensajes del instalador deben ser útiles, breves y no alarmistas.

---

## 20. Desinstalación

En `uninstall.sh`:

- limpia únicamente archivos creados por el módulo;
- comprueba rutas antes de borrar;
- no uses comodines amplios;
- no falles si un archivo ya no existe;
- no asumas que todos los archivos están presentes;
- no restaures ajustes globales si no puedes verificar que los cambió el módulo;
- evita borrar configuraciones de usuario salvo que sea el comportamiento esperado o el usuario lo solicite.

La desinstalación debe ser conservadora y segura incluso si el módulo quedó en un estado parcial.

---

## 21. Logging y depuración

- No generes logs persistentes salvo que el usuario lo pida o sean necesarios para depuración.
- No escribas logs permanentes en `/sdcard` salvo petición expresa.
- Si se añaden logs, deben ser limitados, claros y fáciles de desactivar.
- Evita escribir logs en bucles frecuentes.
- No incluyas información sensible en logs.
- Para versiones finales, elimina trazas temporales como `set -x` salvo petición explícita.
- En instaladores, mantén la salida limpia y comprensible.

---

## 22. Estructura recomendada

Una estructura típica de módulo puede incluir:

```text
module.prop
customize.sh
post-fs-data.sh
service.sh
uninstall.sh
README.md
AGENTS.md
META-INF/
```

No todos los módulos necesitan todos los scripts.

Añade helpers solo si reducen duplicación o riesgo. Duplica lógica simple entre fases si compartir un helper aumenta el riesgo durante instalación, arranque o desinstalación.

### Patrón: helper compartido entre fases

Cuando varias fases del módulo comparten lógica estable, un único archivo
`common.sh` sourced puede reducir el drift silencioso entre `customize.sh` y
`service.sh`. El patrón solo es seguro bajo condiciones concretas.

**Cuándo aplicarlo (todas deben cumplirse):**

- Hay duplicación real entre dos o más fases, no entre helpers triviales de una sola línea.
- El código duplicado es **estable**: validadores, constantes de rango, parsers simples. No lógica que dependa del entorno de fase (permisos, `set_perm`, `ui_print`, `umask`).
- El fallo de carga del helper es **recuperable**: en el peor caso una fase no se ejecuta, sin riesgo de bootloop ni de corrupción.

**Cuándo NO aplicarlo:**

- `uninstall.sh` casi nunca debe sourcear: se ejecuta en el momento más frágil del ciclo y debe poder limpiar incluso si el resto del módulo está roto.
- Funciones que difieren por fase aunque parezcan iguales: escritura atómica con `set_perm` (instalación) vs. `chmod` (arranque). La unificación oculta los matices y aumenta el riesgo.
- Helpers que deban reportar el propio fallo del helper (paradoja): el logger inicial debe quedar inline.

**Qué incluir típicamente:**

- Constantes de rango y valores por defecto.
- Validadores puros: `is_valid_float`, `in_range`, `read_first_line_trim`.
- Cualquier helper sin efectos secundarios y estable a través de fases.

**Qué excluir típicamente:**

- `resolve_sdroot` y similares: se necesitan también en `uninstall.sh`, que conviene mantener autónomo.
- Funciones con I/O sensible a permisos (`umask`, `set_perm`, `chmod`).
- Funciones que dependan de helpers exclusivos de una fase (`ui_print`, `abort` solo en instalación).

**Carga y manejo de fallo:**

- Sourcear con guarda y aborto limpio. **Nunca** fallback inline (volvería a duplicar exactamente lo que se intenta evitar).
- En instalación: `ui_print` + `abort` del gestor root.
- En arranque: log corto en `$MODDIR/error.log` (rotado) y `exit 0` para no marcar el service como crash.
- El helper de logging debe ser **inline**, antes del sourcing.

**Empaquetado y permisos:**

- Helper en la raíz del módulo, sin shebang (es sourced, no ejecutable).
- `0644 root:root` aplicado en `customize.sh` vía `set_perm`.
- Incluido en el zip instalable.
- `# shellcheck shell=sh` y `# shellcheck disable=SC2034` para constantes compartidas (shellcheck no puede ver consumidores al lintar el helper en aislamiento).

**Esqueleto mínimo:**

`common.sh` (sourced desde `customize.sh` y `service.sh`; no desde `uninstall.sh`):

```sh
# shellcheck shell=sh
# shellcheck disable=SC2034
MIN_VAL="0.50"
MAX_VAL="2.00"
DEFAULT_VAL="1.0"

is_valid_float() {
  printf '%s\n' "$1" | grep -Eq '^[0-9]+(\.[0-9]+)?$'
}
```

Carga desde `customize.sh`:

```sh
# shellcheck source=common.sh
if ! . "$MODPATH/common.sh" 2>/dev/null; then
  ui_print "! Failed to load common.sh"
  abort   "! Aborting install"
fi
```

Carga desde `service.sh` (con logger inline previo):

```sh
log_error() {
  _log="$MODDIR/error.log"
  _lines="$(wc -l < "$_log" 2>/dev/null)"
  [ "${_lines:-0}" -gt 100 ] && printf '' > "$_log"
  printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" >> "$_log"
}

# shellcheck source=common.sh
if ! . "$MODDIR/common.sh" 2>/dev/null; then
  log_error "common.sh missing or unloadable; aborting service"
  exit 0
fi
```

---

## 23. `module.prop`

Al modificar `module.prop`:

- conserva formato simple `clave=valor`;
- no introduzcas comentarios incompatibles;
- mantén `id` estable salvo que se pida cambiarlo;
- no cambies `version` o `versionCode` sin instrucción;
- usa descripciones claras y genéricas;
- evita caracteres problemáticos en campos críticos.

---

## 24. Empaquetado

Al crear un zip instalable:

- incluye solo archivos necesarios;
- evita meter `.git`, logs, backups o carpetas de agentes;
- conserva la estructura esperada por Magisk / KernelSU;
- verifica que los scripts tienen permisos correctos;
- no sobrescribas zips previos sin indicarlo.

Ejemplo genérico:

```sh
zip -r module.zip META-INF module.prop customize.sh post-fs-data.sh service.sh uninstall.sh
```

Ajusta la lista de archivos según la estructura real del módulo.

---

## 25. Estilo de código

- Prioriza claridad sobre compactación extrema.
- Usa funciones pequeñas cuando reduzcan duplicación real y no creen acoplamiento peligroso entre fases.
- Mantén comentarios útiles, especialmente cuando haya decisiones relacionadas con boot timing, almacenamiento bloqueado, compatibilidad o seguridad.
- Los comentarios dentro del código pueden estar en inglés si ayudan a mantener compatibilidad con agentes y herramientas.
- Evita cambios de formato masivos si no son necesarios.
- No mezcles refactors con fixes críticos.

---

## 26. Revisión de código

Al auditar scripts, comprueba siempre:

- variables sin comillas;
- rutas no validadas;
- `rm`, `cp`, `mv`, `chmod`, `chown` o `ln` inseguros;
- bashisms incompatibles con Android `/system/bin/sh`;
- dependencias GNU o binarios no estándar;
- ausencia de timeouts;
- bucles infinitos;
- condiciones de carrera;
- acceso prematuro a `/sdcard`;
- suposiciones incorrectas sobre almacenamiento desbloqueado;
- falta de validación de entrada;
- escrituras no atómicas;
- limpieza peligrosa en desinstalación;
- comportamiento diferente entre Magisk y KernelSU;
- rutas específicas de ROM o fabricante;
- reglas SELinux demasiado amplias;
- riesgo de bootloop;
- cambios no idempotentes;
- logs excesivos o permanentes;
- permisos demasiado permisivos;
- cambios irreversibles o destructivos.

---

## 27. Clasificación de propuestas

Cuando propongas cambios o presentes una auditoría, agrupa los hallazgos así:

### Must fix now

Problemas que pueden causar:

- bootloop;
- borrado peligroso;
- corrupción de configuración;
- incompatibilidad clara;
- fallo de instalación, arranque o desinstalación;
- pérdida de datos del usuario.

### Recommended hardening

Mejoras que reducen riesgos:

- validaciones adicionales;
- timeouts;
- escrituras atómicas;
- compatibilidad Magisk / KernelSU;
- compatibilidad entre ROMs;
- control de errores;
- mitigación de race conditions.

### Optional improvements

Cambios útiles pero no urgentes:

- limpieza de estilo;
- modularización menor;
- mensajes más claros;
- pequeñas simplificaciones;
- refactors de bajo riesgo.

Para cada hallazgo, indica:

- archivo afectado;
- sección o función;
- problema;
- riesgo;
- solución recomendada;
- por qué la solución es segura.

---

## 28. Aplicación de parches

Al aplicar cambios:

- usa el diff mínimo razonable;
- conserva nombres existentes;
- conserva formato general;
- no cambies comportamiento no relacionado;
- no mezcles refactors con fixes críticos;
- no introduzcas cambios de comportamiento no solicitados;
- resume archivos modificados y motivo;
- menciona cualquier supuesto no verificado.

Después de modificar, revisa mentalmente:

- instalación;
- arranque temprano;
- arranque tardío;
- almacenamiento bloqueado;
- almacenamiento desbloqueado;
- ejecución repetida;
- desinstalación.

---

## 29. Pruebas recomendadas

Si no hay test suite automatizada, sugiere pruebas manuales:

- instalar el módulo en Magisk;
- instalar el módulo en KernelSU;
- reiniciar con el dispositivo bloqueado;
- reiniciar y desbloquear tarde;
- comprobar que no hay errores visibles;
- comprobar que los archivos esperados existen;
- comprobar permisos y propiedad;
- cambiar configuración de usuario si aplica;
- reiniciar de nuevo;
- desinstalar;
- verificar que la limpieza es segura.

No afirmes que algo está probado en dispositivo real si no se ha ejecutado.

---

## 30. Qué no hacer

No hagas lo siguiente salvo instrucción explícita:

- convertir scripts POSIX a Bash;
- añadir dependencias externas;
- depender de GNU coreutils;
- usar `eval`;
- ejecutar configuración de usuario como código;
- borrar archivos del usuario sin validación;
- usar `rm -rf` sobre rutas dinámicas;
- cambiar el `id` del módulo;
- reestructurar todo el proyecto;
- introducir logs permanentes;
- asumir una ROM concreta;
- asumir un dispositivo concreto;
- asumir una versión concreta de Android;
- remountar particiones del sistema como lectura/escritura;
- optimizar prematuramente;
- ocultar cambios de comportamiento.

---

## 31. Respuesta esperada del agente

Al terminar una revisión o modificación, responde con:

1. Resumen breve.
2. Archivos modificados.
3. Cambios principales.
4. Riesgos reducidos.
5. Riesgos o supuestos pendientes.
6. Pruebas recomendadas o realizadas.

No incluyas explicaciones largas si el cambio fue pequeño.

Distingue siempre entre:

- comprobado;
- inferido;
- recomendado;
- pendiente de probar.

---

## 32. Idioma y estilo

- Responde preferentemente en español si el usuario escribe en español.
- Mantén los comentarios dentro de scripts en inglés si el proyecto ya usa ese estilo.
- Sé preciso y directo.
- No exageres garantías.
- No afirmes compatibilidad o pruebas reales si no se han verificado.
