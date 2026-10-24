function Get-DevKeyKeePassPath {
    foreach($relative in @('KeePass\KeePass.exe','KeePassXC\KeePassXC.exe','KeePassXC\keepassxc.exe')){$path=Join-Path $script:AppsRoot $relative;if(Test-Path -LiteralPath $path -PathType Leaf){return $path}}
    return $null
}
function Show-DevKeySecurityMenu {
    while($true){
        Clear-Host;Write-Host 'SEGURIDAD' -ForegroundColor Cyan
        Write-Host ' [1] Estado token / autenticacion';Write-Host ' [2] Abrir DevKey Vault';Write-Host ' [3] Generar clave aleatoria';Write-Host ' [4] Crear clave de recuperacion';Write-Host ' [5] Recuperar acceso';Write-Host ' [0] Volver'
        $option=Read-Host 'Opcion'
        switch($option){
            '1'{Write-Host ("Token: {0}" -f $(if(Test-DevKeyPhysicalToken){'OK'}else{'ERROR'}));Write-Host ("auth.json: {0}" -f $(if(Test-Path -LiteralPath $script:AuthFile){'presente'}else{'ausente'}));Show-DevKeyIntegrity;Pause-DevKey}
            '2'{$path=Get-DevKeyKeePassPath;if($path -and (Test-Path -LiteralPath $script:VaultFile -PathType Leaf)){[void](Start-DevKeyManagedProcess -FilePath $path -ArgumentList @($script:VaultFile) -WorkingDirectory (Split-Path -Parent $path) -Application 'KeePass')}else{Write-Host 'KeePass o la boveda no estan disponibles.' -ForegroundColor Yellow};Pause-DevKey}
            '3'{$bytes=New-Object byte[] 24;$rng=[Security.Cryptography.RandomNumberGenerator]::Create();try{$rng.GetBytes($bytes)}finally{$rng.Dispose()};$secret=[Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+','-').Replace('/','_');Set-Clipboard -Value $secret;Write-Host "Clave aleatoria temporal (visible hasta limpiar la consola):`n$secret" -ForegroundColor Yellow;Write-Host 'Copiada al portapapeles. No se escribio en los logs.';Pause-DevKey}
            '4'{New-DevKeyRecoveryKey}
            '5'{if(Invoke-DevKeyRecovery){Write-Host 'Acceso recuperado; crea otra clave de recuperacion.' -ForegroundColor Green};Pause-DevKey}
            '0'{return}
            default{Write-Host 'Opcion no valida.' -ForegroundColor Yellow;Start-Sleep -Seconds 1}
        }
    }
}
