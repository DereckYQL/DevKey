# DevKey 2.0 — Auditoría de Fase 0

**Fecha de inspección:** 2026-10-23  
**Ámbito:** inventario y revisión estática del contenido actual de `D:\DevKey`. No se ejecutó el launcher ni se modificaron scripts, configuraciones, proyectos, credenciales o backups.

## Resumen

El repositorio contiene un launcher funcional en forma de script monolítico de aproximadamente 2.200 líneas, 12 módulos de menú/funciones, tres scripts en `Core` y un módulo nuevo de autenticación. Los scripts activos pasan el análisis sintáctico del parser de PowerShell disponible en este entorno. Esto solo comprueba sintaxis: no acredita que los menús, herramientas, autenticación o acciones Git funcionen en el equipo USB.

Hay dos generaciones de implementación sin integrar: el launcher antiguo usa sus propias rutas, autenticación y funciones; `Core\PathManager.ps1`, `Core\Bootstrap.ps1` y `Security\Authentication.ps1` implementan una arquitectura más nueva, pero el launcher no los carga ni llama. `Config\config.json`, `auth.json`, el manifiesto y los scripts de Guardian no existen en la copia inspeccionada. La autenticación y la clave físicas no pudieron probarse.

## Ubicación de la raíz y del token

- El launcher está en `D:\DevKey\Launcher\DevKey.ps1`.
- En el launcher actual, `$DevKeyRoot = Split-Path -Parent $PSScriptRoot`; con esta ubicación da `D:\DevKey`.
- El mismo launcher calcula `$USBRoot` como el directorio padre de la raíz: `D:\`.
- Por tanto, su ruta efectiva para el token es `D:\unlock.k3y`. Esa ruta no existe en el entorno inspeccionado. Tampoco se encontró el archivo en la raíz actual del proyecto.
- `Core\PathManager.ps1` calcula también la raíz desde su propio `$PSScriptRoot` y el token en el directorio padre de DevKey, pero actualmente no está integrado.
- Las rutas para `Data\KiroUser`, `Projects`, `Apps` y `Backups` en el launcher se calculan bajo `$USBRoot` (p. ej. `D:\Projects`), no dentro de `D:\DevKey`. El `README` también describe varias de esas carpetas en la raíz de la unidad. El path manager nuevo, en cambio, las define dentro de `DevKey`. Esta diferencia debe resolverse explícitamente durante la migración para no mover datos por accidente.

## Estructura real encontrada

```text
D:\DevKey\
  Config\                 git.json, profiles.json, version.json
  Core\                   Bootstrap.ps1, ErrorHandler.ps1, PathManager.ps1
  Launcher\               DevKey.ps1, DevKey.bat
  Logs\                   devkey.log
  Modules\                12 scripts de menú, Git, mantenimiento y utilidades
  Security\                Authentication.ps1
  Backups\legacy-v1-20261023-214553\  snapshot previo de archivos/configuración
  DEVKEY-USB-README.txt
  .aider.chat.history.md, .aider.input.history
```

No se encontraron `Apps`, `Projects` ni `Data` dentro de `D:\DevKey`; el launcher sí intenta crear algunas rutas en la raíz de la unidad. No se encontraron Guardian, `config.json`, `auth.json`, `integrity.json`, `devkey-public.cer` ni `Crypto-Test.ps1`. Los tres directorios de datos se deben distinguir entre “no presentes en la carpeta auditada” y “no disponibles en todo el dispositivo”; la raíz de unidad actual carece del token y no se inspeccionó una unidad externa distinta.

El directorio Git informa todos los archivos actuales como no rastreados. El backup `Backups\legacy-v1-20261023-214553` conserva una copia del launcher y módulos antiguos, pero no contiene la versión actual de `Security\Authentication.ps1` ni las versiones actuales recientes de los scripts en `Core`. No se modificó ningún archivo que requiriera crear un nuevo backup durante esta fase.

## Funciones y ubicación

### Launcher — `Launcher\DevKey.ps1`

- Calcula raíz/rutas, crea algunos directorios, lee versión, define SHA-256 esperado, carga módulos existentes y lleva el flujo principal.
- Contiene autenticación heredada PBKDF2, comprobación de token, estado, información del sistema, mantenimiento, perfiles y menú Git con clonado/inicialización/configuración.
- El flujo de inicio comprueba el hash del token antes de pedir contraseña. Sin `unlock.k3y`, el flujo interactivo no puede llegar a menú normal.
- Las funciones `Maintenance-CheckFiles`, `Maintenance-CheckPrograms`, `Maintenance-CheckHash` y `Maintenance-RepairStructure` existen en el launcher; las funciones de mantenimiento recrean directorios bajo las rutas actualmente configuradas.
- El menú principal activo es de la implementación antigua (opciones numéricas y `S` para seguridad); no coincide exactamente con la disposición de opciones 1–9 del informe.

### Módulos — `Modules\*.ps1`

- `DevKey.Menu.ps1`: menú principal modular alternativo.
- `DevKey.Integrity.ps1`: creación/actualización y verificación de manifest de hashes; regenerar y aceptar el manifest requiere revisión antes de usar como verificación de confianza.
- `DevKey.Diagnose.ps1`: informe de diagnóstico.
- `DevKey.Config.ps1`: configuración Git y opciones relacionadas; no es la configuración central propuesta.
- `DevKey.Profiles.ps1`: perfiles.
- `DevKey.Updater.ps1`: consulta y actualización Git; ejecuta `fetch`/`pull` tras confirmación y hace backup de Config, pero no verifica firma del paquete ni ofrece rollback completo.
- `DevKey.Apps.ps1`: estado/menú de aplicaciones.
- `DevKey.GitX.ps1`: repositorios, sincronización, ramas, commits, push e historial.
- `DevKey.GitCreds.ps1`: helper/estado/prueba/limpieza de credenciales Git.
- `DevKey.backup.ps1`: backup/listado/restauración de proyectos.
- `DevKey.OS.ps1`: menú de información/sistema.
- `Security-Menu.ps1`: interfaz KeePass y generador de contraseñas. Al final llama `Show-DevKeySecurityMenu` directamente; al dot-source desde el launcher entra en un bucle interactivo anidado.

La carga de módulos ignora módulos ausentes y captura errores al dot-source, muestra advertencia y continúa. Por tanto, una carga parcial puede dejar opciones disponibles que luego fallen por comando ausente. Las funciones Git heredadas del launcher y `DevKey.GitX.ps1` coexisten; no todas son duplicados con el mismo nombre, pero la capacidad Git está repartida en dos implementaciones.

### Core y Security — código nuevo aún no conectado

- `Core\PathManager.ps1`: define rutas relativas, crea directorios al invocarse e incluye lectura de identidad de volumen.
- `Core\Bootstrap.ps1`: define valores predeterminados de configuración, importación/guardado de JSON y versión. La importación crea config si falta; no hay validación completa por propiedad.
- `Core\ErrorHandler.ps1`: define logging y wrapper de operación.
- `Security\Authentication.ps1`: define PBKDF2-SHA256, token, bloqueo progresivo, cambio de contraseña y recovery key.
- No hay referencias desde el launcher a esos archivos ni llamada observada a `Initialize-DevKeyPaths`, importación de configuración o API de autenticación nueva.
- La nueva autenticación espera campos `script:DevKeyConfig`, `script:AuthFile`, etc., y `Write-DevKeyLog -Log ...`; la implementación heredada tiene otro formato de `auth.json` y otra firma de logging. No se ha localizado `auth.json` para determinar si existe en la unidad original o cuál es su esquema real.

## Duplicados y problemas de integración

- `Write-DevKeyLog` está definido tanto en `Launcher\DevKey.ps1` (línea 131) como en `Core\ErrorHandler.ps1` (línea 1). Actualmente Core no se carga, por lo que no hay colisión en la ejecución activa; integrarlo sin unificación provocaría reemplazo de función en el ámbito de dot-source y firmas incompatibles.
- No se detectaron otros nombres de función duplicados entre scripts activos mediante AST.
- `Modules\Security-Menu.ps1` termina invocando su menú al importarse; debe transformarse en módulo sin efectos de entrada durante la carga.
- Bootstrap, PathManager y autenticación no están conectados al launcher; la interfaz actual mezcla ambas generaciones y el menú antiguo no usa el menú modular `Show-DevKeyMainMenu` en su ruta de ejecución normal.

## Sintaxis y comportamiento verificable

- **Sintaxis:** el parser de PowerShell no reportó errores en los scripts activos bajo `Launcher`, `Core`, `Modules` y `Security`.
- **Ejecución funcional:** no verificada. No se ejecutó el launcher porque requiere entrada interactiva y la comprobación del token fallaría por ausencia de `D:\unlock.k3y`; tampoco están disponibles las aplicaciones portables enumeradas en los archivos de inventario.
- **Autenticación:** código heredado y código nuevo detectados; sin `auth.json` visible y sin ejecución, la inicialización, login, cambio de clave, lockout y recovery no están validados.
- **Integridad:** existe verificación del token contra un hash constante en el launcher y funciones de manifiesto en un módulo. No se pudo comparar el archivo token real ni validar el manifiesto.
- **Git/GitHub, backup, actualización, KeePass y estado:** existen interfaces/código; no se verificaron contra repositorios, herramientas o credenciales reales.
- **Guardian/AutoLaunch/AutoClose:** no implementados en los archivos activos encontrados.

## Riesgos de seguridad y preservación

1. La verificación del token depende de una constante compilada en el script, sin firma del launcher; editar conjuntamente script y hash elimina la garantía de autenticidad.
2. `Security\Authentication.ps1` crea la recovery key y la muestra una vez, pero la guarda junto a la configuración (`Config\recovery.json`). Está separada de `auth.json`, no de la unidad; no hay permisos reforzados ni rotación completa evidenciada.
3. El bloqueo progresivo nuevo persiste fallos en `lockout.json`, pero su política/serialización, límites, continuidad entre sesiones y manejo de fallos no se ejecutaron. No se debe migrar credenciales ni lockout automáticamente.
4. El auth heredado convierte SecureString a texto administrado para PBKDF2; el texto se pone a `$null`, lo cual no garantiza borrado de memoria. En el bloque catch se muestra `Exception.Message`, que puede revelar detalles internos.
5. Existen dos esquemas de autenticación incompatibles; regenerar `auth.json` o asumir formato nuevo podría bloquear al usuario.
6. El actualizador opera directamente sobre el checkout Git y no ofrece verificación criptográfica ni rollback integral.
7. Hay riesgo de confundir rutas USB y rutas dentro de `DevKey`; cualquier reparación/migración puede crear carpetas en una ubicación inesperada.
8. `Logs\devkey.log` incluye rutas absolutas de sesiones anteriores. No contiene contraseñas en el fragmento inspeccionado, pero retiene nombres/rutas de usuario y unidad.
9. Git y módulos de credenciales operan con configuración del host además de la portable; deben revisarse antes de cambiar configuración global o borrar credenciales.
10. Los perfiles, proyectos, archivos de backup, configuración y cualquier `auth.json` fuera de la copia visible deben preservarse sin sobrescritura.

## Plan propuesto de migración

1. Congelar este inventario como referencia y, antes de editar código, crear una copia fechada de **todos** los archivos actuales que se vayan a tocar, incluyendo Core y Security actuales; verificar recuento y hashes del backup.
2. Confirmar con el dispositivo conectado las ubicaciones reales de `unlock.k3y`, `auth.json`, Apps, Data, Projects, Logs y Backups. No ejecutar reparación de estructura para “completar” rutas antes de resolver si los datos viven en la raíz USB o dentro de DevKey.
3. Elegir una sola fuente de rutas/configuración y fijar compatibilidad con la ubicación actual de datos; documentar cualquier migración como copia verificable, sin borrado del original.
4. Extraer la lógica del launcher por etapas, manteniendo el flujo heredado hasta verificar el formato real de auth y disponer de procedimiento de reversión. Convertir los scripts de menú en módulos de carga sin efectos secundarios.
5. Unificar logging y autenticación tras pruebas de compatibilidad en una copia aislada; preservar los archivos originales y nunca recrear auth de forma silenciosa.
6. Migrar menús/capacidades que funcionen; separar Git, proyectos, procesos y mantenimiento. No presentar acciones solamente visuales como implementadas.
7. Añadir Guardian solo después de disponer de una identidad de volumen confiable, un registro de procesos por sesión y una prueba de cierre cooperativo en entorno descartable.
8. Ejecutar y documentar pruebas por fase, incluida la comprobación en PowerShell 5.1. Incorporar manifest firmado o mecanismo de confianza antes de atribuir valor de seguridad a hashes regenerables.

## Resultado de Fase 0

La auditoría está documentada. No se avanzó a reconstrucción ni se modificó código. Antes de Fase 1 faltan la unidad original/token para confirmar datos y el respaldo fechado del conjunto exacto que vaya a cambiarse.
