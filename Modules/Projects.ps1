function Get-DevKeySafeProjectPath {
    param([Parameter(Mandatory=$true)][string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name -match '^[ .]' -or $Name -match '[<>:"/\\|?*\x00-\x1F]' -or $Name -match '[ .]$' -or $Name -in @('.','..')) { throw 'Invalid project name.' }
    if ($Name -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') { throw 'That name is reserved by Windows.' }
    $rootPath=[IO.Path]::GetFullPath($script:ProjectsRoot)
    if(Test-Path -LiteralPath $rootPath -PathType Container){$rootPath=(Resolve-Path -LiteralPath $rootPath -ErrorAction Stop).ProviderPath}
    $root=$rootPath.TrimEnd('\')+'\'
    $path=[IO.Path]::GetFullPath((Join-Path $root $Name))
    if (-not $path.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)) { throw 'Project path is outside Projects.' }
    if(Test-Path -LiteralPath $path){$realPath=(Resolve-Path -LiteralPath $path -ErrorAction Stop).ProviderPath;if(-not $realPath.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw 'Project resolves outside the authorized Projects directory.'};return $realPath}
    return $path
}
function Get-DevKeyProjectDirectories { @(Get-ChildItem -LiteralPath $script:ProjectsRoot -Directory -Force -ErrorAction SilentlyContinue | Sort-Object Name) }
function Show-DevKeyProjects {
    if (-not (Test-Path -LiteralPath $script:ProjectsRoot -PathType Container)) { New-Item -ItemType Directory -Path $script:ProjectsRoot -Force -ErrorAction Stop | Out-Null }
    while ($true) {
        Clear-Host;Write-Host "PROJECTS: $script:ProjectsRoot" -ForegroundColor Cyan
        Write-Host ' [1] Listar';Write-Host ' [2] Crear proyecto';Write-Host ' [3] Abrir proyecto';Write-Host ' [4] Renombrar proyecto';Write-Host ' [5] Eliminar proyecto';Write-Host ' [6] Terminal en proyecto';Write-Host ' [7] Inicializar Git';Write-Host ' [8] Crear desde plantilla';Write-Host ' [9] Biblioteca de prompts';Write-Host ' [0] Volver'
        $option=Read-Host 'Opcion'
        try {
            switch ($option) {
                '1' { $items=Get-DevKeyProjectDirectories;if($items){$items|Select-Object -ExpandProperty Name}else{Write-Host 'No hay proyectos.'};Pause-DevKey }
                '2' { $name=Read-Host 'Nombre';$path=Get-DevKeySafeProjectPath $name;if(Test-Path -LiteralPath $path){throw 'That project already exists.'};New-Item -ItemType Directory -Path $path -ErrorAction Stop|Out-Null;Write-DevKeyLog -Log maintenance.log -Message "Project created: $name";Write-Host 'Proyecto creado.' -ForegroundColor Green;Pause-DevKey }
                '3' { $name=Read-Host 'Nombre';$path=Get-DevKeySafeProjectPath $name;if(-not(Test-Path -LiteralPath $path -PathType Container)){throw 'Project not found.'};Start-Process -FilePath 'explorer.exe' -ArgumentList ('"'+$path+'"') -ErrorAction Stop }
                '4' { $old=Read-Host 'Nombre actual';$source=Get-DevKeySafeProjectPath $old;if(-not(Test-Path -LiteralPath $source -PathType Container)){throw 'Project not found.'};$new=Read-Host 'Nombre nuevo';$dest=Get-DevKeySafeProjectPath $new;if(Test-Path -LiteralPath $dest){throw 'Destination already exists.'};Move-Item -LiteralPath $source -Destination $dest -ErrorAction Stop;Write-DevKeyLog -Log maintenance.log -Message "Project renamed: $old";Pause-DevKey }
                '5' { $name=Read-Host 'Nombre';$path=Get-DevKeySafeProjectPath $name;if(-not(Test-Path -LiteralPath $path -PathType Container)){throw 'Project not found.'};if((Read-Host "Escribe ELIMINAR para borrar $name") -ceq 'ELIMINAR'){Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop;Write-DevKeyLog -Log maintenance.log -Level AUDIT -Message "Project deleted: $name"} }
                '6' { $name=Read-Host 'Nombre';$path=Get-DevKeySafeProjectPath $name;if(-not(Test-Path -LiteralPath $path -PathType Container)){throw 'Project not found.'};$ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe';$code="Set-Location -LiteralPath '$path'";$encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code));[void](Start-DevKeyManagedProcess -FilePath $ps -ArgumentList @('-NoExit','-NoProfile','-EncodedCommand',$encoded) -WorkingDirectory $path -Application "Terminal:$name") }
                '7' { if(-not(Test-Path -LiteralPath $script:GitPath -PathType Leaf)){throw 'Portable Git not found.'};$name=Read-Host 'Nombre';$path=Get-DevKeySafeProjectPath $name;if(-not(Test-Path -LiteralPath $path -PathType Container)){throw 'Project not found.'};if(Test-Path -LiteralPath (Join-Path $path '.git')){throw 'Git is already initialized.'};& $script:GitPath -C $path init;if($LASTEXITCODE -ne 0){throw 'git init failed.'};Write-DevKeyLog -Log maintenance.log -Message "Git initialized: $name";Pause-DevKey }
                '8' { New-DevKeyProjectFromTemplate }
                '9' { Show-DevKeyPromptLibrary }
                '0' { return }
                default { Write-Host 'Opcion no valida.' -ForegroundColor Yellow;Start-Sleep -Seconds 1 }
            }
        } catch { Write-Host $_.Exception.Message -ForegroundColor Red;Pause-DevKey }
    }
}
