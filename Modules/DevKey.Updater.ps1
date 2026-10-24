function Show-DevKeyUpdateStatus {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "          ACTUALIZAR DEVKEY" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "Version actual : $DevKeyVersion"
    Write-Host "Build          : $DevKeyBuild"
    Write-Host "Canal          : $DevKeyChannel"
    Write-Host "Ruta           : $DevKeyRoot"
    Write-Host ""

    if (-not (Test-Path -LiteralPath $GitPath -PathType Leaf)) {
        Write-Host "[--] Git Portable no encontrado." -ForegroundColor Yellow
        Write-Host ""
        Pause
        return
    }

    if (-not (Test-Path -LiteralPath (Join-Path $DevKeyRoot ".git") -PathType Container)) {
        Write-Host "[--] DevKey no es un repositorio Git." -ForegroundColor Yellow
        Write-Host "Para actualizar, reemplaza la carpeta DevKey por la nueva version."
        Write-Host ""
        Pause
        return
    }

    Write-Host "Repositorio Git detectado."
    Write-Host ""

    & $GitPath -C $DevKeyRoot remote -v
    & $GitPath -C $DevKeyRoot status --short

    Write-Host ""
    Pause
}

function Update-DevKeyFromGit {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "      ACTUALIZAR DESDE GIT" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Test-Path -LiteralPath (Join-Path $DevKeyRoot ".git") -PathType Container)) {
        Write-Host "[ERROR] DevKey no es un repositorio Git." -ForegroundColor Red
        Write-Host ""
        Pause
        return
    }

    $Confirm = Read-Host "Actualizar DevKey ahora? (S/N)"

    if ($Confirm -ne "S" -and $Confirm -ne "s") {
        return
    }

    $Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $ConfigBackup = Join-Path $BackupsRoot "Config-$Stamp"

    try {

        if (Test-Path -LiteralPath $ConfigRoot -PathType Container) {
            Copy-Item -LiteralPath $ConfigRoot -Destination $ConfigBackup -Recurse -Force
            Write-Host "[OK] Config respaldada en:" -ForegroundColor Green
            Write-Host $ConfigBackup
            Write-Host ""
        }

        & $GitPath -C $DevKeyRoot fetch --all --prune

        if ($LASTEXITCODE -ne 0) {
            throw "git fetch fallo."
        }

        & $GitPath -C $DevKeyRoot pull --ff-only

        if ($LASTEXITCODE -ne 0) {
            throw "git pull fallo. Revisa cambios locales."
        }

        Write-Host ""
        Write-Host "[OK] DevKey actualizado." -ForegroundColor Green
        Write-Host "Cierra y vuelve a abrir DevKey."
        Write-DevKeyLog "DevKey actualizado desde Git."
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] No se pudo actualizar." -ForegroundColor Red
        Write-Host $_.Exception.Message
        Write-DevKeyLog "Actualizacion fallida: $($_.Exception.Message)"
    }

    Write-Host ""
    Pause
}

function Show-DevKeyUpdaterMenu {

    while ($true) {

        Clear-Host

        Write-Host ""
        Write-Host "======================================" -ForegroundColor DarkGray
        Write-Host "          DEVKEY UPDATER" -ForegroundColor Cyan
        Write-Host "======================================" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host " [1] Ver version y estado" -ForegroundColor White
        Write-Host " [2] Actualizar desde Git" -ForegroundColor White
        Write-Host " [3] Abrir carpeta de backups" -ForegroundColor White
        Write-Host " [0] Volver" -ForegroundColor DarkGray
        Write-Host ""

        $Option = Read-Host "Selecciona una opcion"

        switch ($Option) {

            "1" { Show-DevKeyUpdateStatus }
            "2" { Update-DevKeyFromGit }
            "3" { Start-Process -FilePath "explorer.exe" -ArgumentList "`"$BackupsRoot`"" }
            "0" { return }

            default {
                Write-Host ""
                Write-Host "Opcion no valida." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
    }
}
