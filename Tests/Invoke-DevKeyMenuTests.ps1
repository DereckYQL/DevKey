# Safe, dependency-free navigation tests. No real application or authentication is started.
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$script:passed=0
function Assert([bool]$Condition,[string]$Name){if(-not $Condition){throw "FAIL $Name"};$script:passed++;Write-Output "PASS $Name"}
function Clear-Host {}
function Write-Host {param([Parameter(ValueFromRemainingArguments=$true)]$Text,$ForegroundColor);$script:display+=($Text -join ' ')}
function Start-Sleep {}
function Pause-DevKey {}
function Write-DevKeyLog {}
function Read-Host {param($Prompt);if(-not $script:promptQueue.Count){throw "Unexpected prompt: $Prompt"};$script:promptQueue.Dequeue()}
function Set-Input([string[]]$Values){$script:promptQueue=New-Object 'System.Collections.Generic.Queue[string]';foreach($value in $Values){$script:promptQueue.Enqueue($value)}}
function Confirm-DevKeyOperationalIntegrity {return $script:allowIntegrity}
function Get-DevKeyApplicationPath {param($Name);if($script:available){return ('C:\USB\Apps\'+$Name+'.exe')};return $null}
function Start-DevKeyApplication {param($Name);$script:launched+=,$Name;if($script:launchFails){throw 'Mock failure'};return $true}
$script:DevKeyConfig=[pscustomobject]@{Applications=[pscustomobject]@{Docker=[pscustomobject]@{Enabled=$false}}}
. (Join-Path $root 'Modules/DevKey.Menu.ps1')
. (Join-Path $root 'Modules/DevKey.Software.ps1')
$script:display=@();Show-DevKeyMainMenu
$labels=@($script:display | Where-Object {$_ -match '\[\d\]'})
Assert ($labels.Count -eq 8) 'Main menu has exactly eight options'
$expected=@('Abrir software','GitHub','Projects','Estado del sistema','Mantenimiento','Seguridad / DevKey Vault','Información del sistema','Salir')
for($i=0;$i -lt 8;$i++){Assert ($labels[$i].Contains($expected[$i])) ('Main label/order '+$expected[$i])}
Assert (-not (($labels -join '') -match 'Kiro|OpenCode')) 'Individual launchers are absent from main menu'
$registry=@(Get-DevKeySoftwareRegistry)
Assert (($registry.Name -join ',') -eq 'Kiro,OpenCode,TryOmarchy,Docker') 'Software registry order'
foreach($entry in $registry){Assert ($entry.Available -is [scriptblock] -and $entry.Launch -is [scriptblock] -and $entry.Description) ('Registry hooks '+$entry.Name)}
$script:available=$true;$script:allowIntegrity=$true;$script:launchFails=$false;$script:launched=@()
Set-Input @('invalid','1','2','3','4','0');Show-SoftwareMenu
Assert (($script:launched -join ',') -eq 'Kiro,OpenCode') 'Existing launchers reused; unavailable tools never launched'
Assert ($script:promptQueue.Count -eq 0) 'Invalid input and return consume expected selections'
Assert (($script:display -join '') -match 'TryOmarchy no está configurado en DevKey\.') 'Unconfigured TryOmarchy explanation'
$script:available=$false;$script:launched=@();Set-Input @('1','2','0');Show-SoftwareMenu
Assert ($script:launched.Count -eq 0) 'Missing applications handled without launching'
$script:available=$true;$script:allowIntegrity=$false;Set-Input @('1','0');Show-SoftwareMenu
Assert ($script:launched.Count -eq 0) 'Failed integrity check blocks application launch'
$script:allowIntegrity=$true;$script:launchFails=$true;Set-Input @('1','2','0');Show-SoftwareMenu
Assert ($script:launched.Count -eq 2 -and $script:promptQueue.Count -eq 0) 'Launch exceptions return to software menu'
Assert ($null -eq (Get-DevKeyDockerCli)) 'Disabled Docker is not detected or started'

# Parse every script, then import only function definitions from the real launcher.
$syntaxFailures=@()
foreach($file in Get-ChildItem -LiteralPath $root -Filter '*.ps1' -Recurse){
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    if($errors){$syntaxFailures+=,$file.FullName}
}
Assert ($syntaxFailures.Count -eq 0) ('PowerShell syntax: '+($syntaxFailures -join ', '))
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'Launcher/DevKey.ps1'),[ref]$tokens,[ref]$errors)
foreach($fn in $ast.EndBlock.Statements | Where-Object {$_ -is [Management.Automation.Language.FunctionDefinitionAst]}){
    . ([scriptblock]::Create($fn.Extent.Text))
}
# Test the actual main-loop AST with mocks, excluding startup/configuration side effects.
$main=$ast.EndBlock.Statements | Where-Object {$_ -is [Management.Automation.Language.TryStatementAst] -and $_.Finally -and $_.Extent.Text.Contains('Show-DevKeyFrame')}
Assert (@($main).Count -eq 1) 'Only one main menu loop'
$script:routes=@();$script:frames=0;$script:cleanup=0;$script:authCalls=0
function Show-DevKeyFrame {$script:frames++}
function Test-DevKeyPhysicalToken {return $true}
function Show-SoftwareMenu {$script:routes+=,'software'}
function Show-DevKeyGit {$script:routes+=,'github'}
function Show-DevKeyProjects {$script:routes+=,'projects'}
function Show-DevKeyStatus {$script:routes+=,'status'}
function Show-DevKeyMaintenance {$script:routes+=,'maintenance'}
function Show-DevKeySecurityMenu {$script:routes+=,'security'}
function Show-DevKeySystemInfo {$script:routes+=,'info'}
function Stop-DevKeyGuardianWorker {$script:cleanup++}
function Stop-DevKeyManagedProcesses {$script:cleanup++}
function Test-DevKeyAuthentication {$script:authCalls++;return $true}
function Get-DevKeyIntegrityStatus {return [pscustomobject]@{Status='UNCONFIGURED'}}
function Test-Path {param($LiteralPath,$PathType);return $true}
$script:DevKeyPinnedTokenSha256='TEST-PIN'
$script:DevKeyConfig | Add-Member -NotePropertyName Security -NotePropertyValue ([pscustomobject]@{TokenSha256='TEST-PIN'})
$script:AuthFile='mock-auth';$script:ConfigRoot='mock-config';$script:DevKeyAuthenticated=$false
Assert (Invoke-DevKeyAuthenticationGate) 'Existing authentication gate succeeds via mocked verifier'
Set-Input @('x','1','2','3','4','5','6','7','0')
. ([scriptblock]::Create($main.Extent.Text))
Assert (($script:routes -join ',') -eq 'software,github,projects,status,maintenance,security,info') 'Main routes dispatch existing functions in requested order'
Assert ($script:frames -eq 9 -and $script:promptQueue.Count -eq 0) 'Submenus return to one main frame per selection'
Assert ($script:authCalls -eq 1) 'Authentication called once across submenu returns'
Assert ($script:cleanup -eq 2) 'Exit cleans up Guardian and managed processes'

# Load the active security implementation (not the legacy auto-running module).
$script:AppsRoot='mock-apps'
. (Join-Path $root 'Security/SecurityAudit.ps1')
Set-Input @('invalid','0');Show-DevKeySecurityMenu
Assert ($script:promptQueue.Count -eq 0) 'Security invalid input and a single zero return directly'
# Real portable resolver and unchanged launch function, with process creation mocked.
Remove-Item Function:\Test-Path
. (Join-Path $root 'Modules/Applications.ps1')
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('devkey-menu-'+[guid]::NewGuid().ToString('N'))
try {
    $script:UsbRoot=$fixture;$script:DataRoot=Join-Path $fixture 'Data';$script:KiroData=Join-Path $script:DataRoot 'KiroUser'
    New-Item -ItemType Directory -Path (Join-Path $fixture 'Apps') -Force | Out-Null
    $apps=[ordered]@{}
    foreach($name in @('Kiro','OpenCode','Docker')){
        $relative='Apps/'+$name+'.exe'
        $apps[$name]=[pscustomobject]@{Enabled=$true;Path=$relative}
        Set-Content -LiteralPath (Join-Path $fixture $relative) -Value 'test placeholder, never executed'
    }
    $script:DevKeyConfig.Applications=[pscustomobject]$apps
    foreach($name in @('Kiro','OpenCode')){
        Assert ((Get-DevKeyApplicationPath -Name $name) -eq (Join-Path $fixture ('Apps/'+$name+'.exe'))) ('Portable path '+$name)
    }
    function Get-Process {param($Name,$ErrorAction);return @()}
    function Start-DevKeyManagedProcess {
        param($FilePath,$ArgumentList,$WorkingDirectory,$Application)
        $script:processCall=[pscustomobject]@{Path=$FilePath;Arguments=$ArgumentList;Directory=$WorkingDirectory;Name=$Application;Xdg=$env:XDG_CONFIG_HOME}
    }
    Assert (Start-DevKeyApplication -Name Kiro) 'Kiro launcher succeeds with mock process'
    Assert (($script:processCall.Arguments -join '|') -eq ('--user-data-dir|'+$script:KiroData)) 'Kiro data arguments preserved'
    Assert ($script:processCall.Directory -eq (Join-Path $fixture 'Apps')) 'Existing working directory preserved'
    $originalXdg=$env:XDG_CONFIG_HOME
    Assert (Start-DevKeyApplication -Name OpenCode) 'OpenCode launcher succeeds with mock process'
    Assert ($script:processCall.Xdg -eq (Join-Path $script:DataRoot 'OpenCode\Config')) 'OpenCode portable configuration preserved'
    Assert ($env:XDG_CONFIG_HOME -eq $originalXdg) 'OpenCode restores process environment'
    Assert ((Get-DevKeyDockerCli) -eq (Join-Path $fixture 'Apps/Docker.exe')) 'Configured Docker CLI detected outside PATH'
    if([IO.Path]::DirectorySeparatorChar -eq '/'){
        Assert (Test-DevKeyDockerEngine -Path '/bin/true') 'Engine probe accepts zero exit code'
        Assert (-not(Test-DevKeyDockerEngine -Path '/bin/false')) 'Engine probe rejects nonzero exit code'
        Assert (-not(Test-DevKeyDockerEngine -Path (Join-Path $fixture 'missing-cli'))) 'Engine probe handles missing executable'
        $slow=Join-Path $fixture 'slow-cli'
        [IO.File]::WriteAllText($slow,"#!/bin/sh`nexec sleep 5`n")
        & chmod +x $slow
        $timer=[Diagnostics.Stopwatch]::StartNew()
        Assert (-not(Test-DevKeyDockerEngine -Path $slow -TimeoutMilliseconds 100)) 'Engine probe times out safely'
        Assert ($timer.ElapsedMilliseconds -lt 4000) 'Engine timeout bounds menu wait'
    }
    $script:engineCalls=0
    function Test-DevKeyDockerEngine {param($Path);$script:engineCalls++;return $script:engineReady}
    function Confirm-DevKeyOperationalIntegrity {return $script:allowIntegrity}
    $script:allowIntegrity=$true;$script:engineReady=$false
    Assert (-not(Invoke-DevKeyDocker)) 'Unavailable Docker engine returns safely'
    $script:engineReady=$true
    Assert (Invoke-DevKeyDocker) 'Available Docker engine reported after actual probe hook'
    $before=$script:engineCalls;$script:allowIntegrity=$false
    Assert (-not(Invoke-DevKeyDocker)) 'Docker respects operational integrity denial'
    Assert ($script:engineCalls -eq $before) 'Integrity denial prevents Docker execution'
} finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Output ("RESULT passed={0} failed=0" -f $script:passed)
