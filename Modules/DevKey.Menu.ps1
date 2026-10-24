function Show-DevKeyMainMenu {

    param(
        [string]$Version,
        [string]$Build,
        [string]$Channel,
        [string]$USBRoot,
        [string]$Profile,
        [string]$ProjectsPath
    )

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "             DEVKEY USB" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host (" Version : " + $Version)
    Write-Host (" Build   : " + $Build)
    Write-Host (" Canal   : " + $Channel)
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host " USB: $USBRoot" -ForegroundColor Magenta
    Write-Host ""

    if ($Profile) {
        Write-Host (" Perfil: " + $Profile) -ForegroundColor Magenta
        Write-Host ""
    }

    Write-Host " [1] Abrir frameworks" -ForegroundColor White
    Write-Host " [2] Abrir Projects" -ForegroundColor White
    Write-Host " [3] Ver estado" -ForegroundColor White
    Write-Host " [4] Verificar DevKey" -ForegroundColor White
    Write-Host " [5] Mantenimiento" -ForegroundColor White
    Write-Host " [6] Info Sistema" -ForegroundColor White
    Write-Host " [7] GitHub" -ForegroundColor White
    Write-Host " [8] Sistema Operativo" -ForegroundColor White
    Write-Host " [S] Seguridad / DevKey Vault" -ForegroundColor White
    Write-Host " [0] Salir" -ForegroundColor DarkGray
    Write-Host ""
}
