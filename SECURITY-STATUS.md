# Estado de seguridad de DevKey 2.0

Este documento describe lo que la implementación actual verifica y lo que sigue pendiente. No implica que los datos de `Apps`, `Data` o `Projects` estén cifrados.

## Controles disponibles

- El launcher comprueba `unlock.k3y` con SHA-256 y compara el digest configurado con un valor anclado en el launcher.
- La contraseña se deriva con PBKDF2-SHA256, salt aleatorio y parámetros guardados en `Config\auth.json`. Se puede leer el formato PBKDF2 anterior y migrarlo después de una autenticación correcta.
- Los intentos se limitan y el bloqueo temporal progresivo queda en `Config\lockout.json`.
- La clave de recuperación se genera con el generador criptográfico del sistema, se guarda como verificador derivado y se muestra una sola vez. La clave en claro no se escribe en logs.
- Los logs limitan tamaño y retención, y filtran cadenas con aspecto de token. No son una auditoría resistente a manipulación.
- Los manifiestos locales detectan cambios de archivos, pero son **sin firma**. No prueban quién publicó el código ni resisten a un atacante que pueda cambiar tanto los archivos como el manifiesto.
- Guardian valida el número de serie del volumen y el token, supervisa procesos de la sesión y usa cierre cooperativo antes de cualquier cierre forzado configurable.
- AutoLaunch usa un watcher visible para el usuario actual. Se instala y desinstala desde Configuración; no usa AutoRun del USB ni oculta su ejecución.
- Los backups de proyectos verifican los hashes de los archivos incluidos y omiten patrones de nombres sensibles conocidos. El ZIP no está cifrado y la búsqueda por patrones no detecta secretos incluidos dentro de archivos ordinarios.

## Segundo factor

El archivo `unlock.k3y` aporta una comprobación de presencia, pero su hash no es un secreto y puede clonarse junto con el archivo. Por eso, token más contraseña no debe presentarse como una autenticación fuerte de dos factores.

La opción a evaluar es una llave FIDO2/WebAuthn con verificación de usuario, independiente del USB y de la contraseña DevKey. Antes de implementarla, hay que comprobar la disponibilidad de la API WebAuthn de Windows en los equipos objetivo y preparar pruebas de registro, desafío, cancelación, pérdida de llave y recuperación. Guardar un secreto TOTP o un PIN en la misma unidad no constituye un factor independiente.

No se implementa un segundo factor en esta versión.

## Cifrado de proyectos

En el Windows PowerShell 5.1 instalado durante esta auditoría, el tipo .NET `System.Security.Cryptography.AesGcm` no está disponible. No se debe sustituir con AES-CBC casero ni con una construcción criptográfica propia.

Antes de habilitar cifrado, elegir y validar una de estas rutas:

1. Un pequeño helper separado en .NET moderno, con AES-256-GCM, una versión fijada, origen verificable e integración probada desde PowerShell 5.1.
2. Una herramienta portátil de cifrado autenticado auditada, con formato y procedimiento de recuperación documentados.

El flujo deberá usar una clave aleatoria, mantenerla fuera de los archivos cifrados y fuera de la USB, validar el descifrado antes de retirar originales, crear backups verificables y dejar claro que aplicaciones, memoria, cachés y temporales pueden conservar copias. No se automatiza cifrado ni borrado de originales en este momento.

## Pendientes antes de declarar el entorno validado

- El nuevo `D:\unlock.k3y` de 32 bytes ya pasa la comprobación SHA-256 y coincide con ambos pins. No existe `auth.json`: la primera ejecución real pedirá crear la contraseña; el agente no creó una contraseña.
- Las carpetas portátiles `D:\Apps\Docker`, `Git`, `KeePass`, `Kiro` y `OpenCode` siguen vacías. En este host se detectaron Kiro 1.2.56, OpenCode 1.18.25, Git 2.55.0 y Node.js 24.19.0 desde sus instalaciones existentes.
- Docker Desktop 4.96.3 y CLI 29.9.2 quedaron instalados por usuario; `docker info` respondió con el servidor 29.9.2. No se descargaron ni ejecutaron imágenes de contenedor.
- No se probaron inserción/extracción física del USB, AutoLaunch de inicio de sesión ni cierre de procesos reales.
- `D:\Backups` contiene un backup histórico. Se conservó sin cambios; cualquier unificación de destinos debe mantener ambas ubicaciones hasta una migración verificada.
