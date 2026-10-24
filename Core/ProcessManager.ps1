$script:DevKeyStartedProcesses = @()
$script:DevKeySessionFile = Join-Path $script:RuntimeRoot 'managed-processes.json'

function Start-DevKeyManagedProcess {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [string[]]$ArgumentList=@(),
        [string]$WorkingDirectory=(Split-Path -Parent $FilePath),
        [string]$Application=''
    )
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { throw "Ejecutable no encontrado: $FilePath" }
    $resolved=(Resolve-Path -LiteralPath $FilePath -ErrorAction Stop).Path
    $argsText=(@($ArgumentList | ForEach-Object { if ($_ -match '[\s"]') { '"'+($_ -replace '(\\*)"','$1$1\"' -replace '(\\+)$','$1$1')+'"' } else { $_ } }) -join ' ')
    $parameters=@{FilePath=$resolved;WorkingDirectory=$WorkingDirectory;PassThru=$true;ErrorAction='Stop'}
    if ($argsText) { $parameters.ArgumentList=$argsText }
    $proc=Start-Process @parameters
    try { $started=$proc.StartTime.ToUniversalTime().ToString('o') } catch { $started=[datetime]::UtcNow.ToString('o') }
    $record=[pscustomobject]@{Pid=$proc.Id;Path=$resolved;StartedUtc=$started;Application=$Application;SessionId=$script:DevKeySessionId}
    $script:DevKeyStartedProcesses+=,$record
    try { $script:DevKeyStartedProcesses | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:DevKeySessionFile -Encoding UTF8 -ErrorAction Stop } catch { }
    Write-DevKeyLog -Log guardian.log -Level INFO -Message ("Proceso iniciado: $Application (PID $($proc.Id)).")
    return $proc
}

function Get-DevKeyOwnedProcess {
    param($Record)
    try {
        $p=Get-Process -Id ([int]$Record.Pid) -ErrorAction Stop
        if ([Math]::Abs(($p.StartTime.ToUniversalTime()-[datetime]::Parse([string]$Record.StartedUtc).ToUniversalTime()).TotalSeconds) -gt 3) { return $null }
        $path=$p.Path
        if (-not $path -or -not [string]::Equals([IO.Path]::GetFullPath($path),[IO.Path]::GetFullPath([string]$Record.Path),[StringComparison]::OrdinalIgnoreCase)) { return $null }
        return $p
    } catch { return $null }
}

function Stop-DevKeyManagedProcesses {
    param([switch]$Removal)
    $force=($Removal -and [bool]$script:DevKeyConfig.Guardian.ForceCloseOnRemoval)
    $timeout=[Math]::Max(1,[int]$script:DevKeyConfig.Guardian.ForceCloseAfterSeconds)
    foreach ($record in @($script:DevKeyStartedProcesses)) {
        $appConfig=$script:DevKeyConfig.Applications.($record.Application)
        if($record.Application -like 'Terminal:*'){$appConfig=[pscustomobject]@{AutoClose=$true}}
        if($appConfig -and -not [bool]$appConfig.AutoClose){Write-DevKeyLog -Log guardian.log -Level INFO -Message ("AutoClose disabled for $($record.Application) (PID $($record.Pid)).");continue}
        $p=Get-DevKeyOwnedProcess $record
        if (-not $p) { continue }
        try { if ($p.MainWindowHandle -ne 0) { [void]$p.CloseMainWindow() } } catch { }
        try { if (-not $p.WaitForExit($timeout*1000) -and $force) { $again=Get-DevKeyOwnedProcess $record; if ($again) { Stop-Process -Id $again.Id -Force -ErrorAction SilentlyContinue } } } catch { }
        Write-DevKeyLog -Log guardian.log -Level AUDIT -Message ("Cierre solicitado: $($record.Application) (PID $($record.Pid)); cierre forzado=$force.")
    }
    $script:DevKeyStartedProcesses=@()
    Remove-Item -LiteralPath $script:DevKeySessionFile -Force -ErrorAction SilentlyContinue
}
function Get-DevKeyTrackedProcesses { @($script:DevKeyStartedProcesses | Where-Object { Get-DevKeyOwnedProcess $_ }) }
