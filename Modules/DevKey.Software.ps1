# Trusted, in-code registry. Never evaluate commands read from external configuration.
function Get-DevKeySoftwareRegistry {
    @(
        [pscustomobject]@{Key='1';Name='Kiro';Description='Editor; USB o instalación del equipo';Available={ [bool](Get-DevKeyApplicationPath -Name Kiro) };Launch={ [void](Start-DevKeyApplication -Name Kiro) }},
        [pscustomobject]@{Key='2';Name='OpenCode';Description='Agente de terminal; USB o equipo';Available={ [bool](Get-DevKeyApplicationPath -Name OpenCode) };Launch={ [void](Start-DevKeyApplication -Name OpenCode) }},
        [pscustomobject]@{Key='3';Name='TryOmarchy';Description='Integración pendiente';Available={ $false };Launch={ Write-Host 'TryOmarchy no está configurado en DevKey.' -ForegroundColor Yellow }},
        [pscustomobject]@{Key='4';Name='Docker';Description='CLI y motor externo del equipo';Available={ [bool](Get-DevKeyDockerCli) };Launch={ [void](Invoke-DevKeyDocker) }}
    )
}

function Get-DevKeyDockerCli {
    if(-not $script:DevKeyConfig.Applications.Docker.Enabled){return $null}
    $configured=Get-DevKeyApplicationPath -Name Docker
    if($configured -and [IO.Path]::GetFileName($configured) -in @('docker.exe','docker')){return $configured}
    if($configured -and [IO.Path]::GetFileName($configured) -ieq 'Docker Desktop.exe'){
        $sibling=Join-Path (Split-Path -Parent $configured) 'resources\bin\docker.exe'
        if(Test-Path -LiteralPath $sibling -PathType Leaf){return $sibling}
    }
    $command=Get-Command 'docker.exe','docker' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if($command){return $command.Source}
    return $null
}

function Test-DevKeyDockerEngine {
    param([Parameter(Mandatory=$true)][string]$Path,[int]$TimeoutMilliseconds=5000)
    # Bound the probe and drain both streams asynchronously to avoid deadlocks.
    $process=New-Object System.Diagnostics.Process
    $process.StartInfo.FileName=$Path
    $process.StartInfo.Arguments='info'
    $process.StartInfo.UseShellExecute=$false
    $process.StartInfo.CreateNoWindow=$true
    $process.StartInfo.RedirectStandardOutput=$true
    $process.StartInfo.RedirectStandardError=$true
    try {
        [void]$process.Start()
        $stdout=$process.StandardOutput.ReadToEndAsync()
        $stderr=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit($TimeoutMilliseconds)){
            $process.Kill()
            return $false
        }
        return ($process.ExitCode -eq 0)
    } catch {return $false} finally {$process.Dispose()}
}

function Invoke-DevKeyDocker {
    $cli=Get-DevKeyDockerCli
    if(-not $cli){
        Write-Host 'Docker no está disponible: habilita una CLI existente en la configuración o en PATH. Docker Desktop puede requerir instalación en el equipo.' -ForegroundColor Yellow
        return $false
    }
    if(-not(Confirm-DevKeyOperationalIntegrity)){return $false}
    if(-not(Test-DevKeyDockerEngine -Path $cli)){
        Write-Host 'La CLI de Docker está disponible, pero el motor no responde. Comprueba tu runtime y contexto de Docker e inténtalo de nuevo.' -ForegroundColor Yellow
        return $false
    }
    Write-Host 'Docker: CLI y motor disponibles.' -ForegroundColor Green
    Write-Host ('  CLI del equipo o USB: {0}' -f $cli) -ForegroundColor Cyan
    return $true
}

function Show-SoftwareMenu {
    $software=@(Get-DevKeySoftwareRegistry)
    while($true){
        Clear-Host
        $rows=@($software | ForEach-Object {'[{0}] {1}' -f $_.Key,$_.Name})
        Write-DevKeyPanel -Title 'DEVKEY SOFTWARE MANAGER' -Rows ($rows+@('','[0] Volver al menú principal'))
        $choice=Read-Host 'Selecciona un software'
        if($choice -eq '0'){return}
        $selected=$software | Where-Object {$_.Key -eq $choice} | Select-Object -First 1
        if(-not $selected){Write-Host 'Opción no válida.' -ForegroundColor Yellow;Start-Sleep -Seconds 1;continue}
        try {
            Write-Host $selected.Description -ForegroundColor Cyan
            if(-not(& $selected.Available)){
                if($selected.Name -eq 'TryOmarchy'){Write-Host 'TryOmarchy no está configurado en DevKey.' -ForegroundColor Yellow}
                else{Write-Host ("{0} no está disponible. Revisa su configuración y las dependencias del equipo." -f $selected.Name) -ForegroundColor Yellow}
            } elseif($selected.Name -eq 'Docker'){
                & $selected.Launch
            } elseif(Confirm-DevKeyOperationalIntegrity){
                & $selected.Launch
            }
        } catch {
            Write-DevKeyLog -Level ERROR -Message ('Software '+$selected.Name+': '+$_.Exception.GetType().Name)
            Write-Host 'No se pudo completar la operación. Puedes elegir otro software.' -ForegroundColor Red
        }
        Pause-DevKey
    }
}
