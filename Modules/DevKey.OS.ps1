function Show-DevKeyOSMenu {

    while ($true) {

        Clear-Host

        Write-Host ""
        Write-Host "======================================" -ForegroundColor DarkGray
        Write-Host "         SISTEMA OPERATIVO" -ForegroundColor Cyan
        Write-Host "======================================" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host " [1] Variables de entorno" -ForegroundColor White
        Write-Host " [2] PATH actual" -ForegroundColor White
        Write-Host " [3] Servicios en ejecucion" -ForegroundColor White
        Write-Host " [4] Informacion del sistema" -ForegroundColor White
        Write-Host " [5] Panel de control" -ForegroundColor White
        Write-Host " [6] Administrador de tareas" -ForegroundColor White
        Write-Host " [0] Volver" -ForegroundColor DarkGray
        Write-Host ""

        $Option = Read-Host "Selecciona una opcion"

        switch ($Option) {

            "1" {

                Clear-Host
                Write-Host ""
                Write-Host "======================================" -ForegroundColor DarkGray
                Write-Host "       VARIABLES DE ENTORNO" -ForegroundColor Cyan
                Write-Host "======================================" -ForegroundColor DarkGray
                Write-Host ""

                Get-ChildItem Env: |
                    Sort-Object Name |
                    Format-Table Name, Value -AutoSize

                Pause
            }

            "2" {

                Clear-Host
                Write-Host ""
                Write-Host "======================================" -ForegroundColor DarkGray
                Write-Host "              PATH" -ForegroundColor Cyan
                Write-Host "======================================" -ForegroundColor DarkGray
                Write-Host ""

                $env:PATH -split ";" | ForEach-Object {
                    if ($_) { Write-Host "  $_" }
                }

                Write-Host ""
                Pause
            }

            "3" {

                Clear-Host
                Write-Host ""
                Write-Host "======================================" -ForegroundColor DarkGray
                Write-Host "      SERVICIOS EN EJECUCION" -ForegroundColor Cyan
                Write-Host "======================================" -ForegroundColor DarkGray
                Write-Host ""

                Get-Service |
                    Where-Object { $_.Status -eq "Running" } |
                    Sort-Object DisplayName |
                    Select-Object Status, DisplayName |
                    Format-Table -AutoSize

                Pause
            }

            "4" { Show-SystemInfo }
            "5" { Start-Process -FilePath "control.exe" }
            "6" { Start-Process -FilePath "taskmgr.exe" }
            "0" { return }

            default {
                Write-Host ""
                Write-Host "Opcion no valida." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
    }
}
