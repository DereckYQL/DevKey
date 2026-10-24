$ErrorActionPreference='Continue'
$hostWatcherRoot=Join-Path $env:LOCALAPPDATA 'DevKey\Guardian'
$configPath=Join-Path $hostWatcherRoot 'host-config.json'
$logPath=Join-Path $hostWatcherRoot 'guardian-host.log'
function Write-HostWatcherLog([string]$Message){if($script:HostSettings -and -not [bool]$script:HostSettings.LogEvents){return};try{Add-Content -LiteralPath $logPath -Value ("{0:o} {1}" -f (Get-Date),($Message -replace '[\r\n]',' ')) -Encoding UTF8}catch{}}
function Get-HostWatcherUsbRoot {
    param([string]$ExpectedSerial)
    foreach($drive in @(Get-PSDrive -PSProvider FileSystem)){
        $root=$drive.Root
        try {
            $logical=Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $root.TrimEnd('\')) -ErrorAction Stop
            if(-not $logical -or [int]$logical.DriveType -ne 2){continue}
            $serial=('{0:X8}' -f [Convert]::ToUInt32([string]$logical.VolumeSerialNumber,16))
            if($serial -cne $ExpectedSerial){continue}
            $key=Join-Path $root 'unlock.k3y'
            $dev=Join-Path $root 'DevKey'
            $launcher=Join-Path $dev 'Launcher\DevKey.ps1'
            $config=Join-Path $dev 'Config\config.json'
            if(-not(Test-Path -LiteralPath $key -PathType Leaf) -or -not(Test-Path -LiteralPath $launcher -PathType Leaf) -or -not(Test-Path -LiteralPath $config -PathType Leaf)){continue}
            $hash=(Get-FileHash -LiteralPath $key -Algorithm SHA256 -ErrorAction Stop).Hash
            $conf=Get-Content -LiteralPath $config -Raw -ErrorAction Stop|ConvertFrom-Json -ErrorAction Stop
            if($hash -ceq [string]$conf.Security.TokenSha256 -and $hash -ceq [string]$script:HostSettings.TokenSha256 -and (Test-HostWatcherIntegrity -DevRoot $dev)){return [pscustomobject]@{Root=$root;DevKey=$dev;Launcher=$launcher;Config=$conf}}
        }catch{}
    }
    return $null
}
function Test-HostWatcherIntegrity([string]$DevRoot){
    $manifestPath=Join-Path $DevRoot 'Config\manifests\integrity.json'
    if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){return $true}
    try{$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json -ErrorAction Stop;if([int]$manifest.Version -ne 1 -or [string]$manifest.Trust -ne 'UNSIGNED-LOCAL' -or -not $manifest.Files){return $false};$base=[IO.Path]::GetFullPath($DevRoot).TrimEnd('\')+'\';foreach($item in $manifest.Files){$relative=[string]$item.Path;if([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[/\\])\.\.([/\\]|$)' -or [string]$item.SHA256 -notmatch '^[A-Fa-f0-9]{64}$'){return $false};$file=[IO.Path]::GetFullPath((Join-Path $DevRoot $relative));if(-not $file.StartsWith($base,[StringComparison]::OrdinalIgnoreCase) -or -not(Test-Path -LiteralPath $file -PathType Leaf)){return $false};$resolved=(Resolve-Path -LiteralPath $file -ErrorAction Stop).ProviderPath;if(-not $resolved.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)){return $false};if((Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash -cne [string]$item.SHA256){return $false}};return $true}catch{return $false}
}
function Get-HostWatcherOwnedProcess($Record){
    try{$p=Get-Process -Id ([int]$Record.Pid) -ErrorAction Stop;if([Math]::Abs(($p.StartTime.ToUniversalTime()-[datetime]::Parse([string]$Record.StartedUtc).ToUniversalTime()).TotalSeconds) -gt 3){return $null};if(-not [string]::Equals([IO.Path]::GetFullPath($p.Path),[IO.Path]::GetFullPath([string]$Record.Path),[StringComparison]::OrdinalIgnoreCase)){return $null};return $p}catch{return $null}
}
function Stop-HostWatcherProcesses([object[]]$Records,[bool]$Force,[int]$Timeout){
    foreach($record in $Records){$p=Get-HostWatcherOwnedProcess $record;if(-not$p){continue};try{if($p.MainWindowHandle -ne 0){[void]$p.CloseMainWindow()};if(-not$p.WaitForExit([Math]::Max(1,$Timeout)*1000) -and $Force){$again=Get-HostWatcherOwnedProcess $record;if($again){Stop-Process -Id $again.Id -Force -ErrorAction SilentlyContinue}}}catch{}}
}
try{$script:HostSettings=Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop|ConvertFrom-Json -ErrorAction Stop}catch{Write-Host 'DevKey host watcher configuration is missing or invalid.' -ForegroundColor Red;exit 2}
if(-not $script:HostSettings.Enabled){Write-Host 'AutoLaunch watcher is disabled.';exit 0}
Write-Host 'DEVKEY USB WATCHER (visible, current user). Press Q to quit.' -ForegroundColor Cyan
Write-HostWatcherLog 'Watcher started.'
$lastRoot=$null;$lastConfig=$null;$misses=0;$records=@();$launcherProcess=$null;$launchedForCurrentConnection=$false
while($true){
    if([Console]::KeyAvailable -and [Console]::ReadKey($true).Key -eq 'Q'){break}
    $found=Get-HostWatcherUsbRoot -ExpectedSerial ([string]$script:HostSettings.VolumeSerial)
    if($found){
        if(-not $found.Config.Guardian.Enabled -or -not $found.Config.Guardian.AutoLaunch){Write-Host 'AutoLaunch se desactivo en config.json.';Write-HostWatcherLog 'Watcher stopped because AutoLaunch is disabled on the USB.';break}
        $lastRoot=$found.Root;$lastConfig=$found.Config;$misses=0
        $script:HostSettings.AutoClose=[bool]$found.Config.Guardian.AutoClose
        $script:HostSettings.LogEvents=[bool]$found.Config.Guardian.LogEvents
        $script:HostSettings.ForceCloseOnRemoval=[bool]$found.Config.Guardian.ForceCloseOnRemoval
        $script:HostSettings.ForceCloseAfterSeconds=[int]$found.Config.Guardian.ForceCloseAfterSeconds
        $sessionFile=Join-Path $found.DevKey 'Data\Runtime\managed-processes.json'
        try{if(Test-Path -LiteralPath $sessionFile -PathType Leaf){$read=Get-Content -LiteralPath $sessionFile -Raw|ConvertFrom-Json -ErrorAction Stop;$records=@($records+@($read)|Sort-Object Pid,StartedUtc -Unique)}}catch{}
        $alive=$false
        if($launcherProcess){try{$alive=(-not $launcherProcess.HasExited)}catch{}}
        if(-not $alive -and -not $launchedForCurrentConnection){
            $running=Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction SilentlyContinue | Where-Object {$_.CommandLine -and $_.CommandLine.IndexOf($found.Launcher,[StringComparison]::OrdinalIgnoreCase) -ge 0}
            if(-not $running){try{$powershell=Join-Path $PSHOME 'powershell.exe';$launcherProcess=Start-Process -FilePath $powershell -ArgumentList ('-NoProfile -File "'+$found.Launcher+'"') -WorkingDirectory $found.DevKey -PassThru -ErrorAction Stop;Write-Host "DevKey launcher started from $($found.Root).";Write-HostWatcherLog 'Launcher started after USB verification.';$launchedForCurrentConnection=$true}catch{Write-Host 'Could not start DevKey launcher.' -ForegroundColor Red;Write-HostWatcherLog 'Launcher start failed.'}}
            else{$launchedForCurrentConnection=$true}
        }
    }elseif($lastRoot){
        $misses++
        if($misses -ge 2){Write-Host 'DevKey USB removed; requesting cooperative close for this watcher session.' -ForegroundColor Yellow;Write-HostWatcherLog 'USB removal detected.';if($script:HostSettings.AutoClose){$close=@($records|Where-Object {if($_.Application -like 'Terminal:*'){$true}else{$app=$lastConfig.Applications.([string]$_.Application);(-not $app -or [bool]$app.AutoClose)}});Stop-HostWatcherProcesses -Records $close -Force ([bool]$script:HostSettings.ForceCloseOnRemoval) -Timeout ([int]$script:HostSettings.ForceCloseAfterSeconds)};$records=@();$lastRoot=$null;$lastConfig=$null;$launcherProcess=$null;$launchedForCurrentConnection=$false}
    }
    Start-Sleep -Seconds 2
}
Write-HostWatcherLog 'Watcher stopped manually.'
