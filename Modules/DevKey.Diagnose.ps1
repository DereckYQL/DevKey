function Show-DevKeyDiagnostics {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "        PANEL DE DIAGNOSTICO" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    $Lines = New-Object System.Collections.ArrayList

    [void]$Lines.Add("DEVKEY DIAGNOSTICO")
    [void]$Lines.Add("Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$Lines.Add("")

    [void]$Lines.Add("SISTEMA")
    [void]$Lines.Add("Equipo       : $env:COMPUTERNAME")
    [void]$Lines.Add("Usuario      : $env:USERNAME")
    [void]$Lines.Add("PowerShell   : $($PSVersionTable.PSVersion)")
    [void]$Lines.Add("USB          : $USBRoot")
    [void]$Lines.Add("DevKey       : $DevKeyRoot")
    [void]$Lines.Add("")

    [void]$Lines.Add("VERSION")
    [void]$Lines.Add("Version      : $DevKeyVersion")
    [void]$Lines.Add("Build        : $DevKeyBuild")
    [void]$Lines.Add("Canal        : $DevKeyChannel")
    [void]$Lines.Add("")

    [void]$Lines.Add("RUTAS")
    [void]$Lines.Add("unlock.k3y   : $(Test-Path -LiteralPath $KeyFile)  $KeyFile")
    [void]$Lines.Add("Kiro         : $(Test-Path -LiteralPath $KiroPath)  $KiroPath")
    [void]$Lines.Add("OpenCode     : $(Test-Path -LiteralPath $OpenCodePath)  $OpenCodePath")
    [void]$Lines.Add("Docker       : $(Test-Path -LiteralPath $DockerPath)  $DockerPath")
    [void]$Lines.Add("Git          : $(Test-Path -LiteralPath $GitPath)  $GitPath")
    [void]$Lines.Add("Projects     : $(Test-Path -LiteralPath $ProjectsPath)  $ProjectsPath")
    [void]$Lines.Add("Vault        : $(Test-Path -LiteralPath (Join-Path $USBRoot 'Data\Vault\devkey.kdbx'))")
    [void]$Lines.Add("")

    [void]$Lines.Add("SEGURIDAD")
    [void]$Lines.Add("Hash key     : $(if (Get-HashStatus) { 'OK' } else { 'ERROR' })")
    [void]$Lines.Add("auth.json    : $(Test-Path -LiteralPath $AuthFile)  $AuthFile")
    [void]$Lines.Add("")

    try {
        $Volume = Get-Volume -DriveLetter $USBRoot.Substring(0, 1)
        $FreeGB = [math]::Round($Volume.SizeRemaining / 1GB, 2)
        $TotalGB = [math]::Round($Volume.Size / 1GB, 2)

        [void]$Lines.Add("ALMACENAMIENTO")
        [void]$Lines.Add("Libre        : $FreeGB GB")
        [void]$Lines.Add("Capacidad    : $TotalGB GB")
        [void]$Lines.Add("")
    }
    catch {
        [void]$Lines.Add("ALMACENAMIENTO")
        [void]$Lines.Add("No disponible")
        [void]$Lines.Add("")
    }

    [void]$Lines.Add("REPOSITORIOS")

    try {

        $Repositories = @(Get-DevKeyRepoList)

        if ($Repositories.Count -eq 0) {
            [void]$Lines.Add("No hay repositorios.")
        }
        else {

            foreach ($Repo in $Repositories) {

                $Info = Get-DevKeyRepoInfo -Repo $Repo
                [void]$Lines.Add(("{0} | rama={1} | cambios={2} | adelante={3} | atras={4}" -f $Info.Name, $Info.Branch, $Info.Dirty, $Info.Ahead, $Info.Behind))
            }
        }
    }
    catch {
        [void]$Lines.Add("Error leyendo repositorios: $($_.Exception.Message)")
    }

    [void]$Lines.Add("")
    [void]$Lines.Add("LOG RECIENTE")
    [void]$Lines.Add("")

    if (Test-Path -LiteralPath $DevKeyLogFile -PathType Leaf) {
        Get-Content -LiteralPath $DevKeyLogFile -Tail 20 | ForEach-Object {
            [void]$Lines.Add($_)
        }
    }
    else {
        [void]$Lines.Add("No existe devkey.log.")
    }

    $ReportPath = Join-Path $LogsRoot ("diagnostics-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".txt")

    try {
        $Lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
        Write-DevKeyLog "Diagnostico guardado: $ReportPath"
    }
    catch {
        Write-Host "[!] No se pudo guardar el diagnostico." -ForegroundColor Yellow
    }

    $Lines | ForEach-Object { Write-Host $_ }

    Write-Host ""
    Write-Host "Informe guardado en:"
    Write-Host $ReportPath
    Write-Host ""

    Pause
}

