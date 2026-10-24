$script:DevKeyPromptCategories=@('General','Frontend','Backend','APIs','Databases','Defensive-Security','Code-Review','Testing','Documentation','Diagnostics','Architecture')
function Get-DevKeyPromptFiles {
    $root=Join-Path $script:DataRoot 'Prompts'
    if(-not(Test-Path -LiteralPath $root -PathType Container)){New-Item -ItemType Directory -Path $root -Force|Out-Null}
    return @(Get-ChildItem -LiteralPath $root -Filter '*.txt' -File -Recurse -ErrorAction SilentlyContinue|Sort-Object FullName)
}
function Get-DevKeyPromptPath {
    param([Parameter(Mandatory=$true)][string]$Name,[string]$Category='General')
    if($Name -notmatch '^[\w -]{1,60}$' -or $Name -match '[ .]$'){throw 'Nombre de prompt invalido.'}
    if($Category -notin $script:DevKeyPromptCategories){throw 'Categoria invalida.'}
    $root=Join-Path $script:DataRoot 'Prompts';if($Category -eq 'General'){$folder=$root}else{$folder=Join-Path $root $Category}
    if(-not(Test-Path -LiteralPath $folder -PathType Container)){New-Item -ItemType Directory -Path $folder -Force|Out-Null}
    return (Join-Path $folder ($Name+'.txt'))
}
function Read-DevKeyPromptCategory {
    for($i=0;$i -lt $script:DevKeyPromptCategories.Count;$i++){Write-Host (" [{0}] {1}" -f ($i+1),$script:DevKeyPromptCategories[$i])}
    $number=0;if(-not[int]::TryParse((Read-Host 'Categoria'),[ref]$number) -or $number -lt 1 -or $number -gt $script:DevKeyPromptCategories.Count){return $null}
    return $script:DevKeyPromptCategories[$number-1]
}
function Read-DevKeyPromptText {
    Write-Host 'Escribe el prompt; un punto (.) en una linea termina. El contenido no se registra.' -ForegroundColor DarkGray
    $lines=New-Object System.Collections.Generic.List[string]
    while($true){$line=Read-Host;if($line -ceq '.'){break};$lines.Add($line)}
    return ($lines -join [Environment]::NewLine)
}
function Get-DevKeyPromptDisplayName {
    param($File)
    $root=(Join-Path $script:DataRoot 'Prompts').TrimEnd('\')+'\'
    return ($File.FullName.Substring($root.Length) -replace '\.txt$','' -replace '\\','/')
}
function Backup-DevKeyPromptFile {
    param([string]$Path)
    $destination=Join-Path $script:BackupsRoot ('prompt-'+[guid]::NewGuid().ToString('N')+'.txt')
    Copy-Item -LiteralPath $Path -Destination $destination -ErrorAction Stop
    return $destination
}
function Show-DevKeyPromptLibrary {
    $null=Get-DevKeyPromptFiles
    while($true){
        Clear-Host;Write-Host 'BIBLIOTECA DE PROMPTS' -ForegroundColor Cyan;Write-Host ' [1] Listar por categoria';Write-Host ' [2] Crear';Write-Host ' [3] Editar';Write-Host ' [4] Buscar';Write-Host ' [5] Copiar al portapapeles';Write-Host ' [6] Eliminar';Write-Host ' [0] Volver'
        $option=Read-Host 'Opcion';$files=Get-DevKeyPromptFiles
        switch($option){
            '1'{if($files){foreach($file in $files){Write-Host (' - '+(Get-DevKeyPromptDisplayName $file))}}else{Write-Host 'Biblioteca vacia.'};Pause-DevKey}
            '2'{try{$category=Read-DevKeyPromptCategory;if(-not $category){continue};$name=Read-Host 'Nombre';$path=Get-DevKeyPromptPath -Name $name -Category $category;if(Test-Path -LiteralPath $path){Write-Host 'Ya existe; usa Editar.';Pause-DevKey;continue};$text=Read-DevKeyPromptText;Set-Content -LiteralPath $path -Value $text -Encoding UTF8 -ErrorAction Stop}catch{Write-Host $_.Exception.Message -ForegroundColor Red};Pause-DevKey}
            '3'{if(-not $files){Write-Host 'Biblioteca vacia.';Pause-DevKey;continue};for($i=0;$i -lt $files.Count;$i++){Write-Host (" [{0}] {1}" -f ($i+1),(Get-DevKeyPromptDisplayName $files[$i]))};$n=0;if([int]::TryParse((Read-Host 'Prompt a editar'),[ref]$n) -and $n -ge 1 -and $n -le $files.Count){$path=$files[$n-1].FullName;$null=Backup-DevKeyPromptFile $path;$text=Read-DevKeyPromptText;Set-Content -LiteralPath $path -Value $text -Encoding UTF8 -ErrorAction Stop};Pause-DevKey}
            '4'{$query=Read-Host 'Texto a buscar';if($query){$files|Select-String -SimpleMatch -Pattern $query|ForEach-Object{Write-Host ("{0}: {1}" -f (Get-DevKeyPromptDisplayName (Get-Item -LiteralPath $_.Path)),$_.Line)}};Pause-DevKey}
            '5'{if(-not $files){Write-Host 'Biblioteca vacia.';Pause-DevKey;continue};for($i=0;$i -lt $files.Count;$i++){Write-Host (" [{0}] {1}" -f ($i+1),(Get-DevKeyPromptDisplayName $files[$i]))};$n=0;if([int]::TryParse((Read-Host 'Prompt a copiar'),[ref]$n) -and $n -ge 1 -and $n -le $files.Count){Get-Content -LiteralPath $files[$n-1].FullName -Raw|Set-Clipboard;Write-Host 'Copiado al portapapeles.'};Pause-DevKey}
            '6'{if(-not $files){Write-Host 'Biblioteca vacia.';Pause-DevKey;continue};for($i=0;$i -lt $files.Count;$i++){Write-Host (" [{0}] {1}" -f ($i+1),(Get-DevKeyPromptDisplayName $files[$i]))};$n=0;if([int]::TryParse((Read-Host 'Prompt a eliminar'),[ref]$n) -and $n -ge 1 -and $n -le $files.Count){$file=$files[$n-1];if((Read-Host 'Escribe ELIMINAR para continuar') -ceq 'ELIMINAR'){$backup=Backup-DevKeyPromptFile $file.FullName;Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop;Write-Host "Eliminado; backup: $backup"}};Pause-DevKey}
            '0'{return}
            default{Write-Host 'Opcion no valida.';Start-Sleep -Seconds 1}
        }
    }
}
