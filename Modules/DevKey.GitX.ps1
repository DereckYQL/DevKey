$script:DevKeySyncHistoryFile = Join-Path $script:DevKeyRoot 'Logs\sync-history.jsonl'

function Get-DevKeyRepoList {

    if (-not (Test-Path -LiteralPath $ProjectsPath -PathType Container)) {
        return @()
    }

    return @(
        Get-ChildItem `
            -LiteralPath $ProjectsPath `
            -Directory `
            -Force `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Where-Object {
                Test-Path -LiteralPath (Join-Path $_.FullName ".git") -PathType Container
            } |
            Sort-Object FullName
    )
}

function Add-DevKeySyncRecord {

    param(
        [string]$Repository,
        [string]$Action,
        [string]$Result,
        [string]$Details
    )

    if(-not $script:DevKeyConfig.Logging.Enabled){return}
    try {
        $logDirectory=Split-Path -Parent $script:DevKeySyncHistoryFile
        if(-not (Test-Path -LiteralPath $logDirectory -PathType Container)){New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction Stop|Out-Null}

        if (Test-Path -LiteralPath $script:DevKeySyncHistoryFile -PathType Leaf) {
            $item=Get-Item -LiteralPath $script:DevKeySyncHistoryFile
            $limit=[Math]::Max(1,[int]$script:DevKeyConfig.Logging.MaxFileSizeMB)*1MB
            if($item.Length -ge $limit){$archive=$script:DevKeySyncHistoryFile+'.'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'.old';Move-Item -LiteralPath $script:DevKeySyncHistoryFile -Destination $archive -ErrorAction Stop}
        }
        $Record = [PSCustomObject]@{
            timestamp  = (Get-Date).ToString("o")
            repository = Protect-DevKeyLogText -Text $Repository
            action     = $Action
            result     = $Result
            details    = Protect-DevKeyLogText -Text $Details
        }

        $Record |
            ConvertTo-Json -Compress |
            Add-Content -LiteralPath $script:DevKeySyncHistoryFile -Encoding UTF8
        $cutoff=(Get-Date).AddDays(-[Math]::Max(1,[int]$script:DevKeyConfig.Logging.RetentionDays))
        Get-ChildItem -LiteralPath $LogsRoot -Filter 'sync-history.jsonl.*.old' -File -ErrorAction SilentlyContinue | Where-Object LastWriteTime -lt $cutoff | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-DevKeyLog -Log error.log -Level ERROR -Message 'Failed writing Git sync history.'
    }
}

function Read-DevKeyRepoSelection {

    param([string]$Title)

    $Repositories = @(Get-DevKeyRepoList)

    if (-not $Repositories -or $Repositories.Count -eq 0) {
        Write-Host "[--] No se encontraron repositorios en Projects." -ForegroundColor Yellow
        Pause
        return $null
    }

    if ($Repositories.Count -eq 1) {
        return $Repositories[0]
    }

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "         $Title" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    for ($Index = 0; $Index -lt $Repositories.Count; $Index++) {
        $Relative = $Repositories[$Index].FullName.Substring($ProjectsPath.Length).TrimStart("\")
        Write-Host (" [{0}] {1}" -f ($Index + 1), $Relative) -ForegroundColor White
    }

    Write-Host " [0] Volver" -ForegroundColor DarkGray
    Write-Host ""

    $Option = Read-Host "Selecciona un repositorio"

    if ($Option -eq "0" -or [string]::IsNullOrWhiteSpace($Option)) {
        return $null
    }

    $Number = 0
    if (-not [int]::TryParse($Option, [ref]$Number)) {
        return $null
    }

    if ($Number -lt 1 -or $Number -gt $Repositories.Count) {
        return $null
    }

    return $Repositories[$Number - 1]
}

function Get-DevKeyRepoInfo {

    param([System.IO.DirectoryInfo]$Repo)

    $Branch = ""
    $Remote = ""
    $Ahead = 0
    $Behind = 0
    $Dirty = 0

    try {

        $Branch = (& $GitPath -C $Repo.FullName rev-parse --abbrev-ref HEAD 2>$null | Select-Object -First 1)
        $Remote = (& $GitPath -C $Repo.FullName remote get-url origin 2>$null | Select-Object -First 1)

        $Status = @(& $GitPath -C $Repo.FullName status --porcelain 2>$null)
        $Dirty = $Status.Count

        if ($Remote -and $Branch -and $Branch -ne "HEAD") {

            $Counts = (& $GitPath -C $Repo.FullName rev-list --left-right --count "HEAD...origin/$Branch" 2>$null) -split "\s+"

            if ($Counts.Count -ge 2) {
                $Ahead = [int]$Counts[0]
                $Behind = [int]$Counts[1]
            }
        }
    }
    catch {
        Write-DevKeyLog "Error leyendo repositorio $($Repo.FullName): $($_.Exception.Message)"
    }

    return [PSCustomObject]@{
        Name   = $Repo.Name
        Path   = $Repo.FullName
        Branch = $Branch
        Remote = $Remote
        Ahead  = $Ahead
        Behind = $Behind
        Dirty  = $Dirty
    }
}

function Show-DevKeyRepoOverview {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "        REPOSITORIOS DEVKEY" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    $Repositories = @(Get-DevKeyRepoList)

    if (-not $Repositories -or $Repositories.Count -eq 0) {
        Write-Host "[--] No se encontraron repositorios." -ForegroundColor Yellow
        Pause
        return
    }

    foreach ($Repo in $Repositories) {

        $Info = Get-DevKeyRepoInfo -Repo $Repo
        $Relative = $Info.Path.Substring($ProjectsPath.Length).TrimStart("\")

        Write-Host ""
        Write-Host "--------------------------------------" -ForegroundColor DarkGray
        Write-Host $Relative -ForegroundColor Cyan
        Write-Host "--------------------------------------" -ForegroundColor DarkGray
        Write-Host " Rama   : $($Info.Branch)"
        Write-Host " Remoto : $($Info.Remote)"

        if ($Info.Dirty -eq 0) {
            Write-Host " Estado : limpio" -ForegroundColor Green
        }
        else {
            Write-Host " Estado : $($Info.Dirty) archivo(s) con cambios" -ForegroundColor Yellow
        }

        Write-Host " Sync   : $($Info.Ahead) adelante / $($Info.Behind) atras"
    }

    Write-Host ""
    Write-Host "--------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    Pause
}

function Sync-DevKeyRepositories {

    $ErrorActionPreference = "Continue"
    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "       SINCRONIZAR REPOSITORIOS" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Test-Path -LiteralPath $GitPath -PathType Leaf)) {
        Write-Host "[ERROR] Git Portable no encontrado." -ForegroundColor Red
        Pause
        return
    }

    $Repositories = @(Get-DevKeyRepoList)

    if (-not $Repositories -or $Repositories.Count -eq 0) {
        Write-Host "[--] No se encontraron repositorios." -ForegroundColor Yellow
        Pause
        return
    }

    foreach ($Repo in $Repositories) {

        $Info = Get-DevKeyRepoInfo -Repo $Repo

        Write-Host ""
        Write-Host "--------------------------------------" -ForegroundColor DarkGray
        Write-Host $Info.Name -ForegroundColor Cyan
        Write-Host "--------------------------------------" -ForegroundColor DarkGray

        if (-not $Info.Remote) {
            Write-Host "[--] Sin remoto origin, se omite." -ForegroundColor Yellow
            Add-DevKeySyncRecord -Repository $Info.Name -Action "sync" -Result "skip" -Details "sin origin"
            continue
        }

        Write-Host "Obteniendo cambios..."
        & $GitPath -C $Repo.FullName fetch --all --prune 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] git fetch fallo." -ForegroundColor Red
            Add-DevKeySyncRecord -Repository $Info.Name -Action "fetch" -Result "error" -Details "exit $LASTEXITCODE"
            continue
        }

        $Info = Get-DevKeyRepoInfo -Repo $Repo

        if ($Info.Ahead -gt 0) {
            Write-Host "[INFO] El USB tiene $($Info.Ahead) commit(s) que GitHub no tiene." -ForegroundColor Yellow
            Write-Host "[INFO] No se realizara pull." -ForegroundColor Yellow
            Add-DevKeySyncRecord -Repository $Info.Name -Action "sync" -Result "skip" -Details "ahead $($Info.Ahead)"
            continue
        }

        if ($Info.Behind -eq 0) {
            Write-Host "[OK] Ya esta actualizado." -ForegroundColor Green
            Add-DevKeySyncRecord -Repository $Info.Name -Action "sync" -Result "ok" -Details "sin cambios"
            continue
        }

        if ($Info.Dirty -gt 0) {
            Write-Host "[!] Hay cambios locales. No se realizara pull." -ForegroundColor Yellow
            Add-DevKeySyncRecord -Repository $Info.Name -Action "sync" -Result "skip" -Details "cambios locales"
            continue
        }

        Write-Host "[INFO] Hay $($Info.Behind) commit(s) nuevos en GitHub." -ForegroundColor Magenta
        Write-Host "[INFO] Actualizando..."

        & $GitPath -C $Repo.FullName pull --ff-only 2>&1 | ForEach-Object {
            Write-Host "  $_"
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Repositorio actualizado." -ForegroundColor Green
            Add-DevKeySyncRecord -Repository $Info.Name -Action "pull" -Result "ok" -Details "ff-only"
        }
        else {
            Write-Host "[ERROR] git pull fallo." -ForegroundColor Red
            Add-DevKeySyncRecord -Repository $Info.Name -Action "pull" -Result "error" -Details "exit $LASTEXITCODE"
        }
    }

    Write-Host ""
    Pause
}

function Show-DevKeyBranches {

    $Repo = Read-DevKeyRepoSelection -Title "RAMAS"

    if (-not $Repo) {
        return
    }

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "          RAMAS - $($Repo.Name)" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    & $GitPath -C $Repo.FullName branch -a

    Write-Host ""
    Write-Host "Escribe una rama para cambiar, o ENTER para volver."
    Write-Host ""

    $Branch = Read-Host "Rama"

    if ([string]::IsNullOrWhiteSpace($Branch)) {
        return
    }

    $Branch = $Branch -replace "^remotes/origin/", ""

    if($Branch -notmatch '^[A-Za-z0-9][A-Za-z0-9._/-]{0,199}$' -or $Branch -match '(\.\.|//|@\{|(^|/)\.|\.lock$|/$|\.$'){
        Write-Host 'Nombre de rama no valido.' -ForegroundColor Red
        Pause
        return
    }
    & $GitPath -C $Repo.FullName check-ref-format --branch $Branch 2>$null|Out-Null
    if($LASTEXITCODE -ne 0){Write-Host 'Git rechazo el nombre de rama.' -ForegroundColor Red;Pause;return}
    $dirty=& $GitPath -C $Repo.FullName status --porcelain
    if($LASTEXITCODE -ne 0){Write-Host 'No se pudo leer el estado local.' -ForegroundColor Red;Pause;return}
    if($dirty -and (Read-Host 'Hay cambios locales. Continuar con el cambio de rama? (S/N)') -notin @('S','s')){return}

    & $GitPath -C $Repo.FullName checkout --no-guess $Branch

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[OK] Rama activa: $Branch" -ForegroundColor Green
        Add-DevKeySyncRecord -Repository $Repo.Name -Action "checkout" -Result "ok" -Details $Branch
    }
    else {
        Write-Host ""
        Write-Host "[ERROR] No se pudo cambiar de rama." -ForegroundColor Red
        Add-DevKeySyncRecord -Repository $Repo.Name -Action "checkout" -Result "error" -Details $Branch
    }

    Write-Host ""
    Pause
}

function Show-DevKeyCommits {

    $Repo = Read-DevKeyRepoSelection -Title "COMMITS"

    if (-not $Repo) {
        return
    }

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "         COMMITS - $($Repo.Name)" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    & $GitPath -C $Repo.FullName log --oneline --graph --decorate --all -n 25

    Write-Host ""
    Pause
}

function Invoke-DevKeyPush {

    $Repo = Read-DevKeyRepoSelection -Title "PUSH A GITHUB"

    if (-not $Repo) {
        return
    }

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "         PUSH - $($Repo.Name)" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    $Remote = (& $GitPath -C $Repo.FullName remote get-url origin 2>$null | Select-Object -First 1)

    if (-not $Remote) {
        Write-Host "[ERROR] El repositorio no tiene remoto origin." -ForegroundColor Red
        Pause
        return
    }

    $Status = @(& $GitPath -C $Repo.FullName status --porcelain 2>$null)

    if ($Status.Count -gt 0) {

        Write-Host "Cambios locales:" -ForegroundColor Yellow
        $Status | ForEach-Object { Write-Host "  $_" }
        Write-Host ""

        $Message = Read-Host "Mensaje de commit (ENTER para cancelar)"

        if ([string]::IsNullOrWhiteSpace($Message)) {
            Write-Host ""
            Write-Host "Cancelado." -ForegroundColor Yellow
            Pause
            return
        }

        & $GitPath -C $Repo.FullName add -A
        & $GitPath -C $Repo.FullName commit -m $Message

        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "[ERROR] No se pudo crear el commit." -ForegroundColor Red
            Add-DevKeySyncRecord -Repository $Repo.Name -Action "commit" -Result "error" -Details $Message
            Pause
            return
        }

        Write-Host ""
        Write-Host "[OK] Commit creado." -ForegroundColor Green
        Add-DevKeySyncRecord -Repository $Repo.Name -Action "commit" -Result "ok" -Details $Message
    }

    Write-Host ""
    Write-Host "Enviando a GitHub..."
    Write-Host ""

    & $GitPath -C $Repo.FullName push -u origin HEAD

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[OK] Push completado." -ForegroundColor Green
        Add-DevKeySyncRecord -Repository $Repo.Name -Action "push" -Result "ok" -Details $Remote
    }
    else {
        Write-Host ""
        Write-Host "[ERROR] Push fallido." -ForegroundColor Red
        Add-DevKeySyncRecord -Repository $Repo.Name -Action "push" -Result "error" -Details $Remote
    }

    Write-Host ""
    Pause
}

function Show-DevKeySyncHistory {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "     HISTORIAL DE SINCRONIZACION" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Test-Path -LiteralPath $script:DevKeySyncHistoryFile -PathType Leaf)) {
        Write-Host "[--] No hay historial." -ForegroundColor Yellow
        Pause
        return
    }

    try {

        $Records = @(
            Get-Content -LiteralPath $script:DevKeySyncHistoryFile |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                ForEach-Object { $_ | ConvertFrom-Json }
        )

        $Records |
            Select-Object -Last 30 |
            Select-Object timestamp, repository, action, result, details |
            Format-Table -AutoSize
    }
    catch {
        Write-Host "[ERROR] No se pudo leer el historial." -ForegroundColor Red
        Write-Host $_.Exception.Message
    }

    Write-Host ""
    Pause
}

function Show-DevKeyLog {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "            DEVKEY LOG" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Test-Path -LiteralPath $DevKeyLogFile -PathType Leaf)) {
        Write-Host "[--] No existe el log." -ForegroundColor Yellow
        Pause
        return
    }

    Get-Content -LiteralPath $DevKeyLogFile -Tail 120

    Write-Host ""
    Pause
}

