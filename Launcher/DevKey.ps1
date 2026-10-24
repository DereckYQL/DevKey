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
    'DevKey.Profiles.ps1','DevKey.backup.ps1','DevKey.GitX.ps1','DevKey.GitCreds.ps1','DevKey.OS.ps1'
)
foreach($moduleFile in $moduleFiles){
    $modulePath=Join-Path $script:ModulesRoot $moduleFile
    if(-not(Test-Path -LiteralPath $modulePath -PathType Leaf)){throw "Required module is missing: Modules\$moduleFile"}
    . $modulePath
}

$script:DevKeySessionId=[guid]::NewGuid().ToString('N')
$script:DevKeyAuthenticated=$false
$script:DevKeyPinnedTokenSha256='D951A21327821CD2DF020D70B8631AC9E8AA90C7605AFCC7F8F145389CE2BD7B'

function Pause { Pause-DevKey }
function Show-SystemInfo { Show-DevKeySystemInfo }
function Get-DevKeyDisplayStatus {
    $token=Test-DevKeyPhysicalToken
    $integrity=Get-DevKeyIntegrityStatus
    $integrityText=if($integrity.Status -eq 'UNSIGNED-LOCAL'){'LOCAL'}elseif($integrity.Status -eq 'UNCONFIGURED'){'PENDING'}elseif($integrity.Status -eq 'MISMATCH'){'ERROR'}else{$integrity.Status}
    return [pscustomobject]@{Token=$token;Integrity=$integrityText;Auth=$script:DevKeyAuthenticated}
}
function Show-DevKeyFrame {
    Clear-Host
    $status=Get-DevKeyDisplayStatus
    $accent='Cyan'
    try { $Host.UI.RawUI.BackgroundColor='DarkBlue';$Host.UI.RawUI.ForegroundColor='Gray' } catch { }
    Clear-Host
    Write-Host ''
    Write-Host '  DEVKEY  PORTABLE DEV ENVIRONMENT' -ForegroundColor $accent
    Write-Host '  ----------------------------------------------------------------' -ForegroundColor Blue
    Write-Host ('  Version {0}  |  {1}' -f (Get-DevKeyVersion),$script:DevKeyRoot) -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  [1] Open Software' -ForegroundColor White
    Write-Host '  [2] GitHub' -ForegroundColor White
    Write-Host '  [3] Projects' -ForegroundColor White
    Write-Host '  [4] System Status' -ForegroundColor White
    Write-Host '  [5] Maintenance' -ForegroundColor White
    Write-Host '  [6] Security / DevKey Vault' -ForegroundColor White
    Write-Host '  [7] System Information' -ForegroundColor White
    Write-Host '  [0] Exit' -ForegroundColor DarkGray
    $tokenText=if($status.Token){'OK'}else{'ERROR'}
    $authText=if($status.Auth){'OK'}else{'PENDING'}
    Write-Host ''
    Write-Host '  ----------------------------------------------------------------' -ForegroundColor Blue
    Write-Host ("  USB: {0}  |  INTEGRITY: {1}  |  AUTH: {2}" -f $tokenText,$status.Integrity,$authText) -ForegroundColor $(if(-not $status.Token -or $status.Integrity -eq 'ERROR'){'Red'}else{$accent})
    Write-Host ''
}
function Show-SoftwareMenu {
    $software=@(
        [pscustomobject]@{Key='1';Name='Kiro';Description='Portable coding assistant';Action='Kiro'},
        [pscustomobject]@{Key='2';Name='OpenCode';Description='Terminal coding agent';Action='OpenCode'},
        [pscustomobject]@{Key='3';Name='TryOmarchy';Description='Pending configuration';Action='TryOmarchy'},
        [pscustomobject]@{Key='4';Name='Docker';Description='Docker Desktop / engine';Action='Docker'}
    )
    while($true){
        Clear-Host
        Write-Host '  DEVKEY  PORTABLE DEV ENVIRONMENT' -ForegroundColor Cyan
        Write-Host '  ----------------------------------------------------------------' -ForegroundColor Blue
        Write-Host '  OPEN SOFTWARE' -ForegroundColor White
        Write-Host ''
        foreach($tool in $software){Write-Host ("  [{0}] {1,-12} {2}" -f $tool.Key,$tool.Name,$tool.Description) -ForegroundColor White}
        Write-Host '  [0] Return to Main Menu' -ForegroundColor DarkGray
        Write-Host ''
        $choice=Read-Host '  Select a tool'
        if($choice -eq '0'){return}
        $selected=$software|Where-Object{$_.Key -eq $choice}|Select-Object -First 1
        if(-not $selected){Write-Host '  Invalid selection. Choose 1-4 or 0.' -ForegroundColor Yellow;Start-Sleep -Seconds 1;continue}
        switch($selected.Action){
            {$_ -in 'Kiro','OpenCode'} {
                if(Confirm-DevKeyOperationalIntegrity){[void](Start-DevKeyApplication -Name $selected.Action)}
                Pause-DevKey
            }
            'TryOmarchy' {
                Write-Host '  TryOmarchy is pending configuration. No executable or launch procedure is configured.' -ForegroundColor Yellow
                Pause-DevKey
            }
            'Docker' { Invoke-DevKeyDocker;Pause-DevKey }
        }
    }
}
function Show-DevKeyStatus {
    Clear-Host
    Write-Host '  DEVKEY  PORTABLE DEV ENVIRONMENT' -ForegroundColor Cyan
    Write-Host '  ----------------------------------------------------------------' -ForegroundColor Blue
    Write-Host '  SYSTEM STATUS' -ForegroundColor White
    Write-Host ''
    Get-DevKeyDashboard | Format-Table -AutoSize
    Pause-DevKey
}
function Invoke-DevKeyDocker {
    $dockerPath=Get-DevKeyApplicationPath -Name Docker
    if(-not $dockerPath){Write-Host '  Docker is unavailable: no configured Docker executable was found.' -ForegroundColor Yellow;return $false}
    if(-not(Confirm-DevKeyOperationalIntegrity)){return $false}
    $dockerCli=Get-Command 'docker.exe','docker' -ErrorAction SilentlyContinue|Select-Object -First 1
    $desktop=[IO.Path]::GetFileName($dockerPath) -ieq 'Docker Desktop.exe'
    $engineReady=$false
    if($dockerCli){
        try { & $dockerCli.Source info *> $null; $engineReady=($LASTEXITCODE -eq 0) } catch { $engineReady=$false }
    }
    if($engineReady){
        Write-Host '  Docker executable and engine are available.' -ForegroundColor Green
        if($desktop){
            try { Start-Process -FilePath $dockerPath -WorkingDirectory (Split-Path -Parent $dockerPath) -ErrorAction Stop;Write-Host '  Docker Desktop opened.' -ForegroundColor Green;return $true }
            catch { Write-Host ("  Docker Desktop could not be opened: {0}" -f $_.Exception.Message) -ForegroundColor Red;return $false }
        }
        Write-Host ("  Docker CLI: {0}" -f $dockerCli.Source) -ForegroundColor Cyan
        return $true
    }
    if($desktop){
        try { Start-Process -FilePath $dockerPath -WorkingDirectory (Split-Path -Parent $dockerPath) -ErrorAction Stop;Write-Host '  Docker Desktop opened. The engine was not running; DevKey did not enable or reconfigure services.' -ForegroundColor Yellow;return $true }
        catch { Write-Host ("  Docker Desktop could not be opened: {0}" -f $_.Exception.Message) -ForegroundColor Red;return $false }
    }
    if(-not $dockerCli){Write-Host '  Docker executable was found, but docker.exe is not available to check the engine.' -ForegroundColor Yellow}
    else{Write-Host '  Docker CLI is installed, but the engine is not responding. Start Docker Desktop or its configured engine, then try again.' -ForegroundColor Yellow}
    return $false
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
        $option=Read-Host 'Select an option'
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
                default { Write-Host 'Invalid selection. Choose one of the listed options.' -ForegroundColor Yellow;Start-Sleep -Seconds 1 }
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
