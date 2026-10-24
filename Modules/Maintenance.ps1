function Repair-DevKeyStructure {
    $targets=@($script:ConfigRoot,$script:LogsRoot,$script:BackupsRoot,$script:RuntimeRoot,$script:ProjectsRoot)
    $missing=@($targets|Where-Object {-not(Test-Path -LiteralPath $_ -PathType Container)})
    if(-not $missing){Write-Host 'La estructura configurada ya existe.' -ForegroundColor Green;return}
    Write-Host 'Se crearan unicamente estos directorios:' -ForegroundColor Yellow;$missing|ForEach-Object{Write-Host " - $_"}
    if((Read-Host 'Continuar? (S/N)') -notin @('S','s')){return}
    foreach($path in $missing){New-Item -ItemType Directory -Path $path -Force -ErrorAction Stop|Out-Null}
    Write-DevKeyLog -Log maintenance.log -Level AUDIT -Message ('Created directories: '+($missing -join ', '))
    Write-Host 'Estructura reparada sin reemplazar archivos.' -ForegroundColor Green
}
function Show-DevKeyPortableApplications {
    while($true){
        Clear-Host;Write-Host 'APLICACIONES PORTABLES' -ForegroundColor Cyan
        foreach($name in @('Kiro','OpenCode','Git','Node','Docker')){$path=Get-DevKeyApplicationPath $name;if($path){$version='';try{$version=(Get-Item -LiteralPath $path -ErrorAction Stop).VersionInfo.ProductVersion}catch{};Write-Host (" [OK] {0} {1}" -f $name,$(if($version){$version}else{''})) -ForegroundColor Green;Write-Host "      $path" -ForegroundColor DarkGray}else{Write-Host (" [--] {0} no encontrado" -f $name) -ForegroundColor Yellow}}
        $keepass=Get-DevKeyKeePassPath;if($keepass){Write-Host " [OK] KeePass`n      $keepass" -ForegroundColor Green}else{Write-Host ' [--] KeePass no encontrado' -ForegroundColor Yellow}
        Write-Host '';Write-Host ' [1] Abrir carpeta Apps';Write-Host ' [2] Instrucciones de actualizacion manual';Write-Host ' [0] Volver';$o=Read-Host 'Opcion'
        switch($o){
            '1'{if(Test-Path -LiteralPath $script:AppsRoot -PathType Container){Start-Process -FilePath 'explorer.exe' -ArgumentList ('"'+$script:AppsRoot+'"')}else{Write-Host 'La carpeta Apps no existe; no se creo automaticamente.' -ForegroundColor Yellow;Pause-DevKey}}
            '2'{Write-Host 'Usa paquetes obtenidos de fuentes autorizadas. Cierra la aplicacion, respalda sus datos y reemplaza solo su carpeta dentro de Apps.' -ForegroundColor Yellow;Write-Host 'DevKey no instala ni ejecuta actualizaciones descargadas.';Pause-DevKey}
            '0'{return}
            default{Write-Host 'Opcion no valida.';Start-Sleep -Seconds 1}
        }
    }
}
function Show-DevKeyMaintenance {
    while($true){
        Clear-Host;Write-Host 'MANTENIMIENTO' -ForegroundColor Cyan
        Write-Host ' [1] Comprobar archivos';Write-Host ' [2] Comprobar aplicaciones';Write-Host ' [3] Verificar integridad';Write-Host ' [4] Crear manifiesto local';Write-Host ' [5] Reparar estructura';Write-Host ' [6] Cambiar contrasena';Write-Host ' [7] Crear clave de recuperacion';Write-Host ' [8] Configurar identidad Guardian';Write-Host ' [9] Guardian: estado / iniciar';Write-Host ' [10] Configuracion';Write-Host ' [11] Perfiles de proyectos';Write-Host ' [12] Backup / restaurar Projects';Write-Host ' [13] Informacion del sistema';Write-Host ' [14] Aplicaciones portables';Write-Host ' [15] Herramientas del sistema operativo';Write-Host ' [0] Volver'
        $o=Read-Host 'Opcion'
        try {
            switch($o){
                '1'{$paths=@($script:ConfigFile,$script:VersionFile,$script:AuthFile,$script:KeyFile,(Join-Path $script:LauncherRoot 'DevKey.ps1'));foreach($p in $paths){Write-Host ("{0}: {1}" -f $p,(Test-Path -LiteralPath $p))};Pause-DevKey}
                '2'{foreach($n in @('Kiro','OpenCode','Git','Node','Docker')){$p=Get-DevKeyApplicationPath $n;Write-Host ("{0}: {1}" -f $n,$(if($p){$p}else{'FALTANTE'}))};Write-Host ("KeePass: {0}" -f $(if(Get-DevKeyKeePassPath){'DISPONIBLE'}else{'FALTANTE'}));Pause-DevKey}
                '3'{Show-DevKeyIntegrity;Pause-DevKey}
                '4'{New-DevKeyLocalManifest;Pause-DevKey}
                '5'{Repair-DevKeyStructure;Pause-DevKey}
                '6'{Set-DevKeyPassword;Pause-DevKey}
                '7'{New-DevKeyRecoveryKey;Pause-DevKey}
                '8'{Set-DevKeyGuardianIdentity;Pause-DevKey}
                '9'{Write-Host (Get-DevKeyGuardianStatus);if((Read-Host 'Iniciar Guardian en una ventana visible? (S/N)') -in @('S','s')){Start-DevKeyGuardian};Pause-DevKey}
                '10'{Show-DevKeyConfigurationMenu}
                '11'{Show-DevKeyProfilesMenu}
                '12'{if(Get-Command Show-DevKeyBackupMenu -ErrorAction SilentlyContinue){Show-DevKeyBackupMenu}else{Write-Host 'El módulo de backup no está incluido en esta copia. Conserva el módulo original de la USB; no se modificaron los backups.' -ForegroundColor Yellow;Pause-DevKey}}
                '13'{Show-DevKeySystemInfo}
                '14'{Show-DevKeyPortableApplications}
                '15'{Show-DevKeyOSMenu}
                '0'{return}
                default{Write-Host 'Opcion no valida.' -ForegroundColor Yellow;Start-Sleep -Seconds 1}
            }
        }catch{Write-DevKeyLog -Level ERROR -Message ('Maintenance: '+$_.Exception.GetType().Name);Write-Host 'La operacion fallo; consulta Logs\error.log.' -ForegroundColor Red;Pause-DevKey}
    }
}
function Show-DevKeyConfigurationMenu {
    while($true){
        Clear-Host;Write-Host 'CONFIGURACION DEVKEY' -ForegroundColor Cyan
        Write-Host (' Guardian: {0} | AutoClose: {1} | AutoLaunch: {2}' -f $script:DevKeyConfig.Guardian.Enabled,$script:DevKeyConfig.Guardian.AutoClose,$script:DevKeyConfig.Guardian.AutoLaunch)
        Write-Host ' [1] Ver configuracion';Write-Host ' [2] Activar/desactivar Guardian AutoClose';Write-Host ' [3] Activar/desactivar AutoClose de Kiro';Write-Host ' [4] Activar/desactivar AutoClose de OpenCode';Write-Host ' [5] Activar/desactivar cierre forzado al retirar USB';Write-Host ' [6] Instalar/desinstalar AutoLaunch visible';Write-Host ' [7] Cambiar tema';Write-Host ' [8] Cambiar intervalo de Guardian';Write-Host ' [0] Volver'
        $o=Read-Host 'Opcion'
        try {
            switch($o){
                '1'{$script:DevKeyConfig|ConvertTo-Json -Depth 10;Pause-DevKey}
                '2'{$script:DevKeyConfig.Guardian.AutoClose= -not [bool]$script:DevKeyConfig.Guardian.AutoClose;Save-DevKeyConfiguration;Pause-DevKey}
                '3'{$script:DevKeyConfig.Applications.Kiro.AutoClose= -not [bool]$script:DevKeyConfig.Applications.Kiro.AutoClose;Save-DevKeyConfiguration;Pause-DevKey}
                '4'{$script:DevKeyConfig.Applications.OpenCode.AutoClose= -not [bool]$script:DevKeyConfig.Applications.OpenCode.AutoClose;Save-DevKeyConfiguration;Pause-DevKey}
                '5'{$script:DevKeyConfig.Guardian.ForceCloseOnRemoval= -not [bool]$script:DevKeyConfig.Guardian.ForceCloseOnRemoval;Save-DevKeyConfiguration;Pause-DevKey}
                '6'{if($script:DevKeyConfig.Guardian.AutoLaunch){Disable-DevKeyAutoLaunch}else{Enable-DevKeyAutoLaunch};Pause-DevKey}
                '7'{$themes=@('Classic','Dark','Matrix','Minimal');for($i=0;$i -lt $themes.Count;$i++){Write-Host (" [{0}] {1}" -f ($i+1),$themes[$i])};$n=0;if([int]::TryParse((Read-Host 'Tema'),[ref]$n) -and $n -ge 1 -and $n -le $themes.Count){$script:DevKeyConfig.Interface.Theme=$themes[$n-1];Save-DevKeyConfiguration};Pause-DevKey}
                '8'{$value=0;if([int]::TryParse((Read-Host 'Intervalo en segundos (1-60)'),[ref]$value) -and $value -ge 1 -and $value -le 60){$script:DevKeyConfig.Guardian.CheckIntervalSeconds=$value;Save-DevKeyConfiguration};Pause-DevKey}
                '0'{return}
                default{Write-Host 'Opcion no valida.' -ForegroundColor Yellow;Start-Sleep -Seconds 1}
            }
        }catch{Write-Host 'No se pudo guardar la configuracion.' -ForegroundColor Red;Pause-DevKey}
    }
}
