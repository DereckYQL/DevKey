function Show-DevKeyAppsStatus {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "       APLICACIONES PORTABLES" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    $Apps = @(
        [PSCustomObject]@{
            Name = "Kiro"
            Path = $KiroPath
        }
        [PSCustomObject]@{
            Name = "OpenCode"
            Path = $OpenCodePath
        }
        [PSCustomObject]@{
            Name = "Docker"
            Path = $DockerPath
        }
        [PSCustomObject]@{
            Name = "Git"
            Path = $GitPath
        }
        [PSCustomObject]@{
            Name = "KeePass"
            Path = (Join-Path $USBRoot "Apps\KeePass\KeePass.exe")
        }
    )

    foreach ($App in $Apps) {

        if (Test-Path -LiteralPath $App.Path -PathType Leaf) {

            $Version = ""

            try {
                $Version = (Get-Item -LiteralPath $App.Path).VersionInfo.ProductVersion
            }
            catch {
                $Version = ""
            }

            Write-Host (" [OK] {0}" -f $App.Name) -ForegroundColor Green
            Write-Host ("      {0}" -f $App.Path) -ForegroundColor DarkGray

            if ($Version) {
                Write-Host ("      Version: {0}" -f $Version)
            }
        }
        else {
            Write-Host (" [--] {0} no encontrado" -f $App.Name) -ForegroundColor Yellow
            Write-Host ("      {0}" -f $App.Path) -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Pause
}

function Show-DevKeyAppsMenu {

    while ($true) {

        Clear-Host

        Write-Host ""
        Write-Host "======================================" -ForegroundColor DarkGray
        Write-Host "      ACTUALIZADOR DE APLICACIONES" -ForegroundColor Cyan
        Write-Host "======================================" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host " [1] Ver aplicaciones instaladas" -ForegroundColor White
        Write-Host " [2] Abrir carpeta Apps" -ForegroundColor White
        Write-Host " [3] Comprobar ejecutables" -ForegroundColor White
        Write-Host " [4] Instrucciones de actualizacion" -ForegroundColor White
        Write-Host " [0] Volver" -ForegroundColor DarkGray
        Write-Host ""

        $Option = Read-Host "Selecciona una opcion"

        switch ($Option) {

            "1" { Show-DevKeyAppsStatus }

            "2" {
                Start-Process -FilePath "explorer.exe" -ArgumentList "`"$(Join-Path $USBRoot 'Apps')`""
            }

            "3" {
                Clear-Host
                Write-Host ""
                Write-Host "Comprobando ejecutables..."
                Write-Host ""

                $Checks = @(
                    @{ Name = "Kiro"; Path = $KiroPath }
                    @{ Name = "OpenCode"; Path = $OpenCodePath }
                    @{ Name = "Git"; Path = $GitPath }
                    @{ Name = "Docker"; Path = $DockerPath }
                )

                foreach ($Check in $Checks) {
                    if (Test-Path -LiteralPath $Check.Path -PathType Leaf) {
                        Write-Host (" [OK] {0}" -f $Check.Name) -ForegroundColor Green
                    }
                    else {
                        Write-Host (" [ERROR] {0}" -f $Check.Name) -ForegroundColor Red
                    }
                }

                Write-Host ""
                Pause
            }

            "4" {
                Clear-Host
                Write-Host ""
                Write-Host "======================================" -ForegroundColor DarkGray
                Write-Host "      ACTUALIZAR APLICACIONES" -ForegroundColor Cyan
                Write-Host "======================================" -ForegroundColor DarkGray
                Write-Host ""
                Write-Host "Las aplicaciones son portables y se gestionan"
                Write-Host "manualmente para mantener la USB autocontenida:"
                Write-Host ""
                Write-Host "  1. Descarga la nueva version portable."
                Write-Host "  2. Cierra la aplicacion."
                Write-Host "  3. Reemplaza su carpeta en Apps."
                Write-Host "  4. Conserva la configuracion en Data."
                Write-Host ""
                Write-Host "Apps: $(Join-Path $USBRoot 'Apps')"
                Write-Host "Data: $(Join-Path $USBRoot 'Data')"
                Write-Host ""
                Pause
            }

            "0" { return }

            default {
                Write-Host ""
                Write-Host "Opcion no valida." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
    }
}
