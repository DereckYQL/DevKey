$script:DevKeyDefaultConfig = [ordered]@{
    Version='2.0.0'
    Security=[ordered]@{ MaxAttempts=3; ProgressiveLockout=$true; PBKDF2Iterations=310000; MinimumPasswordLength=8; TokenSha256='E0C4016F3BC6EA37D39A43B73E8EF171FF2A93DE70D5A7621F840A17AE5C2093' }
    Guardian=[ordered]@{ Enabled=$true; AutoLaunch=$false; AutoClose=$true; CheckIntervalSeconds=2; LogEvents=$true; VolumeSerial=''; ForceCloseOnRemoval=$false; ForceCloseAfterSeconds=8 }
    Applications=[ordered]@{
        Kiro=[ordered]@{ Enabled=$true; AutoClose=$true; Path='Apps\Kiro\Kiro.exe' }
        OpenCode=[ordered]@{ Enabled=$true; AutoClose=$true; Path='Apps\OpenCode\opencode.exe' }
        Git=[ordered]@{ Enabled=$true; Path='Apps\Git\cmd\git.exe' }
        Node=[ordered]@{ Enabled=$true; Path='Apps\Node\node.exe' }
        Docker=[ordered]@{ Enabled=$true; Path='Apps\Docker\Docker Desktop.exe' }
    }
    Logging=[ordered]@{ Enabled=$true; MaxFileSizeMB=5; RetentionDays=30 }
    Interface=[ordered]@{ Theme='Classic' }
}

function Import-DevKeyConfiguration {
    if (-not (Test-Path -LiteralPath $script:ConfigFile -PathType Leaf)) {
        $script:DevKeyDefaultConfig | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $script:ConfigFile -Encoding UTF8
    }
    try { $parsed=Get-Content -LiteralPath $script:ConfigFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
    catch { throw 'Config\config.json no contiene JSON valido. El original se conserva; corrige o restaura una copia.' }
    foreach ($section in @('Security','Guardian','Applications','Logging','Interface')) {
        if ($null -eq $parsed.PSObject.Properties[$section]) { throw "Falta la seccion requerida '$section' en config.json. El original se conserva." }
    }
    foreach ($section in @('Security','Guardian','Applications','Logging','Interface')) {
        foreach($property in $script:DevKeyDefaultConfig[$section].Keys){
            if($null -eq $parsed.$section.PSObject.Properties[[string]$property]){$parsed.$section|Add-Member -NotePropertyName ([string]$property) -NotePropertyValue $script:DevKeyDefaultConfig[$section][$property]}
        }
    }
    foreach ($key in @('Kiro','OpenCode','Git','Node','Docker')) {
        if ($null -eq $parsed.Applications.PSObject.Properties[$key]) { $parsed.Applications|Add-Member -NotePropertyName $key -NotePropertyValue ([pscustomobject]$script:DevKeyDefaultConfig.Applications[$key]) }
        else { foreach($property in $script:DevKeyDefaultConfig.Applications[$key].Keys){if($null -eq $parsed.Applications.$key.PSObject.Properties[[string]$property]){$parsed.Applications.$key|Add-Member -NotePropertyName ([string]$property) -NotePropertyValue $script:DevKeyDefaultConfig.Applications[$key][$property]}} }
    }
    if ([int]$parsed.Security.MaxAttempts -lt 1 -or [int]$parsed.Security.PBKDF2Iterations -lt 100000 -or [int]$parsed.Security.PBKDF2Iterations -gt 2000000 -or [int]$parsed.Security.MinimumPasswordLength -lt 8) { throw 'Los parametros de autenticacion de config.json estan fuera de rango.' }
    if ([int]$parsed.Guardian.CheckIntervalSeconds -lt 1 -or [int]$parsed.Guardian.CheckIntervalSeconds -gt 60 -or [int]$parsed.Logging.MaxFileSizeMB -lt 1 -or [int]$parsed.Logging.RetentionDays -lt 1) { throw 'Los parametros de monitorizacion o logs de config.json estan fuera de rango.' }
    if ($parsed.Security.TokenSha256 -notmatch '^[A-Fa-f0-9]{64}$') { throw 'Security.TokenSha256 debe ser un SHA-256 hexadecimal de 64 caracteres.' }
    if ($parsed.Interface.Theme -notin @('Classic','Dark','Matrix','Minimal')) { throw 'Interface.Theme no es uno de los temas admitidos.' }
    $script:DevKeyConfig=$parsed
}

function Save-DevKeyConfiguration {
    $stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup=Join-Path $script:BackupsRoot ("config-$stamp.json")
    if (Test-Path -LiteralPath $script:ConfigFile -PathType Leaf) { Copy-Item -LiteralPath $script:ConfigFile -Destination $backup -ErrorAction Stop }
    $temp=$script:ConfigFile+'.tmp'
    try {
        $script:DevKeyConfig | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $temp -Encoding UTF8 -ErrorAction Stop
        Move-Item -LiteralPath $temp -Destination $script:ConfigFile -Force -ErrorAction Stop
    } catch {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        throw 'No se pudo guardar config.json; revisa el backup y el espacio disponible.'
    }
}
function Get-DevKeyVersion {
    try { $v=Get-Content -LiteralPath $script:VersionFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop; return [string]$v.version } catch { return [string]$script:DevKeyConfig.Version }
}
