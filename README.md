# Set Saturation at Boot
Módulo root para Android (Magisk/KernelSU) que aplica la saturación de color de SurfaceFlinger al arrancar y mantiene sincronizada la configuración entre el módulo y el almacenamiento compartido.

## Qué hace
- Aplica en boot el valor de saturación usando `service call SurfaceFlinger 1022 f <valor>`.
- Lee la configuración desde `saturation.cfg`.
- Usa una copia interna en el módulo (`/data/adb/modules/set_saturation_boot/saturation.cfg`) para funcionar incluso antes del primer desbloqueo (FBE-safe).
- Sincroniza con la configuración visible para el usuario (`/sdcard/saturation.cfg` o ruta equivalente).
- Si existen ambas configuraciones en instalación, **prioriza la de `/sdcard`**.

## Rango y valor por defecto
- Rango permitido: `0.50` a `2.00`
- Valor por defecto: `1.0`
- Formato esperado: número decimal positivo (ej: `0.85`, `1.0`, `1.25`)

## Requisitos
- Android con acceso root.
- Gestor compatible:
  - Magisk
  - KernelSU

## Instalación
1. Empaqueta el contenido del módulo en un ZIP instalable.
2. Instálalo desde Magisk o KernelSU.
3. Reinicia el dispositivo.

Durante la instalación:
- Se validan y ajustan permisos de scripts/archivos.
- Si existe `/sdcard/saturation.cfg` válido, se copia al módulo.
- Si no existe o es inválido, se conserva/restaura una configuración válida del módulo o se crea una por defecto (`1.0`).

## Configuración de saturación
Edita el archivo:

`/sdcard/saturation.cfg`

Con una sola línea, por ejemplo:

`1.15`

Reinicia para garantizar aplicación temprana en el siguiente arranque.  
El servicio también intenta sincronizar y reaplicar cuando el sistema termina de iniciar.

## Flujo de arranque (resumen)
1. Se asegura que exista una configuración interna válida.
2. Espera a que SurfaceFlinger esté activo.
3. Aplica saturación lo antes posible desde la configuración interna.
4. Tras `boot_completed`, reaplica (por posibles reseteos de la ROM/servicio).
5. Intenta sincronizar desde `/sdcard/saturation.cfg` si aparece luego del desbloqueo.

Los pasos 4 y 5 se ejecutan una sola vez por arranque, se alcancen desde
`boot-completed.sh` (KernelSU y derivados, que disponen de esa fase) o desde el
camino de reserva de `service.sh` (Magisk, que no la tiene).

## Desinstalación
- `uninstall.sh` **no borra** intencionalmente `/sdcard/saturation.cfg` para preservar la configuración del usuario.
- La configuración interna del módulo se elimina junto al módulo por el gestor root.

## Archivos principales
- `module.prop`: metadatos del módulo.
- `customize.sh`: lógica de instalación y sincronización inicial.
- `service.sh`: aplicación en boot y sincronización tardía.
- `boot-completed.sh`: fase post-boot en gestores que la soportan; delega en `service.sh`.
- `common.sh`: validación de valores y helpers compartidos.
- `uninstall.sh`: limpieza conservadora al desinstalar.

## Notas
- Si se proporciona un valor fuera de rango o inválido, se ignora y se usa un valor seguro.
- Los errores de aplicación en arranque se registran en:
  - `/data/adb/modules/set_saturation_boot/error.log`
