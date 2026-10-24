function Get-DevKeyApplicationPath {
    param([Parameter(Mandatory=$true)][ValidateSet('Kiro','OpenCode','Git','Node','Docker')][string]$Name)
    $app=$script:DevKeyConfig.Applications.$Name
    if (-not $app -or -not $app.Enabled) { return $null }
    $candidate=[string]$app.Path
    if (-not [string]::IsNullOrWhiteSpace($candidate)) {
        if ([IO.Path]::IsPathRooted($candidate)) { $path=[IO.Path]::GetFullPath($candidate) }
        else { $path=[IO.Path]::GetFullPath((Join-Path $script:UsbRoot $candidate)) }
        if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    }
    $systemCandidates=@()
    switch($Name){
        'Kiro' {
            if($env:LOCALAPPDATA){$systemCandidates+=,(Join-Path $env:LOCALAPPDATA 'Programs\Kiro\Kiro.exe')}
            $command=Get-Command 'kiro.exe','kiro.cmd' -ErrorAction SilentlyContinue | Select-Object -First 1
            if($command -and $command.Source){
                if([IO.Path]::GetExtension($command.Source) -ieq '.cmd'){
                    $installRoot=Split-Path -Parent (Split-Path -Parent $command.Source)
                    $systemCandidates+=,(Join-Path $installRoot 'Kiro.exe')
                }else{$systemCandidates+=,$command.Source}
            }
        }
        'OpenCode' {
            $command=Get-Command 'opencode.exe','opencode.cmd','opencode.ps1' -ErrorAction SilentlyContinue | Select-Object -First 1
            if($command -and $command.Source){
                if([IO.Path]::GetExtension($command.Source) -in @('.cmd','.ps1')){
                    $npmBin=Split-Path -Parent $command.Source
                    $systemCandidates+=,(Join-Path $npmBin 'node_modules\opencode-ai\bin\opencode.exe')
                }else{$systemCandidates+=,$command.Source}
            }
            if($env:APPDATA){$systemCandidates+=,(Join-Path $env:APPDATA 'npm\node_modules\opencode-ai\bin\opencode.exe')}
        }
        'Git' { $command=Get-Command 'git.exe' -ErrorAction SilentlyContinue | Select-Object -First 1; if($command -and $command.Source){$systemCandidates+=,$command.Source} }
        'Node' { $command=Get-Command 'node.exe' -ErrorAction SilentlyContinue | Select-Object -First 1; if($command -and $command.Source){$systemCandidates+=,$command.Source} }
        'Docker' {
            if($env:LOCALAPPDATA){$systemCandidates+=,(Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\Docker Desktop.exe')}
            if($env:ProgramFiles){$systemCandidates+=,(Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe')}
            $command=Get-Command 'docker.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
            if($command -and $command.Source){$systemCandidates+=,$command.Source}
        }
    }
    foreach($systemPath in $systemCandidates){
        if(-not $systemPath){continue}
        try{if(Test-Path -LiteralPath $systemPath -PathType Leaf -ErrorAction Stop){return [IO.Path]::GetFullPath($systemPath)}}catch{continue}
    }
    return $null
}

function Start-DevKeyApplication {
    param([Parameter(Mandatory=$true)][ValidateSet('Kiro','OpenCode')][string]$Name)
    $path=Get-DevKeyApplicationPath -Name $Name
    if (-not $path) { Write-Host "$Name no esta disponible. Revisa Applications.$Name.Path en Config\config.json." -ForegroundColor Yellow; return $false }
    $processNames=@([IO.Path]::GetFileNameWithoutExtension($path))
    if($Name -eq 'Kiro'){$processNames+=,'Kiro'}
    if($Name -eq 'OpenCode'){$processNames+=,'OpenCode';$processNames+=,'opencode'}
    $existing=@(Get-Process -Name $processNames -ErrorAction SilentlyContinue)
    if($existing.Count){
        Write-Host "$Name ya esta abierto. Se conserva ese proceso y no se agrega a la sesion DevKey." -ForegroundColor Yellow
        Write-DevKeyLog -Log guardian.log -Level INFO -Message ("Existing $Name process detected; left untouched.")
        return $false
    }
    $args=@()
    if ($Name -eq 'Kiro') { $args=@('--user-data-dir',$script:KiroData) }
    $hadXdgConfigHome=Test-Path Env:\XDG_CONFIG_HOME
    $oldXdgConfigHome=$env:XDG_CONFIG_HOME
    try {
        if($Name -eq 'OpenCode'){$env:XDG_CONFIG_HOME=Join-Path $script:DataRoot 'OpenCode\Config'}
        [void](Start-DevKeyManagedProcess -FilePath $path -ArgumentList $args -WorkingDirectory (Split-Path -Parent $path) -Application $Name)
        Write-Host "$Name iniciado." -ForegroundColor Green
        return $true
    } catch {
        Write-DevKeyLog -Level ERROR -Message ("No se pudo iniciar ${Name}: "+$_.Exception.GetType().Name)
        Write-Host "No se pudo iniciar $Name." -ForegroundColor Red
        return $false
    } finally {
        if($hadXdgConfigHome){$env:XDG_CONFIG_HOME=$oldXdgConfigHome}else{Remove-Item Env:\XDG_CONFIG_HOME -ErrorAction SilentlyContinue}
    }
}
function Pause-DevKey { [void](Read-Host 'Pulsa ENTER para continuar') }
