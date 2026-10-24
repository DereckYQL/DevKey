function Get-DevKeyGitHelper {
    foreach($path in @((Join-Path $script:AppsRoot 'Git\mingw64\bin\git-credential-manager.exe'),(Join-Path $script:AppsRoot 'Git\bin\git-credential-manager.exe'),(Join-Path $script:AppsRoot 'Git\mingw64\libexec\git-core\git-credential-wincred.exe'))){if(Test-Path -LiteralPath $path -PathType Leaf){return ($path -replace '\\','/')}}
    $cmd=Get-Command git-credential-manager.exe -ErrorAction SilentlyContinue|Select-Object -First 1
    if($cmd){return ($cmd.Source -replace '\\','/')}
    return $null
}
function Get-DevKeyGitRepositories {
    if(-not(Test-Path -LiteralPath $script:ProjectsRoot -PathType Container)){return @()}
    return @(Get-ChildItem -LiteralPath $script:ProjectsRoot -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName '.git')} | Sort-Object FullName)
}
function Select-DevKeyGitRepository {
    $repos=@(Get-DevKeyGitRepositories)
    if(-not $repos){Write-Host 'No se encontraron repositorios Git.' -ForegroundColor Yellow;return $null}
    for($i=0;$i -lt $repos.Count;$i++){Write-Host (" [{0}] {1}" -f ($i+1),$repos[$i].FullName.Substring($script:ProjectsRoot.Length).TrimStart('\'))}
    $n=0;if(-not[int]::TryParse((Read-Host 'Repositorio (0 cancela)'),[ref]$n) -or $n -lt 1 -or $n -gt $repos.Count){return $null}
    return $repos[$n-1]
}
function Invoke-DevKeyGitStatus {
    $repo=Select-DevKeyGitRepository;if(-not $repo){return}
    & $script:GitPath -C $repo.FullName status --short --branch
    Pause-DevKey
}
function Invoke-DevKeyGitClone {
    $url=Read-Host 'URL HTTPS o SSH del repositorio'
    if($url -notmatch '^(https://[^\s]+|git@[^\s:]+:[^\s]+)$'){Write-Host 'URL no valida.' -ForegroundColor Yellow;Pause-DevKey;return}
    if($url -match '/([^/]+?)(\.git)?$'){$name=$Matches[1]}elseif($url -match ':([^/]+?)(\.git)?$'){$name=$Matches[1]}else{Write-Host 'No se pudo obtener el nombre destino.';return}
    try{$dest=Get-DevKeySafeProjectPath $name;if(Test-Path -LiteralPath $dest){throw 'El destino ya existe.'};& $script:GitPath clone -- $url $dest;if($LASTEXITCODE -ne 0){throw 'git clone fallo; revisa red y autenticacion.'};Write-DevKeyLog -Log maintenance.log -Message "Git clone completed: $name"}catch{Write-Host $_.Exception.Message -ForegroundColor Red}
    Pause-DevKey
}
function Invoke-DevKeyGitPull {
    $repo=Select-DevKeyGitRepository;if(-not $repo){return}
    $status=& $script:GitPath -C $repo.FullName status --porcelain
    if($LASTEXITCODE -ne 0){Write-Host 'No se pudo consultar el estado; pull cancelado.' -ForegroundColor Red;Pause-DevKey;return}
    if($status){Write-Host 'Hay cambios locales. Guarda o confirma esos cambios antes de actualizar.' -ForegroundColor Yellow;Pause-DevKey;return}
    if((Read-Host 'Repositorio limpio. Ejecutar pull --ff-only? (S/N)') -in @('S','s')){& $script:GitPath -C $repo.FullName pull --ff-only;if($LASTEXITCODE -ne 0){Write-Host 'Pull fallo; revisa la rama y el remoto.' -ForegroundColor Red}else{Write-DevKeyLog -Log maintenance.log -Message "Git pull completed: $($repo.Name)"}}
    Pause-DevKey
}
function Invoke-DevKeyGitPush {
    $repo=Select-DevKeyGitRepository;if(-not $repo){return}
    & $script:GitPath -C $repo.FullName status --short --branch
    if((Read-Host 'Enviar la rama actual al remoto? (S/N)') -in @('S','s')){& $script:GitPath -C $repo.FullName push;if($LASTEXITCODE -ne 0){Write-Host 'Push fallo; revisa autenticacion y upstream.' -ForegroundColor Red}else{Write-DevKeyLog -Log maintenance.log -Message "Git push completed: $($repo.Name)"}}
    Pause-DevKey
}
function Invoke-DevKeyGitCommit {
    $repo=Select-DevKeyGitRepository;if(-not $repo){return}
    & $script:GitPath -C $repo.FullName status --short
    if($LASTEXITCODE -ne 0){Write-Host 'No se pudo consultar el estado.';Pause-DevKey;return}
    if((Read-Host 'Preparar todos los cambios mostrados para commit? (S/N)') -notin @('S','s')){return}
    $message=Read-Host 'Mensaje del commit';if([string]::IsNullOrWhiteSpace($message)){Write-Host 'Mensaje vacio; commit cancelado.';return}
    & $script:GitPath -C $repo.FullName add --all
    if($LASTEXITCODE -ne 0){Write-Host 'No se pudieron preparar los cambios.' -ForegroundColor Red;Pause-DevKey;return}
    & $script:GitPath -C $repo.FullName commit -m $message
    if($LASTEXITCODE -eq 0){Write-DevKeyLog -Log maintenance.log -Message "Git commit created in $($repo.Name)."}else{Write-Host 'Commit fallo.' -ForegroundColor Red}
    Pause-DevKey
}
function Get-DevKeyGitSettings {
    if(-not(Test-Path -LiteralPath $script:GitConfigFile -PathType Leaf)){return [pscustomobject]@{'user.name'='';'user.email'='';defaultBranch='main';credentialHelper=''}}
    try{return (Get-Content -LiteralPath $script:GitConfigFile -Raw -ErrorAction Stop|ConvertFrom-Json -ErrorAction Stop)}catch{throw 'Config\git.json no es valido y se conserva sin cambios.'}
}
function Save-DevKeyGitSettings {
    param([Parameter(Mandatory=$true)]$Settings)
    if(Test-Path -LiteralPath $script:GitConfigFile -PathType Leaf){Copy-Item -LiteralPath $script:GitConfigFile -Destination (Join-Path $script:BackupsRoot ('git-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'.json')) -ErrorAction Stop}
    $temp=$script:GitConfigFile+'.tmp'
    try{$Settings|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $temp -Encoding UTF8 -ErrorAction Stop;Move-Item -LiteralPath $temp -Destination $script:GitConfigFile -Force -ErrorAction Stop}catch{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue;throw 'No se pudo guardar git.json; el original se conserva.'}
}
function Show-DevKeyGitConfiguration {
    try{$settings=Get-DevKeyGitSettings}catch{Write-Host $_.Exception.Message -ForegroundColor Red;Pause-DevKey;return}
    $repo=Select-DevKeyGitRepository
    $name=Read-Host ("user.name [{0}]" -f $settings.'user.name');$email=Read-Host ("user.email [{0}]" -f $settings.'user.email')
    if([string]::IsNullOrWhiteSpace($name)){$name=[string]$settings.'user.name'}
    if([string]::IsNullOrWhiteSpace($email)){$email=[string]$settings.'user.email'}
    if([string]::IsNullOrWhiteSpace($name) -or $email -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$'){Write-Host 'Identidad no valida.' -ForegroundColor Yellow;Pause-DevKey;return}
    $scope=Read-Host 'Aplicar [R]epositorio (recomendado) o [G]lobal al usuario'
    if($scope -in @('G','g')){if((Read-Host 'Confirmas el cambio global para este equipo? (S/N)') -notin @('S','s')){return};& $script:GitPath config --global user.name $name;if($LASTEXITCODE -ne 0){throw 'git config global user.name fallo.'};& $script:GitPath config --global user.email $email}
    elseif($scope -in @('R','r') -and $repo){& $script:GitPath -C $repo.FullName config user.name $name;if($LASTEXITCODE -ne 0){throw 'git config local user.name fallo.'};& $script:GitPath -C $repo.FullName config user.email $email}
    else{Write-Host 'Seleccion de alcance cancelada.';return}
    if($LASTEXITCODE -eq 0){$settings.'user.name'=$name;$settings.'user.email'=$email;Save-DevKeyGitSettings -Settings $settings;Write-Host 'Identidad Git configurada.' -ForegroundColor Green;Write-DevKeyLog -Log maintenance.log -Message 'Git identity configured.'}else{Write-Host 'No se pudo configurar Git.' -ForegroundColor Red}
    Pause-DevKey
}
function Show-DevKeyGit {
    if(-not(Test-Path -LiteralPath $script:GitPath -PathType Leaf)){Write-Host 'Git no esta disponible (portable ni PATH).';return}
    while($true){
        Clear-Host;Write-Host 'GIT / GITHUB' -ForegroundColor Cyan
        Write-Host ' [1] Estado';Write-Host ' [2] Clonar';Write-Host ' [3] Pull seguro';Write-Host ' [4] Push';Write-Host ' [5] Crear commit';Write-Host ' [6] Configurar identidad Git';Write-Host ' [7] Credenciales GitHub';Write-Host ' [8] Backups de Projects';Write-Host ' [9] Ramas';Write-Host ' [10] Historial de commits';Write-Host ' [11] Sincronizar repositorios limpios';Write-Host ' [12] Historial de sincronizacion';Write-Host ' [13] Ver log DevKey';Write-Host ' [0] Volver'
        $o=Read-Host 'Opcion'
        switch($o){
            '1'{Invoke-DevKeyGitStatus}
            '2'{Invoke-DevKeyGitClone}
            '3'{Invoke-DevKeyGitPull}
            '4'{Invoke-DevKeyGitPush}
            '5'{Invoke-DevKeyGitCommit}
            '6'{Show-DevKeyGitConfiguration}
            '7'{Show-GitCredentialMenu}
            '8'{Show-DevKeyBackupMenu}
            '9'{Show-DevKeyBranches}
            '10'{Show-DevKeyCommits}
            '11'{Sync-DevKeyRepositories;Pause-DevKey}
            '12'{Show-DevKeySyncHistory}
            '13'{Show-DevKeyLog}
            '0'{return}
            default{Write-Host 'Opcion no valida.' -ForegroundColor Yellow;Start-Sleep -Seconds 1}
        }
    }
}
