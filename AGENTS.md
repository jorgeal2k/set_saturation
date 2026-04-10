# AGENTS.md

## Alcance de trabajo
- Trabaja únicamente dentro de esta carpeta del módulo.
- Da preferencia a los archivos abiertos y a los referenciados explícitamente.
- No escanees todo el repositorio a menos que se solicite.
- Ignora archivos zip, artefactos de compilación, logs, capturas y archivos generados.

---

## Política de cambios
- Prioriza cambios pequeños y de bajo riesgo (small diffs).
- Preserva el comportamiento actual salvo que se indique lo contrario.
- No reestructures ni renombres archivos sin solicitud explícita.
- En auditorías: muestra hallazgos antes de aplicar cambios.

---

## Contexto del proyecto
- Este proyecto es un módulo de Android (Magisk / KernelSU).
- El entorno es limitado (toybox / toolbox), no GNU completo.
- Evita asumir comandos o comportamientos no estándar.
- Mantén compatibilidad entre ROMs y dispositivos.
- El código debe funcionar tanto en Magisk como en KernelSU.

---

## Fases de ejecución
- `customize.sh`: instalación.
- `post-fs-data.sh`: arranque temprano (filesystem limitado).
- `service.sh`: arranque tardío (usuario puede seguir bloqueado).
- `uninstall.sh`: limpieza.

---

## Reglas para scripts shell
- Usa sintaxis POSIX siempre que sea posible.
- Evita características específicas de Bash (arrays, [[ ]], etc.).
- Cita siempre variables y rutas: "$var".
- Evita word splitting y globbing accidental.
- No asumas que los comandos existen o se comportan como en Linux de escritorio.
- Maneja errores de forma segura (archivos inexistentes, permisos, etc.).

---

## Arranque y almacenamiento
- No asumas que `/sdcard` o `/storage/emulated/0` están disponibles en arranque temprano.
- El almacenamiento del usuario puede estar bloqueado en `service.sh`.
- Si una operación depende del almacenamiento del usuario:
  - usa reintentos
  - incluye timeout
  - evita bucles infinitos
- No bloquees el arranque por tareas no críticas.

---

## Prevención de race conditions
- No asumas que recursos del sistema están disponibles inmediatamente.
- Añade lógica de reintento cuando sea necesario.
- Evita dependencias implícitas del orden de ejecución.

---

## Seguridad en operaciones de archivos
- Verifica siempre que las rutas:
  - no estén vacías
  - sean las esperadas
- Evita `rm -rf` sin validaciones previas.
- Evita comodines peligrosos (`*`) en rutas críticas.
- Sé especialmente conservador con rutas sensibles.

---

## Compatibilidad
- Evita rutas específicas de ROM.
- Evita dependencias de binarios no estándar.
- Mantén comportamiento consistente en distintos dispositivos.

---

## Estilo de código
- Prefiere scripts pequeños y modulares.
- Extrae lógica compleja a helpers si es necesario.
- Prioriza claridad sobre complejidad.

---

## Revisión de código
Al auditar, comprueba siempre:
- variables sin comillas
- uso inseguro de rm/cp/mv/chmod/chown
- race conditions
- problemas de timing en arranque
- acceso a almacenamiento no disponible

---

## Propuesta de cambios
Agrupa siempre en:
- must fix now
- recommended hardening
- optional improvements

Explica por qué cada cambio es necesario y seguro.

---

## Aplicación de cambios
- No reescribas scripts completos sin necesidad.
- No introduzcas cambios de comportamiento innecesarios.
- Mantén los cambios mínimos y reversibles.