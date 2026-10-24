param(
    [Parameter(Mandatory=$true)][string]$FixtureRoot,
    [ValidateSet('Navigation','BadToken','BadPassword','InvalidIntegrity')][string]$Scenario='Navigation'
)
$ErrorActionPreference='Stop'
# This helper may only operate inside a sandbox made by the smoke suite.
$fixturePath=[IO.Path]::GetFullPath($FixtureRoot)
$tempPath=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
if(-not $fixturePath.StartsWith($tempPath,[StringComparison]::OrdinalIgnoreCase) -or
   -not (Test-Path -LiteralPath (Join-Path $fixturePath '.devkey-smoke-fixture') -PathType Leaf)){
    throw 'A marked temporary smoke fixture is required.'
}
$launcher=Join-Path $fixturePath 'Launcher/DevKey.ps1'
$resultPath=Join-Path $fixturePath 'fixture-result.json'
# Launcher functions run in a child script scope. Keep the scripted console state
# in this worker process's global scope so Read-Host cannot bind launcher locals.
$global:DevKeyLauncherFixtureState=[pscustomobject]@{
    Steps=(New-Object 'System.Collections.Generic.Queue[object]')
    Completed=(New-Object 'System.Collections.Generic.List[string]')
    Failures=(New-Object 'System.Collections.Generic.List[string]')
    ProcessAttempts=0
    PromptCount=0
}
function Add-Step {
    param([string]$Id,[string]$Caller,[string]$Prompt,[string]$Value,[bool]$Secure=$false)
    $global:DevKeyLauncherFixtureState.Steps.Enqueue([pscustomobject]@{Id=$Id;Caller=$Caller;Prompt=$Prompt;Value=$Value;Secure=$Secure})
}
function Read-Host {
    param([string]$Prompt,[switch]$AsSecureString)
    $global:DevKeyLauncherFixtureState.PromptCount++
    if($global:DevKeyLauncherFixtureState.PromptCount -gt 100 -or -not $global:DevKeyLauncherFixtureState.Steps.Count){
        $global:DevKeyLauncherFixtureState.Failures.Add('Unexpected/excess prompt: '+$Prompt)
        throw 'The fixture prompt budget was exhausted.'
    }
    $step=$global:DevKeyLauncherFixtureState.Steps.Peek()
    $caller=(Get-PSCallStack)[1].FunctionName
    if($Prompt -cne $step.Prompt -or [bool]$AsSecureString -ne $step.Secure -or $caller -cne $step.Caller){
        # Report prompt names only, never queued responses or fixture passwords.
        $global:DevKeyLauncherFixtureState.Failures.Add(('Prompt mismatch at {0}: {1} ({2})' -f $step.Id,$Prompt,$caller))
        throw 'Unexpected fixture navigation.'
    }
    [void]$global:DevKeyLauncherFixtureState.Steps.Dequeue()
    $global:DevKeyLauncherFixtureState.Completed.Add($step.Id)
    if($AsSecureString){return (ConvertTo-SecureString -String $step.Value -AsPlainText -Force)}
    return $step.Value
}
function Clear-Host {}
function Start-Process {
    $global:DevKeyLauncherFixtureState.ProcessAttempts++
    throw 'Launching applications or services is forbidden in this fixture.'
}

if($Scenario -eq 'BadToken' -or $Scenario -eq 'BadPassword'){
    if($Scenario -eq 'BadPassword'){
        Add-Step 'wrong-password' 'Test-DevKeyAuthentication' 'DevKey password' 'Wrong-fixture-password-24' $true
    }
    Add-Step 'denied-exit' '<ScriptBlock>' 'Acceso no concedido. Pulsa ENTER para salir' ''
} else {
    Add-Step 'setup-password' 'Initialize-DevKeyAuthentication' 'New password (minimum 8 characters)' 'Fixture-password-24' $true
    Add-Step 'confirm-password' 'Initialize-DevKeyAuthentication' 'Confirm password' 'Fixture-password-24' $true
    if($Scenario -eq 'InvalidIntegrity'){
        Add-Step 'main-1' '<ScriptBlock>' 'Selecciona una opción' '1'
        Add-Step 'blocked-kiro' 'Show-SoftwareMenu' 'Selecciona un software' '1'
        Add-Step 'integrity-denied-pause' 'Pause-DevKey' 'Pulsa ENTER para continuar' ''
        Add-Step 'software-pause' 'Pause-DevKey' 'Pulsa ENTER para continuar' ''
        Add-Step 'software-return' 'Show-SoftwareMenu' 'Selecciona un software' '0'
        Add-Step 'main-exit' '<ScriptBlock>' 'Selecciona una opción' '0'
    } else {
        Add-Step 'main-invalid' '<ScriptBlock>' 'Selecciona una opción' 'x'
        Add-Step 'main-1' '<ScriptBlock>' 'Selecciona una opción' '1'
        Add-Step 'software-invalid' 'Show-SoftwareMenu' 'Selecciona un software' 'x'
        foreach($key in @('1','2','3','4')){
            Add-Step ('software-'+$key) 'Show-SoftwareMenu' 'Selecciona un software' $key
            Add-Step ('software-pause-'+$key) 'Pause-DevKey' 'Pulsa ENTER para continuar' ''
        }
        Add-Step 'software-return' 'Show-SoftwareMenu' 'Selecciona un software' '0'
        Add-Step 'main-2' '<ScriptBlock>' 'Selecciona una opción' '2'
        Add-Step 'github-return' 'Show-DevKeyGit' 'Opcion' '0'
        Add-Step 'main-3' '<ScriptBlock>' 'Selecciona una opción' '3'
        Add-Step 'projects-return' 'Show-DevKeyProjects' 'Opcion' '0'
        Add-Step 'main-4' '<ScriptBlock>' 'Selecciona una opción' '4'
        Add-Step 'status-return' 'Pause-DevKey' 'Pulsa ENTER para continuar' ''
        Add-Step 'main-5' '<ScriptBlock>' 'Selecciona una opción' '5'
        Add-Step 'maintenance-return' 'Show-DevKeyMaintenance' 'Opcion' '0'
        Add-Step 'main-6' '<ScriptBlock>' 'Selecciona una opción' '6'
        Add-Step 'security-invalid' 'Show-DevKeySecurityMenu' 'Opcion' 'x'
        Add-Step 'security-status' 'Show-DevKeySecurityMenu' 'Opcion' '1'
        Add-Step 'security-pause' 'Pause-DevKey' 'Pulsa ENTER para continuar' ''
        Add-Step 'security-return' 'Show-DevKeySecurityMenu' 'Opcion' '0'
        Add-Step 'main-7' '<ScriptBlock>' 'Selecciona una opción' '7'
        Add-Step 'info-return' 'Pause-DevKey' 'Pulsa ENTER para continuar' ''
        Add-Step 'main-exit' '<ScriptBlock>' 'Selecciona una opción' '0'
    }
}
$expected=@($global:DevKeyLauncherFixtureState.Steps | ForEach-Object {$_.Id})
$originalForeground=$null;$originalBackground=$null
try {
    try {$originalForeground=$Host.UI.RawUI.ForegroundColor;$originalBackground=$Host.UI.RawUI.BackgroundColor} catch { }
    & $launcher
} catch {
    $global:DevKeyLauncherFixtureState.Failures.Add('Launcher exception: '+$_.Exception.GetType().Name+' at '+$_.ScriptStackTrace)
} finally {
    try {
        if($null -ne $originalForeground){$Host.UI.RawUI.ForegroundColor=$originalForeground}
        if($null -ne $originalBackground){$Host.UI.RawUI.BackgroundColor=$originalBackground}
    } catch { }
    if($global:DevKeyLauncherFixtureState.Steps.Count){$global:DevKeyLauncherFixtureState.Failures.Add(('Unconsumed fixture steps: {0}' -f $global:DevKeyLauncherFixtureState.Steps.Count))}
    $errorPath=Join-Path $fixturePath 'Logs/error.log'
    $errorLog=if(Test-Path -LiteralPath $errorPath){Get-Content -LiteralPath $errorPath -Raw}else{''}
    if($errorLog -match '\[ERROR\]'){$global:DevKeyLauncherFixtureState.Failures.Add('The launcher logged an ERROR.')}
    if($global:DevKeyLauncherFixtureState.ProcessAttempts){$global:DevKeyLauncherFixtureState.Failures.Add('An application launch was attempted.')}
    [ordered]@{
        Scenario=$Scenario;Expected=$expected;Completed=@($global:DevKeyLauncherFixtureState.Completed)
        Failures=@($global:DevKeyLauncherFixtureState.Failures);ProcessAttempts=$global:DevKeyLauncherFixtureState.ProcessAttempts
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding UTF8
}
if($global:DevKeyLauncherFixtureState.Failures.Count){exit 1}
