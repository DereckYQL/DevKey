function Set-DevKeyGuardianIdentity {
    $identity=Get-DevKeyDriveIdentity -Path $script:UsbRoot
    if(-not $identity -or -not (Test-DevKeyPhysicalToken)){Write-Host 'No se pudo verificar el token y la identidad de la unidad actual.' -ForegroundColor Red;return $false}
    Write-Host ("Unidad: {0}  Serial: {1}  Etiqueta: {2}" -f $identity.Root,$identity.Serial,$identity.Label)
    if((Read-Host 'Registrar esta unidad como identidad autorizada? (S/N)') -notin @('S','s')){return $false}
    $script:DevKeyConfig.Guardian.VolumeSerial=$identity.Serial
    Save-DevKeyConfiguration
    Write-DevKeyLog -Log guardian.log -Level AUDIT -Message 'Volume identity configured.'
    Write-Host 'Identidad guardada.' -ForegroundColor Green
    return $true
}

function Test-DevKeyGuardianPresence {
    $expected=[string]$script:DevKeyConfig.Guardian.VolumeSerial
    if(-not $expected){return $false}
    $identity=Get-DevKeyDriveIdentity -Path $script:UsbRoot
    if(-not $identity -or $identity.Serial -cne $expected){return $false}
    if(-not (Test-DevKeyPhysicalToken)){return $false}
    $integrity=Get-DevKeyIntegrityStatus
    if($integrity.Status -in @('MISMATCH','INVALID')){return $false}
    return $true
}

function Start-DevKeyGuardianWorker {
    if(-not $script:DevKeyConfig.Guardian.Enabled){Write-Host 'Guardian esta desactivado en Config\config.json.' -ForegroundColor Yellow;return $null}
    if(-not $script:DevKeyConfig.Guardian.VolumeSerial){Write-Host 'Registra la identidad de volumen desde Mantenimiento antes de iniciar Guardian.' -ForegroundColor Yellow;return $null}
    if(-not(Test-DevKeyGuardianPresence)){Write-Host 'No se puede validar la unidad o el manifiesto.' -ForegroundColor Red;return $null}
    if($script:DevKeyGuardianWorker -and -not $script:DevKeyGuardianWorker.HasExited){Write-Host 'Guardian ya esta activo.' -ForegroundColor Green;return $script:DevKeyGuardianWorker}
    $worker=Join-Path $script:GuardianRoot 'Guardian.ps1'
    if(-not(Test-Path -LiteralPath $worker -PathType Leaf)){Write-Host 'Falta Guardian\Guardian.ps1.' -ForegroundColor Red;return $null}
    $hostPath=Join-Path $PSHOME 'powershell.exe'
    $argLine='-NoProfile -File "{0}" -ParentProcessId {1} -SessionId {2}' -f $worker,$PID,$script:DevKeySessionId
    try {
        $script:DevKeyGuardianWorker=Start-Process -FilePath $hostPath -ArgumentList $argLine -WorkingDirectory $script:DevKeyRoot -PassThru -ErrorAction Stop
        Write-DevKeyLog -Log guardian.log -Level INFO -Message ("Visible Guardian worker started (PID $($script:DevKeyGuardianWorker.Id)).")
        Write-Host 'Guardian se inicio en una ventana visible.' -ForegroundColor Green
        return $script:DevKeyGuardianWorker
    } catch { Write-DevKeyLog -Log guardian.log -Level ERROR -Message ('Guardian launch failed: '+$_.Exception.GetType().Name);Write-Host 'No se pudo iniciar Guardian.' -ForegroundColor Red;return $null }
}

function Stop-DevKeyGuardianWorker {
    if(-not $script:DevKeySessionId){return}
    $stopPath=Join-Path $script:RuntimeRoot ('guardian-stop-'+$script:DevKeySessionId+'.flag')
    try { Set-Content -LiteralPath $stopPath -Value 'stop' -Encoding ASCII -ErrorAction Stop } catch { }
    if($script:DevKeyGuardianWorker){try{[void]$script:DevKeyGuardianWorker.WaitForExit(4000)}catch{}}
    Remove-Item -LiteralPath $stopPath -Force -ErrorAction SilentlyContinue
}

function Start-DevKeyGuardian {
    $null=Start-DevKeyGuardianWorker
}
function Enable-DevKeyAutoLaunch {
    if($script:DevKeyConfig.Guardian.AutoLaunch){Write-Host 'AutoLaunch ya aparece habilitado en Config.' -ForegroundColor Yellow;return $false}
    $identity=Get-DevKeyDriveIdentity -Path $script:UsbRoot
    if(-not $identity -or -not(Test-DevKeyPhysicalToken)){Write-Host 'Verifica primero token e identidad de volumen.' -ForegroundColor Red;return $false}
    if($script:DevKeyConfig.Guardian.VolumeSerial -cne $identity.Serial){Write-Host 'Registra primero esta identidad desde Mantenimiento.' -ForegroundColor Yellow;return $false}
    Write-Host 'Esto instala un watcher VISIBLE para tu usuario actual.' -ForegroundColor Yellow
    Write-Host 'Se copiaran dos archivos a LocalAppData y se agregara una entrada Run de HKCU.'
    Write-Host 'El watcher pide la autenticacion normal al iniciar DevKey y se puede desinstalar desde este menu.'
    if((Read-Host 'Continuar con la instalacion de AutoLaunch? (S/N)') -notin @('S','s')){return $false}
    $hostRoot=Join-Path $env:LOCALAPPDATA 'DevKey\Guardian'
    $hostScript=Join-Path $hostRoot 'HostWatcher.ps1'
    $hostConfig=Join-Path $hostRoot 'host-config.json'
    $runKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $property='DevKeyGuardian'
    if(-not(Test-Path -LiteralPath $runKey)){New-Item -Path $runKey -Force|Out-Null}
    $existing=(Get-ItemProperty -LiteralPath $runKey -Name $property -ErrorAction SilentlyContinue).$property
    if($existing -and $existing.IndexOf($hostScript,[StringComparison]::OrdinalIgnoreCase) -lt 0){Write-Host 'Ya existe un valor DevKeyGuardian que no pertenece al watcher actual; no se reemplazo.' -ForegroundColor Yellow;return $false}
    $source=Join-Path $script:GuardianRoot 'HostWatcher.ps1'
    if(-not(Test-Path -LiteralPath $source -PathType Leaf)){Write-Host 'Falta Guardian\HostWatcher.ps1.' -ForegroundColor Red;return $false}
    try {
        if(-not(Test-Path -LiteralPath $hostRoot -PathType Container)){New-Item -ItemType Directory -Path $hostRoot -Force|Out-Null}
        $stamp=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
        foreach($path in @($hostScript,$hostConfig)){if(Test-Path -LiteralPath $path -PathType Leaf){Copy-Item -LiteralPath $path -Destination ($path+'.'+$stamp+'.bak') -ErrorAction Stop}}
        Copy-Item -LiteralPath $source -Destination $hostScript -Force -ErrorAction Stop
        $hostSettings=[ordered]@{Enabled=$true;VolumeSerial=$identity.Serial;TokenSha256=$script:DevKeyConfig.Security.TokenSha256;AutoClose=[bool]$script:DevKeyConfig.Guardian.AutoClose;LogEvents=[bool]$script:DevKeyConfig.Guardian.LogEvents;ForceCloseOnRemoval=[bool]$script:DevKeyConfig.Guardian.ForceCloseOnRemoval;ForceCloseAfterSeconds=[int]$script:DevKeyConfig.Guardian.ForceCloseAfterSeconds}
        $hostSettings|ConvertTo-Json|Set-Content -LiteralPath $hostConfig -Encoding UTF8 -ErrorAction Stop
        $command='"{0}" -NoProfile -File "{1}"' -f (Join-Path $PSHOME 'powershell.exe'),$hostScript
        Set-ItemProperty -LiteralPath $runKey -Name $property -Value $command -ErrorAction Stop
        $script:DevKeyConfig.Guardian.AutoLaunch=$true
        Save-DevKeyConfiguration
        Write-DevKeyLog -Log guardian.log -Level AUDIT -Message 'Visible current-user AutoLaunch watcher installed.'
        Write-Host 'AutoLaunch instalado para el inicio de sesion actual.' -ForegroundColor Green
        return $true
    } catch {
        Remove-ItemProperty -LiteralPath $runKey -Name $property -ErrorAction SilentlyContinue
        $script:DevKeyConfig.Guardian.AutoLaunch=$false
        Write-DevKeyLog -Log guardian.log -Level ERROR -Message ('AutoLaunch installation failed: '+$_.Exception.GetType().Name)
        Write-Host 'No se pudo completar AutoLaunch. Revisa el estado de los archivos locales.' -ForegroundColor Red
        return $false
    }
}
function Disable-DevKeyAutoLaunch {
    if(-not $script:DevKeyConfig.Guardian.AutoLaunch){Write-Host 'AutoLaunch ya esta desactivado.';return $true}
    if((Read-Host 'Quitar el inicio automatico visible de este usuario? (S/N)') -notin @('S','s')){return $false}
    $runKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';$property='DevKeyGuardian'
    $existing=(Get-ItemProperty -LiteralPath $runKey -Name $property -ErrorAction SilentlyContinue).$property
    $ownedScript=Join-Path $env:LOCALAPPDATA 'DevKey\Guardian\HostWatcher.ps1'
    if($existing -and $existing.IndexOf($ownedScript,[StringComparison]::OrdinalIgnoreCase) -lt 0){Write-Host 'El valor de inicio no apunta al watcher de DevKey; no se modifico.' -ForegroundColor Red;return $false}
    if($existing){Remove-ItemProperty -LiteralPath $runKey -Name $property -ErrorAction Stop}
    $script:DevKeyConfig.Guardian.AutoLaunch=$false
    Save-DevKeyConfiguration
    $hostRoot=Join-Path $env:LOCALAPPDATA 'DevKey\Guardian'
    foreach($file in @('HostWatcher.ps1','host-config.json')){Remove-Item -LiteralPath (Join-Path $hostRoot $file) -Force -ErrorAction SilentlyContinue}
    Write-DevKeyLog -Log guardian.log -Level AUDIT -Message 'Visible AutoLaunch watcher removed.'
    Write-Host 'AutoLaunch desinstalado. El log local se conservo.' -ForegroundColor Green
    return $true
}
function Get-DevKeyGuardianStatus {
    if(-not $script:DevKeyConfig.Guardian.Enabled){return 'DESACTIVADO'}
    if(-not $script:DevKeyConfig.Guardian.VolumeSerial){return 'IDENTIDAD NO CONFIGURADA'}
    if(Test-DevKeyGuardianPresence){return 'CONFIGURADO / UNIDAD PRESENTE'}
    return 'CONFIGURADO / UNIDAD NO VERIFICADA'
}
