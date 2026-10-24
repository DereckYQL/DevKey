$script:ProfilesFile = Join-Path $ConfigRoot "profiles.json"
$script:ActiveProfileFile = Join-Path $ConfigRoot "active-profile.txt"

function Get-DevKeyProfiles {

    if (-not (Test-Path -LiteralPath $script:ProfilesFile -PathType Leaf)) {
        return @()
    }

    try {
        $Data = Get-Content -LiteralPath $script:ProfilesFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

        if ($Data.profiles) {
            foreach($profile in $Data.profiles){if($profile.env){foreach($property in $profile.env.PSObject.Properties){if($property.Name -match '(?i)(token|password|secret|credential|private.?key|api.?key)'){throw 'Sensitive environment name in profile data.'}}}}
            return @($Data.profiles)
        }

        return @($Data)
    }
    catch {
        Write-DevKeyLog -Level ERROR -Message 'profiles.json is invalid and was preserved.'
        throw 'profiles.json no se pudo validar; no se modifico.'
    }
}

function Save-DevKeyProfiles {

    param([object[]]$Profiles)

    foreach($profile in $Profiles){
        if($profile.env){foreach($property in $profile.env.PSObject.Properties){if($property.Name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or $property.Name -match '(?i)(token|password|secret|credential|private.?key|api.?key)'){throw 'El nombre de una variable no es valido o parece contener un secreto.'}}}
    }
    $Payload = [PSCustomObject]@{
        profiles = @($Profiles)
    }
    if(Test-Path -LiteralPath $script:ProfilesFile -PathType Leaf){$backup=Join-Path $BackupsRoot ('profiles-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'.json');Copy-Item -LiteralPath $script:ProfilesFile -Destination $backup -ErrorAction Stop}
    $temp=$script:ProfilesFile+'.tmp'
    try{$Payload|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $temp -Encoding UTF8 -ErrorAction Stop;Move-Item -LiteralPath $temp -Destination $script:ProfilesFile -Force -ErrorAction Stop}catch{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue;throw 'No se pudieron guardar los perfiles; se conserva el archivo previo.'}
}

function Get-DevKeyActiveProfile {

    if (-not (Test-Path -LiteralPath $script:ActiveProfileFile -PathType Leaf)) {
        return $null
    }

    $Name = (Get-Content -LiteralPath $script:ActiveProfileFile -Raw).Trim()

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $null
    }

    $Profile = Get-DevKeyProfiles | Where-Object { $_.name -eq $Name } | Select-Object -First 1

    if (-not $Profile) {
        return [PSCustomObject]@{
            name        = $Name
            description = "Perfil activo sin definicion"
            env         = @{}
        }
    }

    $EnvVars = @{}

    if ($Profile.env) {
        $Profile.env.PSObject.Properties | ForEach-Object {
            $EnvVars[$_.Name] = [string]$_.Value
        }
    }

    return [PSCustomObject]@{
        name        = [string]$Profile.name
        description = [string]$Profile.description
        env         = $EnvVars
    }
}

function Set-DevKeyActiveProfile {

    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return
    }

    $Profile = Get-DevKeyProfiles | Where-Object { $_.name -eq $Name } | Select-Object -First 1

    if (-not $Profile) {
        Write-Host ""
        Write-Host "[ERROR] Perfil no encontrado: $Name" -ForegroundColor Red
        Write-Host ""
        Pause
        return
    }

    if(Test-Path -LiteralPath $script:ActiveProfileFile -PathType Leaf){Copy-Item -LiteralPath $script:ActiveProfileFile -Destination (Join-Path $BackupsRoot ('active-profile-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'.txt')) -ErrorAction Stop}
    Set-Content -LiteralPath $script:ActiveProfileFile -Value $Name -Encoding UTF8 -ErrorAction Stop

    $EnvVars = @{}

    if ($Profile.env) {
        $Profile.env.PSObject.Properties | ForEach-Object {
            $EnvVars[$_.Name] = [string]$_.Value
        }
    }

    foreach ($Key in $EnvVars.Keys) {
        [Environment]::SetEnvironmentVariable($Key, $EnvVars[$Key], "Process")
    }

    $env:DEVKEY_PROFILE = $Name

    Write-Host ""
    Write-Host "[OK] Perfil activo: $Name" -ForegroundColor Green
    Write-Host ""
    Pause
}

function New-DevKeyProfile {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "          NUEVO PERFIL" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    $Name = Read-Host "Nombre del perfil"

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return
    }

    $Profiles = @(Get-DevKeyProfiles)

    if ($Profiles | Where-Object { $_.name -eq $Name }) {
        Write-Host ""
        Write-Host "[ERROR] El perfil ya existe." -ForegroundColor Red
        Write-Host ""
        Pause
        return
    }

    $Description = Read-Host "Descripcion"

    $Profile = [PSCustomObject]@{
        name        = $Name
        description = $Description
        env         = [PSCustomObject]@{}
    }

    $environment=[ordered]@{}
    Write-Host 'Variables de entorno opcionales. ENTER en nombre termina. No guardes credenciales aqui.' -ForegroundColor Yellow
    while($true){$key=Read-Host 'Nombre de variable';if([string]::IsNullOrWhiteSpace($key)){break};if($key -notmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or $key -match '(?i)(token|password|secret|credential|private.?key|api.?key)'){Write-Host 'Nombre no valido o reservado para un secreto.' -ForegroundColor Yellow;continue};$environment[$key]=Read-Host ("Valor de {0}" -f $key)}
    $Profile.env=[PSCustomObject]$environment

    $Profiles += $Profile
    Save-DevKeyProfiles -Profiles $Profiles

    Write-Host ""
    Write-Host "[OK] Perfil creado." -ForegroundColor Green
    Write-Host ""
    Pause
}

function Remove-DevKeyProfile {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "         ELIMINAR PERFIL" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    $Profiles = @(Get-DevKeyProfiles)

    if ($Profiles.Count -eq 0) {
        Write-Host "[--] No hay perfiles." -ForegroundColor Yellow
        Pause
        return
    }

    for ($Index = 0; $Index -lt $Profiles.Count; $Index++) {
        Write-Host (" [{0}] {1}" -f ($Index + 1), $Profiles[$Index].name)
    }

    Write-Host ""
    $Option = Read-Host "Perfil a eliminar"

    $Number = 0
    if (-not [int]::TryParse($Option, [ref]$Number)) {
        return
    }

    if ($Number -lt 1 -or $Number -gt $Profiles.Count) {
        return
    }

    $Target = $Profiles[$Number - 1]

    $Confirm = Read-Host "Eliminar '$($Target.name)'? (S/N)"

    if ($Confirm -ne "S" -and $Confirm -ne "s") {
        return
    }

    $Remaining = @($Profiles | Where-Object { $_.name -ne $Target.name })
    Save-DevKeyProfiles -Profiles $Remaining

    $Active = Get-DevKeyActiveProfile

    if ($Active -and $Active.name -eq $Target.name) {
        if(Test-Path -LiteralPath $script:ActiveProfileFile -PathType Leaf){Copy-Item -LiteralPath $script:ActiveProfileFile -Destination (Join-Path $BackupsRoot ('active-profile-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'.txt')) -ErrorAction Stop}
        Remove-Item -LiteralPath $script:ActiveProfileFile -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "[OK] Perfil eliminado." -ForegroundColor Green
    Write-Host ""
    Pause
}

function Show-DevKeyProfilesMenu {

    while ($true) {

        Clear-Host

        Write-Host ""
        Write-Host "======================================" -ForegroundColor DarkGray
        Write-Host "       PERFILES DE PROYECTOS" -ForegroundColor Cyan
        Write-Host "======================================" -ForegroundColor DarkGray
        Write-Host ""

        $Active = Get-DevKeyActiveProfile

        if ($Active) {
            Write-Host (" Activo: {0}" -f $Active.name) -ForegroundColor Green
        }
        else {
            Write-Host " Activo: ninguno" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host " [1] Ver perfiles" -ForegroundColor White
        Write-Host " [2] Crear perfil" -ForegroundColor White
        Write-Host " [3] Activar perfil" -ForegroundColor White
        Write-Host " [4] Eliminar perfil" -ForegroundColor White
        Write-Host " [0] Volver" -ForegroundColor DarkGray
        Write-Host ""

        $Option = Read-Host "Selecciona una opcion"

        switch ($Option) {

            "1" {

                Clear-Host
                Write-Host ""
                Write-Host "======================================" -ForegroundColor DarkGray
                Write-Host "            PERFILES" -ForegroundColor Cyan
                Write-Host "======================================" -ForegroundColor DarkGray
                Write-Host ""

                $Profiles = @(Get-DevKeyProfiles)

                if ($Profiles.Count -eq 0) {
                    Write-Host "[--] No hay perfiles." -ForegroundColor Yellow
                }
                else {
                    foreach ($Profile in $Profiles) {
                        Write-Host (" - {0} : {1}" -f $Profile.name, $Profile.description)
                    }
                }

                Write-Host ""
                Pause
            }

            "2" { New-DevKeyProfile }

            "3" {

                $Profiles = @(Get-DevKeyProfiles)

                if ($Profiles.Count -eq 0) {
                    Write-Host ""
                    Write-Host "[--] No hay perfiles." -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                    continue
                }

                Clear-Host
                Write-Host ""

                for ($Index = 0; $Index -lt $Profiles.Count; $Index++) {
                    Write-Host (" [{0}] {1}" -f ($Index + 1), $Profiles[$Index].name)
                }

                Write-Host ""
                $Selection = Read-Host "Perfil a activar"

                $Number = 0
                if ([int]::TryParse($Selection, [ref]$Number)) {
                    if ($Number -ge 1 -and $Number -le $Profiles.Count) {
                        Set-DevKeyActiveProfile -Name $Profiles[$Number - 1].name
                    }
                }
            }

            "4" { Remove-DevKeyProfile }
            "0" { return }

            default {
                Write-Host ""
                Write-Host "Opcion no valida." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
    }
}
