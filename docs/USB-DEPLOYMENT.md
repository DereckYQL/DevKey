# Despliegue aprobado a la USB

El repositorio es la fuente de desarrollo; la USB es el entorno operativo. Esta
rama no modifica la USB física. No desplegar hasta revisar el PR y validar en
Windows PowerShell 5.1. No reemplazar `D:\DevKey` completo.

## Preparar la versión

En el equipo Windows, desde una carpeta de trabajo fuera de la USB:

```powershell
git clone --branch feature/devkey-terminal-redesign https://github.com/DereckYQL/DevKey.git DevKey-review
Set-Location .\DevKey-review
git status --short
git log -1 --oneline
```

Compara el commit con el aprobado en el PR. También puedes descargar el ZIP de
esa rama desde GitHub y extraerlo fuera de la USB; comprueba la revisión antes de
copiar. Después de integrar el PR, usa el commit aprobado de `devkey-usb-source`.
No uses `main`, cuyo contenido no es el proyecto operativo.

## Respaldar y comprobar requisitos

Cierra DevKey, Kiro, OpenCode y KeePass de manera normal. Guarda cambios antes de
cerrarlos. Usa un destino de backup privado, preferentemente un volumen cifrado
separado de la USB. Ejemplo: `E:\DevKeyBackups` (debe existir y ser confiable).

```powershell
$stamp = Get-Date -Format yyyyMMdd-HHmmss
$backup = Join-Path 'E:\DevKeyBackups' $stamp
New-Item -ItemType Directory -Path $backup -ErrorAction Stop | Out-Null
Copy-Item -LiteralPath 'D:\DevKey' -Destination $backup -Recurse -ErrorAction Stop
foreach ($name in @('Data', 'Projects')) {
    $path = Join-Path 'D:\' $name
    if (Test-Path -LiteralPath $path) {
        Copy-Item -LiteralPath $path -Destination $backup -Recurse -ErrorAction Stop
    }
}
if (Test-Path -LiteralPath 'D:\unlock.k3y') {
    Copy-Item -LiteralPath 'D:\unlock.k3y' -Destination $backup -ErrorAction Stop
}
```

Verifica recuentos y hashes de los archivos copiados con `Get-FileHash`; no sigas
si el backup está incompleto. Este respaldo contiene datos privados: no subirlo
a GitHub. Conserva también cualquier ubicación personalizada de Apps, Data,
Projects, Vault y backups establecida por tu instalación.

La copia publicada de la rama fuente omite `Modules\DevKey.backup.ps1` y toda la
configuración privada. Si tu USB tiene ese módulo, consérvalo. Sin él la opción
Backup de Mantenimiento explica la ausencia y no modifica datos. La suite smoke
heredada depende de ese archivo y de fixtures de configuración que faltan.

El hash predeterminado del token en `Core\Bootstrap.ps1` difiere del anclado en el
launcher. No se modifica ninguno en este rediseño. Conserva `Config\config.json`
y el token existentes; si la instalación no supera el control, detén el despliegue
y revisa el enrolamiento con el propietario. No cambies pins ni generes un token
para eludirlo.

## Copiar solo los archivos de aplicación aprobados

Desde la raíz del checkout revisado, en Windows PowerShell:

```powershell
$source = (Get-Location).Path
$target = 'D:\DevKey'
$files = @(
    'Launcher\DevKey.ps1',
    'Modules\DevKey.Menu.ps1',
    'Modules\DevKey.Software.ps1',
    'Modules\Maintenance.ps1',
    'Modules\SystemInfo.ps1'
)
foreach ($file in $files) {
    $from = Join-Path $source $file
    $to = Join-Path $target $file
    if (-not (Test-Path -LiteralPath $from -PathType Leaf)) { throw "Falta $file" }
    if (-not (Test-Path -LiteralPath (Split-Path -Parent $to))) { throw "Destino no válido: $to" }
}
foreach ($file in $files) {
    Copy-Item -LiteralPath (Join-Path $source $file) -Destination (Join-Path $target $file) -ErrorAction Stop
    if ((Get-FileHash -LiteralPath (Join-Path $source $file)).Hash -ne
        (Get-FileHash -LiteralPath (Join-Path $target $file)).Hash) { throw "Copia no verificada: $file" }
}
```

No copiar ni borrar `Config`, `auth.json`, `recovery.json`, `lockout.json`,
`unlock.k3y`, manifiestos, `Apps`, `Data`, `Projects`, `Vault`, `Logs` o `Backups`.
No sustituir `.kdbx`, contraseñas, salts o hashes. El launcher batch existente
`Launcher\DevKey.bat` se conserva sin cambios. No uses `robocopy /MIR`.

Si existe un manifiesto de integridad, el cambio de código debe producir una
alerta hasta que el propietario revise los archivos y use el procedimiento
existente de Mantenimiento para crear un manifiesto local. Conserva el anterior.
No borrar el manifiesto para esquivar la verificación. Un manifiesto local no
certifica el origen de los archivos.

## Validar en Windows

En la copia de desarrollo, con Windows PowerShell 5.1:

```powershell
powershell.exe -NoProfile -File .\Tests\Invoke-DevKeyMenuTests.ps1
powershell.exe -NoProfile -File .\Tests\Invoke-DevKeyTests.ps1
powershell.exe -NoProfile -File .\Tests\Invoke-DevKeySmokeTests.ps1
```

La suite heredada tiene problemas previos documentados en
`docs/ENGINEERING-REPORT.md`; no interpretar un fallo como éxito. Ejecuta smoke
solo cuando estén disponibles sus dependencias originales y revisados sus
fixtures. Las nuevas pruebas no lanzan aplicaciones reales ni cambian servicios.

Abre `D:\DevKey\Launcher\DevKey.bat` de forma normal y verifica:

1. Autenticación existente una sola vez; un fallo impide entrar.
2. Menú principal en el orden solicitado; `[1]` abre Software Manager.
3. Kiro y OpenCode conservan sus datos y directorios de trabajo.
4. TryOmarchy informa que no está configurado.
5. Docker ausente o motor detenido devuelve un aviso. No se instala ni se inicia.
6. `[0]` en Software y Seguridad vuelve con una selección; entradas inválidas no cierran DevKey.
7. GitHub, Projects, estado, mantenimiento e información conservan sus funciones.
8. `[0]` principal cierra la sesión y conserva Guardian y limpieza existentes.

Prueba otra letra de unidad cuando sea seguro hacerlo. El código calcula las
rutas desde los scripts; no cambies las rutas en el fuente. Docker/WSL son
capacidades del equipo anfitrión, no aplicaciones garantizadas por la USB.

## Revertir

Cierra DevKey y las aplicaciones. Restaura desde `$backup\DevKey` únicamente los
archivos de la lista `$files`. Si `DevKey.Software.ps1` no existía antes, retíralo
solo después de restaurar el launcher anterior. No restaures datos privados o
proyectos antiguos sobre datos recientes. Si se aprobó un manifiesto nuevo,
restaura el anterior correspondiente al código anterior mediante el procedimiento
controlado de la instalación. Conserva ambos respaldos hasta validar el rollback.
