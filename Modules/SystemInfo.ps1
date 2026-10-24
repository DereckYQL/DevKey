function Get-DevKeyDashboard {
    $integrity=Get-DevKeyIntegrityStatus
    $token=Test-DevKeyPhysicalToken
    $items=@(
        [pscustomobject]@{Name='Unidad USB / token';State=$(if($token){'OK'}else{'ERROR'})},
        [pscustomobject]@{Name='Autenticación';State=$(if($script:DevKeyAuthenticated){'OK (sesión actual)'}else{'PENDIENTE'})},
        [pscustomobject]@{Name='Integridad';State=$integrity.Status},
        [pscustomobject]@{Name='Guardian';State=(Get-DevKeyGuardianStatus)},
        [pscustomobject]@{Name='Kiro';State=$(if(Get-DevKeyApplicationPath Kiro){'DISPONIBLE'}else{'FALTANTE'})},
        [pscustomobject]@{Name='OpenCode';State=$(if(Get-DevKeyApplicationPath OpenCode){'DISPONIBLE'}else{'FALTANTE'})},
        [pscustomobject]@{Name='Git';State=$(if(Get-DevKeyApplicationPath Git){'DISPONIBLE'}else{'FALTANTE'})},
        [pscustomobject]@{Name='Node.js';State=$(if(Get-DevKeyApplicationPath Node){'DISPONIBLE'}else{'FALTANTE'})},
        [pscustomobject]@{Name='Docker';State=$(if(Get-DevKeyApplicationPath Docker){'DISPONIBLE'}else{'FALTANTE'})},
        [pscustomobject]@{Name='Projects';State=$(if(Test-Path -LiteralPath $script:ProjectsRoot -PathType Container){'OK'}else{'ERROR'})},
        [pscustomobject]@{Name='Configuración';State='OK (cargada)'}
    );return $items
}
function Show-DevKeySystemInfo {
    Clear-Host;Write-Host 'DEVKEY STATUS' -ForegroundColor Cyan;Get-DevKeyDashboard | Format-Table -AutoSize
    try{$os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop;$cpu=Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1;Write-Host "Windows: $($os.Caption) $($os.Version)";Write-Host "CPU: $($cpu.Name)";Write-Host ('Memoria física libre: {0:N1} GB' -f ($os.FreePhysicalMemory/1MB))}catch{Write-Host 'Información de hardware no disponible.' -ForegroundColor Yellow}
    Write-Host "DevKey: $script:DevKeyRoot";Write-Host "Versión: $(Get-DevKeyVersion)";Pause-DevKey
}
