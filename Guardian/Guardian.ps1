param([Parameter(Mandatory=$true)][int]$ParentProcessId,[Parameter(Mandatory=$true)][string]$SessionId)

$ErrorActionPreference='Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Core\PathManager.ps1')
Initialize-DevKeyPaths
. (Join-Path $script:CoreRoot 'Bootstrap.ps1')
. (Join-Path $script:CoreRoot 'ErrorHandler.ps1')
. (Join-Path $script:CoreRoot 'ProcessManager.ps1')
. (Join-Path $script:SecurityRoot 'Authentication.ps1')
. (Join-Path $script:SecurityRoot 'Integrity.ps1')
. (Join-Path $script:GuardianRoot 'GuardianManager.ps1')
Import-DevKeyConfiguration

$mutex=$null
try {
    $created=$false
    $mutex=New-Object Threading.Mutex($false,('Local\DevKeyGuardian-'+$SessionId),[ref]$created)
    if(-not $created){Write-Host 'Ya existe un Guardian para esta sesion.';return}

    $parent=Get-CimInstance Win32_Process -Filter "ProcessId = $ParentProcessId" -ErrorAction Stop
    $launcher=Join-Path $script:LauncherRoot 'DevKey.ps1'
    if(-not $parent -or $parent.CommandLine.IndexOf($launcher,[StringComparison]::OrdinalIgnoreCase) -lt 0){Write-Host 'La sesion de origen no se pudo validar.' -ForegroundColor Red;return}
    if(-not(Test-DevKeyGuardianPresence)){Write-Host 'La unidad no coincide con la identidad configurada.' -ForegroundColor Red;return}

    $script:DevKeySessionFile=Join-Path $script:RuntimeRoot 'managed-processes.json'
    $stopPath=Join-Path $script:RuntimeRoot ('guardian-stop-'+$SessionId+'.flag')
    $lastRecords=@();$misses=0
    Write-Host 'DEVKEY GUARDIAN - monitor visible' -ForegroundColor Cyan
    Write-Host 'Pulsa Q para salir manualmente. La extraccion de la unidad solicitara el cierre ordenado.'
    Write-DevKeyLog -Log guardian.log -Level INFO -Message 'Guardian worker monitoring session.'
    while($true){
        if(Test-Path -LiteralPath $stopPath -PathType Leaf){Write-DevKeyLog -Log guardian.log -Level INFO -Message 'Guardian stopped by launcher.';break}
        $parentAlive=$true
        try { $null=Get-Process -Id $ParentProcessId -ErrorAction Stop } catch { $parentAlive=$false }
        if(-not $parentAlive){$misses=2}
        elseif(Test-DevKeyGuardianPresence){
            $misses=0
            try { if(Test-Path -LiteralPath $script:DevKeySessionFile -PathType Leaf){$read=Get-Content -LiteralPath $script:DevKeySessionFile -Raw -ErrorAction Stop|ConvertFrom-Json -ErrorAction Stop;$lastRecords=@($read|Where-Object {$_.SessionId -eq $SessionId})} } catch { }
        } else { $misses++ }
        if($misses -ge 2){
            Write-Host 'Unidad ausente o identidad alterada. Cerrando aplicaciones iniciadas por esta sesion.' -ForegroundColor Yellow
            Write-DevKeyLog -Log guardian.log -Level AUDIT -Message 'Unit removal/interruption detected; cooperative close requested.'
            if($script:DevKeyConfig.Guardian.AutoClose){$script:DevKeyStartedProcesses=@($lastRecords);Stop-DevKeyManagedProcesses -Removal}
            break
        }
        try { if([Console]::KeyAvailable -and [Console]::ReadKey($true).Key -eq 'Q'){Write-DevKeyLog -Log guardian.log -Level INFO -Message 'Guardian stopped manually.';break} } catch { }
        Start-Sleep -Seconds ([int]$script:DevKeyConfig.Guardian.CheckIntervalSeconds)
    }
    Write-Host 'Guardian detenido.'
} catch {
    Write-DevKeyLog -Log guardian.log -Level ERROR -Message ('Guardian monitor error: '+$_.Exception.GetType().Name)
    Write-Host 'Guardian se detuvo por un error. Revisa Logs\guardian.log si la unidad sigue conectada.' -ForegroundColor Red
} finally {
    if($mutex){try{$mutex.ReleaseMutex()}catch{};$mutex.Dispose()}
}
