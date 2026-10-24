$script:DevKeyIntegrityFile = Join-Path $ConfigRoot "integrity.json"

function Get-DevKeyIntegrityFiles {

    param([switch]$IncludeApps)

    $Roots = @($DevKeyRoot)

    if ($IncludeApps) {
        $Roots += (Join-Path $USBRoot "Apps")
    }

    $Files = @()

    foreach ($Root in $Roots) {

        if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
            continue
        }

        $Files += Get-ChildItem `
            -LiteralPath $Root `
            -File `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notlike (Join-Path $LogsRoot "*") -and
                $_.FullName -ne $script:DevKeyIntegrityFile -and
                $_.Extension -notin @(".tmp", ".log", ".jsonl")
            }
    }

    if ($IncludeApps -and (Test-Path -LiteralPath $KeyFile -PathType Leaf)) {
        $Files += Get-Item -LiteralPath $KeyFile
    }

    return $Files
}

function New-DevKeyIntegrityManifest {

    param([switch]$IncludeApps)

    $Entries = @{}

    $Files = Get-DevKeyIntegrityFiles -IncludeApps:$IncludeApps

    foreach ($File in $Files) {

        $Hash = (Get-FileHash -LiteralPath $File.FullName -Algorithm SHA256).Hash.ToUpper()
        $Entries[$File.FullName] = $Hash
    }

    $Manifest = [PSCustomObject]@{
        created     = (Get-Date).ToString("o")
        includeApps = [bool]$IncludeApps
        algorithm   = "SHA256"
        files       = $Entries
    }

    $Manifest |
        ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath $script:DevKeyIntegrityFile -Encoding UTF8

    return $Entries.Count
}

function Update-DevKeyIntegrity {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "      REGENERAR INTEGRIDAD DEVKEY" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Se calculara SHA-256 de los archivos de DevKey"
    Write-Host "y se guardara el manifiesto en:"
    Write-Host $script:DevKeyIntegrityFile
    Write-Host ""

    $Confirm = Read-Host "Continuar? (S/N)"

    if ($Confirm -ne "S" -and $Confirm -ne "s") {
        return
    }

    try {

        $Count = New-DevKeyIntegrityManifest

        Write-Host ""
        Write-Host "[OK] Integridad regenerada ($Count archivos)." -ForegroundColor Green
        Write-DevKeyLog "Manifiesto de integridad regenerado ($Count archivos)."
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] No se pudo regenerar la integridad." -ForegroundColor Red
        Write-Host $_.Exception.Message
    }

    Write-Host ""
    Pause
}

function Test-DevKeyIntegrity {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "        VERIFICAR INTEGRIDAD" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Test-Path -LiteralPath $script:DevKeyIntegrityFile -PathType Leaf)) {

        Write-Host "[--] No existe el manifiesto de integridad." -ForegroundColor Yellow
        Write-Host "Usa la opcion Regenerar integridad."
        Write-Host ""
        Pause
        return
    }

    try {

        $Manifest = Get-Content -LiteralPath $script:DevKeyIntegrityFile -Raw |
            ConvertFrom-Json

        $Expected = @{}
        $Manifest.files.PSObject.Properties | ForEach-Object {
            $Expected[$_.Name] = [string]$_.Value
        }

        $Missing = @()
        $Changed = @()
        $Ok = 0

        foreach ($Path in $Expected.Keys) {

            if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
                $Missing += $Path
                continue
            }

            $Current = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpper()

            if ($Current -eq $Expected[$Path]) {
                $Ok++
            }
            else {
                $Changed += $Path
            }
        }

        $CurrentFiles = @{}
        Get-DevKeyIntegrityFiles -IncludeApps:$Manifest.includeApps | ForEach-Object {
            $CurrentFiles[$_.FullName] = $true
        }

        $Extra = @($CurrentFiles.Keys | Where-Object { -not $Expected.ContainsKey($_) })

        Write-Host (" [OK]      {0}" -f $Ok) -ForegroundColor Green
        Write-Host (" [FALTAN]  {0}" -f $Missing.Count) -ForegroundColor Red
        Write-Host (" [CAMBIAN] {0}" -f $Changed.Count) -ForegroundColor Yellow
        Write-Host (" [NUEVOS]  {0}" -f $Extra.Count) -ForegroundColor Magenta
        Write-Host ""

        $Missing | ForEach-Object { Write-Host "  FALTA   $_" -ForegroundColor Red }
        $Changed | ForEach-Object { Write-Host "  CAMBIA  $_" -ForegroundColor Yellow }
        $Extra   | ForEach-Object { Write-Host "  NUEVO   $_" -ForegroundColor Magenta }

        if ($Missing.Count -eq 0 -and $Changed.Count -eq 0) {
            Write-Host ""
            Write-Host "[OK] Integridad correcta." -ForegroundColor Green
        }
        else {
            Write-Host ""
            Write-Host "[!] Hay diferencias respecto al manifiesto." -ForegroundColor Yellow
        }

        Write-DevKeyLog "Verificacion de integridad: ok=$Ok faltan=$($Missing.Count) cambian=$($Changed.Count) nuevos=$($Extra.Count)"
    }
    catch {
        Write-Host "[ERROR] No se pudo verificar la integridad." -ForegroundColor Red
        Write-Host $_.Exception.Message
    }

    Write-Host ""
    Pause
}

function Test-DevKeyIntegrityAdvanced {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "   VERIFICAR INTEGRIDAD AVANZADA" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Incluye DevKey, Apps y unlock.k3y."
    Write-Host "Puede tardar varios minutos."
    Write-Host ""

    $Confirm = Read-Host "Continuar? (S/N)"

    if ($Confirm -ne "S" -and $Confirm -ne "s") {
        return
    }

    try {

        $Count = New-DevKeyIntegrityManifest -IncludeApps
        $HashOk = Get-HashStatus

        Write-Host ""
        Write-Host "[OK] Manifiesto avanzado generado ($Count archivos)." -ForegroundColor Green

        if ($HashOk) {
            Write-Host "[OK] unlock.k3y coincide con ExpectedHash." -ForegroundColor Green
        }
        else {
            Write-Host "[ERROR] unlock.k3y NO coincide con ExpectedHash." -ForegroundColor Red
        }

        Write-DevKeyLog "Manifiesto de integridad avanzado generado ($Count archivos)."
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] No se pudo generar el manifiesto avanzado." -ForegroundColor Red
        Write-Host $_.Exception.Message
    }

    Write-Host ""
    Pause
}
