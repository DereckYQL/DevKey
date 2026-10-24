param()

$ErrorActionPreference='Stop'
$script:LauncherPath=$PSScriptRoot
$coreRoot=Join-Path (Split-Path -Parent $PSScriptRoot) 'Core'
. (Join-Path $coreRoot 'PathManager.ps1')
Initialize-DevKeyPaths
. (Join-Path $script:CoreRoot 'Bootstrap.ps1')
. (Join-Path $script:CoreRoot 'ErrorHandler.ps1')
. (Join-Path $script:CoreRoot 'ProcessManager.ps1')
. (Join-Path $script:SecurityRoot 'Authentication.ps1')
. (Join-Path $script:SecurityRoot 'Integrity.ps1')
. (Join-Path $script:SecurityRoot 'SecurityAudit.ps1')
. (Join-Path $script:GuardianRoot 'GuardianManager.ps1')

$moduleFiles=@(
    'Applications.ps1','Projects.ps1','GitManager.ps1','Maintenance.ps1','SystemInfo.ps1','Templates.ps1','PromptLibrary.ps1',
    'DevKey.Menu.ps1','DevKey.Software.ps1','DevKey.Profiles.ps1','DevKey.GitX.ps1','DevKey.GitCreds.ps1','DevKey.OS.ps1'
)
foreach($moduleFile in $moduleFiles){
    $modulePath=Join-Path $script:ModulesRoot $moduleFile
    if(-not(Test-Path -LiteralPath $modulePath -PathType Leaf)){throw "Required module is missing: Modules\$moduleFile"}
    . $modulePath
}

# The USB export omitted the backup module; retain it when supplied locally.
$backupModule=Join-Path $script:ModulesRoot 'DevKey.backup.ps1'
if(Test-Path -LiteralPath $backupModule -PathType Leaf){. $backupModule}

$script:DevKeySessionId=[guid]::NewGuid().ToString('N')
$script:DevKeyAuthenticated=$false
$script:DevKeyPinnedTokenSha256='D951A21327821CD2DF020D70B8631AC9E8AA90C7605AFCC7F8F145389CE2BD7B'

function Pause { Pause-DevKey }
function Show-SystemInfo { Show-DevKeySystemInfo }
function Get-DevKeyDisplayStatus {
    $token=Test-DevKeyPhysicalToken
    $integrity=Get-DevKeyIntegrityStatus
    $integrityText=if($integrity.Status -eq 'UNSIGNED-LOCAL'){'LOCAL'}elseif($integrity.Status -eq 'UNCONFIGURED'){'PENDIENTE'}elseif($integrity.Status -eq 'MISMATCH'){'ERROR'}else{$integrity.Status}
    return [pscustomobject]@{Token=$token;Integrity=$integrityText;Auth=$script:DevKeyAuthenticated}
}
function Confirm-DevKeyOperationalIntegrity {
    $status=Get-DevKeyIntegrityStatus
    if($status.Status -eq 'MISMATCH' -or $status.Status -eq 'INVALID'){
        Write-Host 'La verificacion de integridad detecto cambios. La accion se cancelo.' -ForegroundColor Red
        Show-DevKeyIntegrity
        Pause-DevKey
        return $false
    }
    return $true
}
function Invoke-DevKeyAuthenticationGate {
    if(-not (Test-DevKeyPhysicalToken)){
        Write-Host 'No se encontro el token esperado o su SHA-256 no coincide.' -ForegroundColor Red
        Write-Host "Ruta esperada: $script:KeyFile"
        Write-Host 'El token no se recrea ni se reemplaza automaticamente.' -ForegroundColor Yellow
        return $false
    }
    if($script:DevKeyConfig.Security.TokenSha256.ToUpperInvariant() -cne $script:DevKeyPinnedTokenSha256){
        Write-Host 'El hash configurado no coincide con el valor anclado en el launcher.' -ForegroundColor Red
        return $false
    }
    $integrity=Get-DevKeyIntegrityStatus
    if($integrity.Status -eq 'MISMATCH' -or $integrity.Status -eq 'INVALID'){
        Write-Host 'El manifiesto existente no coincide. Solo se habilita verificacion y mantenimiento.' -ForegroundColor Red
        Show-DevKeyIntegrity
    }
    if(-not(Test-Path -LiteralPath $script:AuthFile -PathType Leaf)){
        try { $script:DevKeyAuthenticated=Initialize-DevKeyAuthentication;return $script:DevKeyAuthenticated }
        catch { Write-DevKeyLog -Log error.log -Level ERROR -Message ('Authentication initialization failed: '+$_.Exception.GetType().Name);Write-Host 'No se pudo configurar la autenticacion. El archivo existente no se modifico.' -ForegroundColor Red;return $false }
    }
    try {
        $script:DevKeyAuthenticated=Test-DevKeyAuthentication
        if(-not $script:DevKeyAuthenticated -and (Test-Path -LiteralPath (Join-Path $script:ConfigRoot 'recovery.json'))){
            if((Read-Host 'Acceso no concedido. Intentar recuperacion? (S/N)') -in @('S','s')){$script:DevKeyAuthenticated=Invoke-DevKeyRecovery}
        }
        return $script:DevKeyAuthenticated
    }
    catch {
        Write-Host 'No se pudo validar la autenticacion. El archivo auth.json se conserva.' -ForegroundColor Red
        if(Test-Path -LiteralPath (Join-Path $script:ConfigRoot 'recovery.json')){
            if((Read-Host 'Intentar recuperacion? (S/N)') -in @('S','s')){$script:DevKeyAuthenticated=Invoke-DevKeyRecovery;return $script:DevKeyAuthenticated}
        }
        return $false
    }
}

try {
    Import-DevKeyConfiguration
    if($script:DevKeyConfig.Security.TokenSha256.ToUpperInvariant() -cne $script:DevKeyPinnedTokenSha256){throw 'Security.TokenSha256 differs from the pinned launcher value.'}
} catch {
    Clear-Host
    Write-Host 'DEVKEY: CONFIGURACION NO VALIDA' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host 'No se sobrescribio la configuracion existente.'
    [void](Read-Host 'Pulsa ENTER para salir')
    return
}

$configuredGit=Get-DevKeyApplicationPath -Name Git
if($configuredGit){$script:GitPath=$configuredGit;Set-Variable -Name GitPath -Value $configuredGit -Scope Script}

Write-DevKeyLog -Level INFO -Message 'Launcher iniciado.'
if(-not(Invoke-DevKeyAuthenticationGate)){
    Write-DevKeyLog -Log access.log -Level AUDIT -Message 'Launcher detenido antes de crear una sesion autenticada.'
    [void](Read-Host 'Acceso no concedido. Pulsa ENTER para salir')
    return
}
if((Get-DevKeyIntegrityStatus).Status -eq 'UNCONFIGURED'){
    Write-Host 'Aviso: no existe manifiesto local de integridad; no se afirma que el codigo este validado.' -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}
if($script:DevKeyConfig.Guardian.Enabled -and $script:DevKeyConfig.Guardian.VolumeSerial){$null=Start-DevKeyGuardianWorker}

Write-DevKeyLog -Log access.log -Level AUDIT -Message 'Sesion DevKey iniciada.'
try {
    while($true){
        Show-DevKeyFrame
        $option=Read-Host 'Selecciona una opción'
        if(-not(Test-DevKeyPhysicalToken)){Write-Host 'La unidad o el token ya no estan disponibles. La sesion se interrumpe.' -ForegroundColor Yellow;Write-DevKeyLog -Log guardian.log -Level AUDIT -Message 'Token lost while main menu was active.';break}
        try {
            switch($option){
                '1' { Show-SoftwareMenu }
                '2' { Show-DevKeyGit }
                '3' { Show-DevKeyProjects }
                '4' { Show-DevKeyStatus }
                '5' { Show-DevKeyMaintenance }
                '6' { Show-DevKeySecurityMenu }
                '7' { Show-DevKeySystemInfo }
                '0' { break }
                default { Write-Host 'Opción no válida. Selecciona una de las opciones indicadas.' -ForegroundColor Yellow;Start-Sleep -Seconds 1 }
            }
        } catch {
            Write-DevKeyLog -Level ERROR -Message ('Menu option '+$option+': '+$_.Exception.GetType().Name)
            Write-Host 'La opcion no se pudo completar; DevKey sigue abierta.' -ForegroundColor Red
            Pause-DevKey
        }
        if($option -eq '0'){break}
    }
} catch {
    Write-DevKeyLog -Level ERROR -Message ('Launcher error: '+$_.Exception.GetType().Name)
    Write-Host 'Se produjo un error en DevKey. Consulta Logs\error.log.' -ForegroundColor Red
    Pause-DevKey
} finally {
    Stop-DevKeyGuardianWorker
    Stop-DevKeyManagedProcesses
    Write-DevKeyLog -Log access.log -Level AUDIT -Message 'Sesion DevKey finalizada.'
}
