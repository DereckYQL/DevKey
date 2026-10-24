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
| `Tests/Invoke-DevKeySmokeTests.ps1` | Fixture de configuración generado sin Config del checkout; recorrido vNext real y casos negativos aislados con timeout. |
| `Tests/Fixtures/Invoke-LauncherFixture.ps1` (nuevo) | Consola programada que verifica prompt, función llamadora, respuesta segura y consumo exacto; impide ejecutar aplicaciones externas. |
| `Tests/Invoke-DevKeyTests.ps1` | Corrige Version/Trust del manifiesto temporal y añade pruebas de rechazo de metadatos inválidos. |
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

## Validación ejecutada tras corregir las fixtures

Entorno real: Linux, PowerShell **7.4.6** descargado de la publicación oficial y
verificado contra su manifiesto SHA-256. No hay Windows PowerShell 5.1 ni USB
física. Se ejecutaron las tres suites disponibles después de los cambios:

| Comando | Aprobadas | Fallidas | Omitidas explícitamente | Salida |
| --- | ---: | ---: | ---: | ---: |
| `pwsh -NoProfile -File Tests/Invoke-DevKeyMenuTests.ps1` | 48 | 0 | 0 | 0 |
| `pwsh -NoProfile -File Tests/Invoke-DevKeyTests.ps1` | 11 | 0 | 2 | 0 |
| `pwsh -NoProfile -File Tests/Invoke-DevKeySmokeTests.ps1` | 77 | 0 | 6 | 0 |

La suite Menu incluye sintaxis de todos los PS1, incluido el nuevo helper.
`git diff --check` y la revisión de secretos de las modificaciones no detectaron
problemas. Core, Security, Guardian, Launcher y Modules no cambian en esta
corrección de pruebas. Los resultados omitidos no se cuentan como aprobados.

Las dos assertions heredadas que antes fallaban (`local manifest reports unsigned
status when matching` e `integrity detects changed file`) utilizaban un JSON sin
`Version=1` ni `Trust=UNSIGNED-LOCAL`, obligatorios para el verificador real. La
fixture ahora incluye ambos; el test de alteración también exige que `Changed`
identifique `sample.ps1`. Se conserva una prueba del formato antiguo incompleto y
otra de confianza no admitida: ambos deben devolver `INVALID`.

Las dos comprobaciones positivas de archivos permanecen pendientes en Linux:
el verificador de producción usa contención de rutas Windows. Se omiten solo en
plataformas sin separador Windows, con mensaje y contador explícitos. En Windows
se ejecutan ambas assertions corregidas contra el verificador original, sin mocks,
sin cambiar algoritmos, sin regenerar manifiestos para eludir errores y sin
relajar la contención de rutas. Aún no se afirma que hayan pasado en Windows.

Las seis omisiones de smoke son: dos por el módulo opcional de backup/restauración
no exportado y cuatro por requerir Windows (identidad/cierre de un proceso Windows
PowerShell y manifiesto coincidente/archivo alterado). Cuando están disponibles
las dependencias o la plataforma, las comprobaciones originales siguen activas.
No se ha inventado un módulo de backup ni se ha modificado una USB real.

### Recorrido del launcher con configuración autocontenida

Smoke crea cuatro árboles independientes bajo el directorio temporal del sistema.
Copia únicamente scripts de Launcher/Core/Modules/Security/Guardian y crea Config
con los valores predeterminados del código; **no copia Config desde Git ni desde
la USB**. Cada escenario genera su propio token temporal de 32 bytes. Solo en el
launcher copiado se ancla ese hash, conservando intactos la comparación y los
controles reales. Todas las contraseñas y registros KDF son exclusivos del test.

El escenario Navigation programa la nueva secuencia por función y prompt:
autenticación inicial, entrada inválida principal, opción 1, entrada inválida de
Software, Kiro/OpenCode/TryOmarchy/Docker con sus pausas, Software 0, GitHub 0,
Projects 0, estado, Mantenimiento 0, Seguridad (entrada inválida, estado y 0),
información y salida principal 0. Los prefijos de cada prompt distinguen menú
principal y Software; las funciones llamadoras distinguen los otros submenús que
comparten `Opcion`. Una respuesta cero de más, autenticación repetida, prompt
inesperado o cola sobrante produce un fallo. Las contraseñas no se incluyen en la
traza. Se comprueba que cada ruta llegó a su manejador real y volvió al padre.

Los otros tres escenarios verifican con los controles originales:

- BadToken: un token temporal alterado impide autenticación y entrada al menú;
  no se crea auth.json ni se sustituye el token.
- BadPassword: la contraseña temporal incorrecta impide la sesión y conserva sin
  cambios el registro KDF; se registra un único rechazo.
- InvalidIntegrity: un manifiesto temporal inválido bloquea la acción Kiro en
  `Confirm-DevKeyOperationalIntegrity`, sin ejecutar el placeholder del programa.

Kiro, OpenCode, Node y Docker están deshabilitados en la fixture de navegación
para evitar detección y ejecución de instalaciones del host. Git usa un archivo
placeholder temporal que permite entrar en su menú, sin ejecutar Git. El caso de
integridad habilita únicamente el placeholder Kiro para probar su bloqueo. Guardian
no se inicia en la fixture. Un guard registra y rechaza cualquier Start-Process
inesperado; las funciones de autenticación, token e integridad no se sustituyen.

Cada launcher se ejecuta en un proceso PowerShell separado, con `-NoProfile
-NonInteractive`, un límite de **45 segundos**, presupuesto de prompts y resultado
JSON propio. El padre comprueba finalización, código de salida, resultado de esa
ejecución, errores de nivel ERROR, consumo exacto, ausencia de lanzamientos y
conservación de los bytes del token. La existencia de error.log por mensajes INFO
no se interpreta como un error. La limpieza termina solo el worker que inició el
test si no ha salido y elimina el sandbox en finally. No hay respuestas de reserva
que vuelvan a seleccionar opciones indefinidamente.

### Validación pendiente en Windows PowerShell 5.1

Desde la raíz del checkout de desarrollo, sin conectar la USB ni copiar sus datos:

```powershell
powershell.exe -NoProfile -File .\Tests\Invoke-DevKeyTests.ps1
powershell.exe -NoProfile -File .\Tests\Invoke-DevKeyMenuTests.ps1
powershell.exe -NoProfile -File .\Tests\Invoke-DevKeySmokeTests.ps1
```

Confirmar el código de salida cero y revisar los contadores de omisiones. El
módulo de backup original sigue ausente: sus dos pruebas deben seguir figurando
como SKIP hasta disponer de una copia de desarrollo revisada. Se requiere ejecutar
realmente las assertions de integridad y proceso que Linux omite, y confirmar el
worker/cola en Windows 5.1. El BAT, consola/fuentes, aplicaciones reales, Vault,
servicios externos y Guardian/USB físicos siguen siendo validación manual aparte.
Las cinco sondas auxiliares Unix de la suite Menu no se ejecutan en Windows; no
son validación de Docker real. No se afirma funcionamiento Windows ni aceptación
completa basándose en los resultados Linux.

## Seguridad y pendientes

- No se cambiaron Authentication, Integrity, hashes/salts operativos, pin del launcher original,
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
