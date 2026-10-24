# Informe de ingeniería: terminal DevKey vNext

## Base y alcance

Base: `devkey-usb-source`, commit `dde828911a0f638d311294fbfa31487f20500f12`.
Desarrollo: `feature/devkey-terminal-redesign`. No se modificaron `main`, la rama
fuente, el dispositivo USB ni sus credenciales. El PR apunta a la rama fuente y
no se fusiona automáticamente.

Se revisaron el launcher PS1/BAT, Core (Bootstrap, PathManager, ProcessManager,
ErrorHandler), Security (Authentication, Integrity, SecurityAudit), GuardianManager,
los módulos Menu, Applications, Apps, Maintenance, SystemInfo, Projects,
GitManager y OS, ambas suites existentes, README, AUDIT, IMPLEMENTATION-STATUS,
SECURITY-STATUS y `.gitignore`. Se inventariaron los archivos rastreados y el
historial local disponible para buscar archivos privados y patrones de secretos.

La arquitectura activa autentica en `Launcher/DevKey.ps1`, importa
`Security/SecurityAudit.ps1` para Seguridad y usa `Modules/Applications.ps1` para
Kiro/OpenCode. El antiguo `Modules/Security-Menu.ps1` ejecuta su propio menú al
importarse; permanece fuera del flujo activo. No hay integración ejecutable de
TryOmarchy/Omarchy: la opción queda disponible con el aviso solicitado.

## Cambios

| Archivo | Resultado |
| --- | --- |
| `Launcher/DevKey.ps1` | Importa los módulos visual y de software; conserva un solo bucle principal, autenticación, controles de integridad y limpieza Guardian. Prompts en español. Importa backup si existe localmente. |
| `Modules/DevKey.Menu.ps1` | Renderizado compartido, identidad DEVKEY, orden exacto de opciones, marco cian/azul, fondo oscuro donde se admite, Unicode con fallback ASCII. |
| `Modules/DevKey.Software.ps1` (nuevo) | Registro confiable en código con nombre, descripción, disponibilidad y acción; control de errores por selección; Docker sin instalación ni arranque de Desktop/servicios. |
| `Modules/Maintenance.ps1` | Explica la ausencia del módulo original de backup sin fabricar una implementación ni tocar backups. |
| `Modules/SystemInfo.ps1` | No presenta autenticación correcta si no existe sesión autenticada. |
| `Tests/Invoke-DevKeyMenuTests.ps1` (nuevo) | Pruebas de navegación, registro, lanzadores con mocks, sintaxis de todos los PS1 y timeout de la sonda Docker. |
| `.gitignore` | Conserva las exclusiones existentes; permite plantillas `.env.example`, `.env.template` y `*.example.json` seguras. |
| `README.md` | Entrada al nuevo flujo, pruebas y documentación. |
| `docs/USB-DEPLOYMENT.md` (nuevo) | Backup privado, copia selectiva verificada, conservación de datos/configuración, pruebas y rollback. |
| `docs/ENGINEERING-REPORT.md` (nuevo) | Este informe. |

Funciones nuevas: `Write-DevKeyPanel`, `Get-DevKeySoftwareRegistry`,
`Get-DevKeyDockerCli`, `Test-DevKeyDockerEngine`.
Funciones adaptadas/reubicadas: `Show-DevKeyMainMenu`, `Show-DevKeyFrame`,
`Show-SoftwareMenu`, `Show-DevKeyStatus`, `Invoke-DevKeyDocker`.

Se reutilizan sin alterar sus implementaciones `Start-DevKeyApplication`,
`Get-DevKeyApplicationPath`, `Start-DevKeyManagedProcess`, `Pause-DevKey`,
`Invoke-DevKeyAuthenticationGate`, `Confirm-DevKeyOperationalIntegrity`,
`Show-DevKeyGit`, `Show-DevKeyProjects`, `Show-DevKeyMaintenance`,
`Show-DevKeySecurityMenu`, `Show-DevKeySystemInfo` y la resolución de rutas.
Kiro conserva `--user-data-dir`, OpenCode conserva `XDG_CONFIG_HOME` y ambos su
directorio de trabajo y supervisión de procesos. El BAT no cambia.

Docker usa la CLI configurada, la CLI junto a Desktop o la de PATH; respeta
`Enabled`. Ejecuta únicamente `docker info`, con espera de cinco segundos como
máximo por proceso. Drena ambas salidas y no muestra sus contenidos. Un timeout
termina solo la sonda iniciada por DevKey. No instala ni configura runtimes,
servicios, WSL, contenedores o procesos privilegiados.

## Validación ejecutada

Entorno real: Linux, PowerShell **7.4.6** descargado de la publicación oficial y
verificado contra su manifiesto SHA-256. No hay Windows PowerShell 5.1 ni USB
física. Se usaron directorios XDG/TEMP de prueba, fuera del checkout.

| Comando | Resultado observado |
| --- | --- |
| `pwsh -NoProfile -File Tests/Invoke-DevKeyMenuTests.ps1` | **48 aprobadas, 0 fallidas**, incluida sintaxis de todos los PS1. |
| `pwsh -NoProfile -File Tests/Invoke-DevKeyTests.ps1` | **9 aprobadas, 2 fallidas**, salida 1. |
| Mismo comando sobre una copia intacta del commit base | **9 aprobadas, las mismas 2 fallidas**, salida 1. |
| `pwsh -NoProfile -File Tests/Invoke-DevKeySmokeTests.ps1` | Abortada antes de assertions: falta `Modules/DevKey.backup.ps1`, salida 1. |
| `git diff --check` | Sin errores de whitespace. |

Las dos assertions heredadas fallidas son `local manifest reports unsigned
status when matching` e `integrity detects changed file`. Su fixture omite
`Version=1` y `Trust=UNSIGNED-LOCAL`, exigidos por el verificador actual. Además,
el verificador usa separadores Windows al comprobar el prefijo del directorio,
por lo que esas pruebas no validan integridad real en Linux. No se alteró el
verificador ni se desactivaron assertions para conseguir un resultado verde.

Smoke depende también de configuración no exportada y contiene una secuencia de
opciones del menú anterior; requiere mantenimiento separado con los originales.
No se inventó el módulo faltante. La aplicación puede usar el módulo local si la
USB lo conserva; la funcionalidad de backups no se declara verificada.

Las 48 pruebas cubren el orden y etiquetas, registro extensible, volver con cero,
entrada inválida, excepciones, integridad denegada, rutas relativas, argumentos
Kiro, entorno OpenCode y restauración, CLI Docker configurada, rutas principales,
una llamada al verificador de autenticación con mocks, retorno de Seguridad y
limpieza. En Linux prueban además la sonda con procesos auxiliares de salida cero,
no cero, inexistentes y lentos. Esas cinco assertions auxiliares se omiten en
Windows; las otras 43 están diseñadas para PowerShell 5.1. Los lanzamientos reales,
la autenticación interactiva y las operaciones reales GitHub/Projects/Vault no se
ejecutaron; sus rutas se comprobaron con mocks. No afirmar validación Windows.

## Seguridad y pendientes

- No se cambiaron Authentication, Integrity, hashes/salts, pin del launcher,
  Guardian, formato de configuración ni el BAT. No se crearon claves ni vaults.
- El hash predeterminado de Bootstrap difiere del pin del launcher en la base.
  Una instalación nueva sin configuración privada se detendrá por ese control.
  **Bloqueo previo al despliegue**: revisar con el propietario el enrolamiento
  real. No se cambiaron valores de seguridad para eludirlo.
- La fuente publicada no contiene configuración privada ni módulo de backup.
  Conservar los originales operativos. No es una instalación USB completa.
- No se encontraron archivos de credenciales privados rastreados ni secretos
  reales confirmados en el historial local revisado. Las coincidencias de tokens
  en `Tests/Invoke-DevKeySmokeTests.ps1` son fixtures explícitos de redacción de
  logs/URLs. No se imprimieron sus valores. La revisión por patrones no garantiza
  que todo secreto posible sea detectable; no cubre refs remotos no disponibles.
- `.gitignore` no elimina contenido del historial. Si aparece una credencial real,
  revocarla/rotarla, retirarla del árbol y coordinar limpieza del historial y copias.
- Los PS1 modificados/nuevos con texto Unicode llevan BOM UTF-8 para la lectura
  de Windows PowerShell 5.1. No se introduce sintaxis exclusiva de PowerShell 7.
- Quedan por validar en Windows 5.1: consola y fuentes reales, autenticación
  interactiva, launcher BAT, aplicaciones, hardware USB, otras letras, Guardian,
  Vault y conectividad real GitHub/Docker. No hay afirmación de aceptación completa.

Para desplegar a `D:\DevKey`, seguir `USB-DEPLOYMENT.md`: revisar el commit,
respaldar fuera de la USB, copiar solo los cinco archivos de aplicación indicados,
conservar todo dato privado, revisar el manifiesto con el procedimiento existente
y comprobar el flujo real. No reemplazar la USB ni fusionar el PR automáticamente.
