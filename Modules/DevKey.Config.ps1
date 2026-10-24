function Show-DevKeyConfig {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "       CONFIGURACION AVANZADA" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "Config:" -ForegroundColor Magenta
    Write-Host "  $ConfigRoot"
    Write-Host ""

    Write-Host "version.json:" -ForegroundColor Magenta

    if (Test-Path -LiteralPath $VersionFile -PathType Leaf) {
        Get-Content -LiteralPath $VersionFile -Raw
    }
    else {
        Write-Host "  No existe."
    }

    Write-Host ""
    Write-Host "git.json:" -ForegroundColor Magenta

    if (Test-Path -LiteralPath $GitConfigFile -PathType Leaf) {
        Get-Content -LiteralPath $GitConfigFile -Raw
    }
    else {
        Write-Host "  No existe."
    }

    Write-Host ""
    Write-Host "Rutas:" -ForegroundColor Magenta
    Write-Host "  USB          : $USBRoot"
    Write-Host "  Git          : $GitPath"
    Write-Host "  Projects     : $ProjectsPath"
    Write-Host "  Kiro data    : $KiroData"
    Write-Host "  Auth         : $AuthFile"
    Write-Host "  Security     : $SecurityMenu"
    Write-Host ""

    Pause
}

function Edit-DevKeyConfigFile {

    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Host ""
        Write-Host "[ERROR] No existe: $Path" -ForegroundColor Red
        Write-Host ""
        Pause
        return
    }

    Start-Process -FilePath "notepad.exe" -ArgumentList "`"$Path`""

    Write-Host ""
    Write-Host "[OK] Archivo abierto en Notepad." -ForegroundColor Green
    Write-Host "Guarda los cambios y vuelve a DevKey."
    Write-Host ""
    Pause
}

function Reset-DevKeyGitIdentity {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "     RESTABLECER IDENTIDAD GIT" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Se aplicara user.name y user.email de git.json"
    Write-Host "a todos los repositorios de Projects."
    Write-Host ""

    $Confirm = Read-Host "Continuar? (S/N)"

    if ($Confirm -ne "S" -and $Confirm -ne "s") {
        return
    }

    try {
        Set-DevKeyRepoIdentity | Out-Null
        Write-Host ""
        Write-Host "[OK] Identidad aplicada." -ForegroundColor Green
        Write-DevKeyLog "Identidad Git reaplicada a Projects."
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] No se pudo aplicar la identidad." -ForegroundColor Red
        Write-Host $_.Exception.Message
    }

    Write-Host ""
    Pause
}

function Show-DevKeyConfigMenu {

    while ($true) {

        Clear-Host

        Write-Host ""
        Write-Host "======================================" -ForegroundColor DarkGray
        Write-Host "        DEVKEY CONFIGURACION" -ForegroundColor Cyan
        Write-Host "======================================" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host " [1] Ver configuracion" -ForegroundColor White
        Write-Host " [2] Editar git.json" -ForegroundColor White
        Write-Host " [3] Editar version.json" -ForegroundColor White
        Write-Host " [4] Abrir carpeta Config" -ForegroundColor White
        Write-Host " [5] Restablecer identidad Git" -ForegroundColor White
        Write-Host " [0] Volver" -ForegroundColor DarkGray
        Write-Host ""

        $Option = Read-Host "Selecciona una opcion"

        switch ($Option) {

            "1" { Show-DevKeyConfig }
            "2" { Edit-DevKeyConfigFile -Path $GitConfigFile }
            "3" { Edit-DevKeyConfigFile -Path $VersionFile }
            "4" { Start-Process -FilePath "explorer.exe" -ArgumentList "`"$ConfigRoot`"" }
            "5" { Reset-DevKeyGitIdentity }
            "0" { return }

            default {
                Write-Host ""
                Write-Host "Opcion no valida." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
    }
}
