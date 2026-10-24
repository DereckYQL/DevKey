function Get-DevKeyCriticalFiles {
    $roots=@((Join-Path $script:DevKeyRoot 'Launcher'),(Join-Path $script:DevKeyRoot 'Core'),(Join-Path $script:DevKeyRoot 'Security'),(Join-Path $script:DevKeyRoot 'Guardian'),(Join-Path $script:DevKeyRoot 'Modules'))
    foreach($root in $roots){if(Test-Path -LiteralPath $root -PathType Container){Get-ChildItem -LiteralPath $root -Filter '*.ps1' -File -Recurse -ErrorAction SilentlyContinue}}
}
function Get-DevKeyIntegrityStatus {
    if(-not(Test-Path -LiteralPath $script:ManifestFile -PathType Leaf)){return [pscustomobject]@{Status='UNCONFIGURED';Changed=@();Missing=@();Trust='NONE'}}
    try{$manifest=Get-Content -LiteralPath $script:ManifestFile -Raw -ErrorAction Stop|ConvertFrom-Json -ErrorAction Stop}catch{return [pscustomobject]@{Status='INVALID';Changed=@();Missing=@();Trust='NONE'}}
    if([int]$manifest.Version -ne 1 -or [string]$manifest.Trust -ne 'UNSIGNED-LOCAL' -or -not $manifest.Files){return [pscustomobject]@{Status='INVALID';Changed=@();Missing=@();Trust='NONE'}}
    $changed=New-Object System.Collections.Generic.List[string];$missing=New-Object System.Collections.Generic.List[string]
    try{
        foreach($entry in $manifest.Files){
            $relative=[string]$entry.Path
            if([string]::IsNullOrWhiteSpace($relative) -or [IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[/\\])\.\.([/\\]|$)' -or [string]$entry.SHA256 -notmatch '^[A-Fa-f0-9]{64}$'){return [pscustomobject]@{Status='INVALID';Changed=@();Missing=@();Trust='NONE'}}
            $path=[IO.Path]::GetFullPath((Join-Path $script:DevKeyRoot $relative))
            $base=[IO.Path]::GetFullPath($script:DevKeyRoot).TrimEnd('\')+'\'
            if(-not $path.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)){return [pscustomobject]@{Status='INVALID';Changed=@();Missing=@();Trust='NONE'}}
            if(-not(Test-Path -LiteralPath $path -PathType Leaf)){$missing.Add($relative);continue}
            $resolved=(Resolve-Path -LiteralPath $path -ErrorAction Stop).ProviderPath
            if(-not $resolved.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)){$changed.Add($relative);continue}
            $actual=(Get-FileHash -LiteralPath $resolved -Algorithm SHA256 -ErrorAction Stop).Hash
            if($actual -cne [string]$entry.SHA256){$changed.Add($relative)}
        }
    }catch{return [pscustomobject]@{Status='INVALID';Changed=@($changed);Missing=@($missing);Trust='NONE'}}
    $status=if($changed.Count -or $missing.Count){'MISMATCH'}else{'UNSIGNED-LOCAL'}
    return [pscustomobject]@{Status=$status;Changed=@($changed);Missing=@($missing);Trust='UNSIGNED-LOCAL'}
}
function New-DevKeyLocalManifest {
    Write-Host 'El manifiesto local detecta cambios accidentales, pero no autentica DevKey ni su origen.' -ForegroundColor Yellow
    if((Read-Host 'Crear/reemplazar manifiesto despues de revisar los archivos? (S/N)') -notin @('S','s')){return}
    if(Test-Path -LiteralPath $script:ManifestFile -PathType Leaf){$backup=Join-Path $script:BackupsRoot ('integrity-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'.json');Copy-Item -LiteralPath $script:ManifestFile -Destination $backup -ErrorAction Stop}
    $files=@(Get-DevKeyCriticalFiles|ForEach-Object{[pscustomobject]@{Path=$_.FullName.Substring($script:DevKeyRoot.Length).TrimStart('\');SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()}})
    if(-not $files){throw 'No se encontraron archivos criticos para el manifiesto.'}
    $temp=$script:ManifestFile+'.tmp';$record=[ordered]@{Version=1;CreatedUtc=[datetime]::UtcNow.ToString('o');Trust='UNSIGNED-LOCAL';Files=$files}
    try{$record|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $temp -Encoding UTF8 -ErrorAction Stop;Move-Item -LiteralPath $temp -Destination $script:ManifestFile -Force -ErrorAction Stop}
    catch{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue;throw 'No se pudo guardar el manifiesto; el anterior se conserva.'}
    Write-DevKeyLog -Log maintenance.log -Level AUDIT -Message 'Unsigned local integrity manifest created.'
    Write-Host 'Manifiesto local creado; no esta firmado.' -ForegroundColor Yellow
}
function Show-DevKeyIntegrity {
    $status=Get-DevKeyIntegrityStatus
    $color=if($status.Status -eq 'MISMATCH' -or $status.Status -eq 'INVALID'){'Red'}elseif($status.Status -eq 'UNSIGNED-LOCAL'){'Yellow'}else{'DarkYellow'}
    Write-Host "Integridad: $($status.Status)" -ForegroundColor $color
    if($status.Changed.Count){Write-Host ('Modificados o fuera de raiz: '+($status.Changed -join ', ')) -ForegroundColor Red}
    if($status.Missing.Count){Write-Host ('Faltantes: '+($status.Missing -join ', ')) -ForegroundColor Red}
    if($status.Status -eq 'UNCONFIGURED'){Write-Host 'No existe manifiesto; no se afirma que el codigo este validado.' -ForegroundColor Yellow}
    if($status.Trust -eq 'UNSIGNED-LOCAL'){Write-Host 'Confianza: manifiesto local sin firma; no protege contra una modificacion coordinada.' -ForegroundColor Yellow}
}
