$ErrorActionPreference='Stop'
$script:Failures=New-Object System.Collections.Generic.List[string]
$script:Passes=0
$script:Skipped=0
function Skip-DevKeyTest([string]$Name){$script:Skipped++;Write-Host "SKIP $Name" -ForegroundColor Yellow}
function Assert-DevKeyTest([bool]$Condition,[string]$Name){if($Condition){$script:Passes++;Write-Host "PASS $Name" -ForegroundColor Green}else{$script:Failures.Add($Name);Write-Host "FAIL $Name" -ForegroundColor Red}}
function Pause-DevKey {}
function Pause {}
$script:PromptQueue=New-Object System.Collections.Generic.Queue[string]
$global:DevKeySmokePromptQueue=$script:PromptQueue
function Read-Host {
    param([string]$Prompt,[switch]$AsSecureString)
    if(-not $global:DevKeySmokePromptQueue.Count){throw ('Unexpected smoke-test prompt: '+$Prompt)}
    $value=$global:DevKeySmokePromptQueue.Dequeue()
    if($AsSecureString){return (ConvertTo-SecureString -String $value -AsPlainText -Force)}
    return $value
}
$sourceRoot=Split-Path -Parent $PSScriptRoot
$sandbox=Join-Path ([IO.Path]::GetTempPath()) ('DevKey-smoke-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $sandbox -Force|Out-Null
try {
    $script:DevKeyRoot=$sandbox
    $script:UsbRoot=Join-Path $sandbox 'USB'
    $script:ConfigRoot=Join-Path $sandbox 'DevKey\Config'
    $script:LogsRoot=Join-Path $sandbox 'DevKey\Logs'
    $script:BackupsRoot=Join-Path $sandbox 'DevKey\Backups'
    $script:RuntimeRoot=Join-Path $sandbox 'DevKey\Data\Runtime'
    $script:DataRoot=Join-Path $sandbox 'USB\Data'
    $script:ProjectsRoot=Join-Path $sandbox 'USB\Projects'
    $script:ProjectsPath=$script:ProjectsRoot
    $script:AppsRoot=Join-Path $sandbox 'USB\Apps'
    $script:KiroData=Join-Path $script:DataRoot 'KiroUser'
    $script:ConfigFile=Join-Path $script:ConfigRoot 'config.json'
    $script:VersionFile=Join-Path $script:ConfigRoot 'version.json'
    $script:AuthFile=Join-Path $script:ConfigRoot 'auth.json'
    $script:LockoutFile=Join-Path $script:ConfigRoot 'lockout.json'
    $script:ManifestFile=Join-Path $script:ConfigRoot 'manifests\integrity.json'
    $script:KeyFile=Join-Path $script:UsbRoot 'unlock.k3y'
    $script:GitConfigFile=Join-Path $script:ConfigRoot 'git.json'
    $script:GitPath=Join-Path $script:AppsRoot 'Git\cmd\git.exe'
    $script:DevKeyLogFile=Join-Path $script:LogsRoot 'devkey.log'
    foreach($path in @($script:UsbRoot,$script:ConfigRoot,$script:LogsRoot,$script:BackupsRoot,$script:RuntimeRoot,$script:ProjectsRoot,$script:AppsRoot,(Split-Path -Parent $script:ManifestFile))){New-Item -ItemType Directory -Path $path -Force|Out-Null}

    . (Join-Path $sourceRoot 'Core\Bootstrap.ps1')
    . (Join-Path $sourceRoot 'Core\ErrorHandler.ps1')
    . (Join-Path $sourceRoot 'Security\Authentication.ps1')
    . (Join-Path $sourceRoot 'Security\Integrity.ps1')
    . (Join-Path $sourceRoot 'Modules\Applications.ps1')
    . (Join-Path $sourceRoot 'Modules\Projects.ps1')
    . (Join-Path $sourceRoot 'Modules\GitManager.ps1')
    . (Join-Path $sourceRoot 'Modules\Maintenance.ps1')
    . (Join-Path $sourceRoot 'Modules\Templates.ps1')
    . (Join-Path $sourceRoot 'Modules\PromptLibrary.ps1')
    . (Join-Path $sourceRoot 'Modules\DevKey.Profiles.ps1')
    $backupModule=Join-Path $sourceRoot 'Modules\DevKey.backup.ps1'
    if(Test-Path -LiteralPath $backupModule -PathType Leaf){. $backupModule}
    . (Join-Path $sourceRoot 'Modules\DevKey.GitX.ps1')
    . (Join-Path $sourceRoot 'Modules\DevKey.GitCreds.ps1')
    . (Join-Path $sourceRoot 'Modules\SystemInfo.ps1')
    . (Join-Path $sourceRoot 'Core\ProcessManager.ps1')
    . (Join-Path $sourceRoot 'Guardian\GuardianManager.ps1')

    $sample=@{
        Version='2.0.0';
        Security=@{MaxAttempts=3;ProgressiveLockout=$true};
        Guardian=@{Enabled=$true;AutoLaunch=$false;AutoClose=$true;CheckIntervalSeconds=2;LogEvents=$true};
        Applications=@{Kiro=@{Enabled=$true;AutoClose=$true;Path='Apps\Kiro\Kiro.exe'};OpenCode=@{Enabled=$true;AutoClose=$true;Path='Apps\OpenCode\opencode.exe'};Git=@{Enabled=$true};};
        Logging=@{Enabled=$true;MaxFileSizeMB=1;RetentionDays=30};
        Interface=@{Theme='Classic'}
    }
    $sample|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $script:ConfigFile -Encoding UTF8
    Import-DevKeyConfiguration
    Assert-DevKeyTest ($script:DevKeyConfig.Security.PBKDF2Iterations -ge 100000) 'Config example receives safe defaults for omitted security values'
    Assert-DevKeyTest ($script:DevKeyConfig.Security.TokenSha256 -match '^[A-Fa-f0-9]{64}$') 'Config defaults include a SHA-256 token digest'
    $script:DevKeyConfig.Interface.Theme='Matrix';Save-DevKeyConfiguration
    Assert-DevKeyTest ((Get-ChildItem -LiteralPath $script:BackupsRoot -Filter 'config-*.json').Count -eq 1) 'Config changes create a dated backup'

    $badConfig='{ malformed'
    Set-Content -LiteralPath $script:ConfigFile -Value $badConfig -Encoding UTF8
    try{Import-DevKeyConfiguration;Assert-DevKeyTest $false 'Malformed config is rejected'}catch{Assert-DevKeyTest ((Get-Content -LiteralPath $script:ConfigFile -Raw).Trim() -eq $badConfig) 'Malformed config is rejected without replacement'}
    $sample|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $script:ConfigFile -Encoding UTF8
    Import-DevKeyConfiguration

    $record=New-DevKeyKdfRecord -Password 'Smoke-test-password-24'
    Assert-DevKeyTest (Test-DevKeyKdfRecord -Password 'Smoke-test-password-24' -Record $record) 'PBKDF2 accepts matching password'
    Assert-DevKeyTest (-not(Test-DevKeyKdfRecord -Password 'wrong-password' -Record $record)) 'PBKDF2 rejects incorrect password'
    $script:AuthFile=Join-Path $script:ConfigRoot 'auth.json'
    Save-DevKeyAuthRecord -Record $record
    Assert-DevKeyTest (Test-Path -LiteralPath $script:AuthFile) 'Authentication record persists without plaintext password'
    $legacySalt=New-Object byte[] 16;for($i=0;$i -lt 16;$i++){$legacySalt[$i]=$i}
    $legacyKdf=New-Object Security.Cryptography.Rfc2898DeriveBytes('legacy-password',$legacySalt,100000,[Security.Cryptography.HashAlgorithmName]::SHA256)
    try{$legacyHash=[BitConverter]::ToString($legacyKdf.GetBytes(32)).Replace('-','').ToLowerInvariant()}finally{$legacyKdf.Dispose()}
    $legacy=[pscustomobject]@{version='1.0';algorithm='PBKDF2-SHA256';iterations=100000;salt=[Convert]::ToBase64String($legacySalt);hash=$legacyHash}
    Assert-DevKeyTest (Test-DevKeyKdfRecord -Password 'legacy-password' -Record $legacy) 'Legacy PBKDF2-SHA256 hex record remains readable'
    Set-DevKeyLockoutState -Failures 4 -UntilUtc ([datetime]::UtcNow.AddSeconds(20))
    Assert-DevKeyTest ((Get-DevKeyLockoutState).Failures -eq 4) 'Lockout state persists'
    Remove-Item -LiteralPath $script:AuthFile -Force
    $script:PromptQueue.Enqueue('Smoke-Password-24');$script:PromptQueue.Enqueue('Smoke-Password-24')
    Assert-DevKeyTest (Initialize-DevKeyAuthentication) 'First-use password setup writes a KDF record'
    Set-DevKeyLockoutState -Failures 0
    $script:DevKeyConfig.Security.MaxAttempts=1;$script:DevKeyConfig.Security.ProgressiveLockout=$false
    $script:PromptQueue.Enqueue('wrong-password')
    Assert-DevKeyTest (-not(Test-DevKeyAuthentication)) 'Wrong password does not authenticate'
    $script:PromptQueue.Enqueue('Smoke-Password-24')
    Assert-DevKeyTest (Test-DevKeyAuthentication) 'Correct password authenticates'
    $script:PromptQueue.Enqueue('Smoke-Password-24');$script:PromptQueue.Enqueue('Changed-Password-24');$script:PromptQueue.Enqueue('Changed-Password-24')
    Assert-DevKeyTest (Set-DevKeyPassword) 'Password change verifies old password and saves replacement'
    $recoveryKey='Recovery-key-value-only-in-test'
    (New-DevKeyKdfRecord -Password $recoveryKey)|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $script:ConfigRoot 'recovery.json') -Encoding UTF8
    $script:PromptQueue.Enqueue($recoveryKey);$script:PromptQueue.Enqueue('Recovered-Password-24');$script:PromptQueue.Enqueue('Recovered-Password-24')
    Assert-DevKeyTest (Invoke-DevKeyRecovery) 'Recovery resets password and consumes one-time key'
    Assert-DevKeyTest (-not(Test-Path -LiteralPath (Join-Path $script:ConfigRoot 'recovery.json'))) 'Recovery key is single-use'
    $authBackup=Join-Path $script:BackupsRoot 'auth-valid-test.json';Copy-Item -LiteralPath $script:AuthFile -Destination $authBackup
    Set-Content -LiteralPath $script:AuthFile -Value '{ bad auth json' -Encoding UTF8
    try{Test-DevKeyAuthentication|Out-Null;Assert-DevKeyTest $false 'Corrupt auth is rejected'}catch{Assert-DevKeyTest ((Get-Content -LiteralPath $script:AuthFile -Raw).Trim() -eq '{ bad auth json') 'Corrupt auth is rejected without replacement'}
    Copy-Item -LiteralPath $authBackup -Destination $script:AuthFile -Force
    $script:DevKeyConfig.Security.MaxAttempts=3;$script:DevKeyConfig.Security.ProgressiveLockout=$true

    Write-DevKeyLog -Log access.log -Level AUDIT -Message 'Test token=ghp_abcdefghijklmnopqrstuvwxyz0123456789'
    $log=Get-Content -LiteralPath (Join-Path $script:LogsRoot 'access.log') -Raw
    Assert-DevKeyTest ($log -notmatch 'ghp_abcdefghijklmnopqrstuvwxyz') 'Logs redact token-like values'
    Write-DevKeyLog -Log access.log -Message 'https://ghp_abcdefghijklmnopqrstuvwxyz0123456789@github.com/org/repo.git'
    Add-DevKeySyncRecord -Repository 'sample' -Action 'push' -Result 'ok' -Details 'https://ghp_abcdefghijklmnopqrstuvwxyz0123456789@github.com/org/repo.git'
    $syncLog=Get-Content -LiteralPath $script:DevKeySyncHistoryFile -Raw
    Assert-DevKeyTest ($syncLog -notmatch 'ghp_abcdefghijklmnopqrstuvwxyz') 'Git sync history redacts credentials embedded in URLs'

    $script:ProjectsRoot=Join-Path $script:UsbRoot 'Projects';$script:ProjectsPath=$script:ProjectsRoot;New-Item -ItemType Directory -Path $script:ProjectsRoot -Force|Out-Null
    Assert-DevKeyTest ((Get-DevKeySafeProjectPath 'LabControl').StartsWith($script:ProjectsRoot,[StringComparison]::OrdinalIgnoreCase)) 'Project path stays within Projects'
    $rejected=$false;try{Get-DevKeySafeProjectPath '..\outside'|Out-Null}catch{$rejected=$true}
    Assert-DevKeyTest $rejected 'Project traversal is rejected'
    $rejected=$false;try{Get-DevKeySafeProjectPath 'CON'|Out-Null}catch{$rejected=$true}
    Assert-DevKeyTest $rejected 'Windows reserved project names are rejected'

    $kiro=Join-Path $script:AppsRoot 'Kiro\Kiro.exe';New-Item -ItemType Directory -Path (Split-Path -Parent $kiro) -Force|Out-Null;Set-Content -LiteralPath $kiro -Value 'placeholder'
    Assert-DevKeyTest ((Get-DevKeyApplicationPath -Name Kiro) -eq $kiro) 'Application paths resolve from the removable drive root'

    if(Test-Path -LiteralPath $backupModule -PathType Leaf){
        $project=Join-Path $script:ProjectsRoot 'sample';New-Item -ItemType Directory -Path $project -Force|Out-Null
        Set-Content -LiteralPath (Join-Path $project 'readme.txt') -Value 'safe project data'
        Set-Content -LiteralPath (Join-Path $project '.env') -Value 'secret=should-not-be-backed-up'
        $script:DevKeySessionId='smoke'
        $script:PromptQueue.Enqueue('')
        New-DevKeyProjectBackup
        $archive=Get-ChildItem -LiteralPath $script:BackupsRoot -Filter 'Projects-*.zip' -File|Select-Object -First 1
        $backupStatus=if($archive){Test-DevKeyProjectBackup -Path $archive.FullName}else{$null}
        Assert-DevKeyTest ($backupStatus -and $backupStatus.Valid -and $backupStatus.ExcludedCount -ge 1) 'Project backup verifies and excludes sensitive paths'
        $script:PromptQueue.Enqueue('1');$script:PromptQueue.Enqueue('RESTAURAR');$script:PromptQueue.Enqueue('')
        Restore-DevKeyProjectBackup
        $restored=Get-ChildItem -LiteralPath $script:ProjectsRoot -Directory -Filter 'Restored-*'|Select-Object -First 1
        Assert-DevKeyTest ($restored -and (Test-Path -LiteralPath (Join-Path $restored.FullName 'sample\readme.txt')) -and -not(Test-Path -LiteralPath (Join-Path $restored.FullName 'sample\.env'))) 'Backup restores to a new path and keeps excluded secrets out'

        Assert-DevKeyTest ($script:PromptQueue.Count -eq 0) 'Backup restore consumes its expected prompts'
    } else {
        Skip-DevKeyTest 'Project backup verification: optional DevKey.backup.ps1 is absent'
        Skip-DevKeyTest 'Project restore: optional DevKey.backup.ps1 is absent'
    }

    $template=Get-DevKeyTemplateFiles -Index 2 -Name 'smoke-project'
    $package=($template|Where-Object {$_.Name -eq 'package.json'})['Content']
    Assert-DevKeyTest ((ConvertFrom-Json $package).name -eq 'smoke-project') 'Node template creates valid package JSON'
    $template=Get-DevKeyTemplateFiles -Index 4 -Name "smoke & project's app"
    $package=($template|Where-Object {$_.Name -eq 'package.json'})['Content']
    Assert-DevKeyTest ((ConvertFrom-Json $package).name -eq 'smoke-project-s-app') 'Next template safely normalizes package names'
    Assert-DevKeyTest (@($template|Where-Object {$_.Name -like 'app/*'}).Count -ge 2) 'Next template includes app router page and layout'

    if([IO.Path]::DirectorySeparatorChar -eq '\'){
        $psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $command64=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes('Start-Sleep -Seconds 2'))
        $script:DevKeySessionFile=Join-Path $script:RuntimeRoot 'managed-processes.json'
        $script:DevKeySessionId='smoke'
        $managed=Start-DevKeyManagedProcess -FilePath $psExe -ArgumentList @('-NoProfile','-EncodedCommand',$command64) -Application 'Smoke'
        $tracked=@(Get-DevKeyTrackedProcesses)
        Assert-DevKeyTest (@($tracked|Where-Object Pid -eq $managed.Id).Count -eq 1) 'Process manager tracks an owned process by PID and identity'
        Stop-DevKeyManagedProcesses
        Assert-DevKeyTest ((Get-Process -Id $managed.Id -ErrorAction SilentlyContinue) -eq $null) 'Process manager requests cooperative close for tracked session process'

    } else {
        Skip-DevKeyTest 'Managed Windows PowerShell process ownership requires Windows'
        Skip-DevKeyTest 'Cooperative Windows process shutdown requires Windows'
    }

    $critical=Join-Path $script:DevKeyRoot 'critical.ps1';Set-Content -LiteralPath $critical -Value 'Write-Output stable'
    $hash=(Get-FileHash -LiteralPath $critical -Algorithm SHA256).Hash
    [ordered]@{Version=1;Trust='UNSIGNED-LOCAL';Files=@([pscustomobject]@{Path='critical.ps1';SHA256=$hash})}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $script:ManifestFile -Encoding UTF8
    if([IO.Path]::DirectorySeparatorChar -eq '\'){
        $status=Get-DevKeyIntegrityStatus
        Assert-DevKeyTest ($status.Status -eq 'UNSIGNED-LOCAL') 'Integrity manifest reports unsigned local trust'
        Set-Content -LiteralPath $critical -Value 'Write-Output changed'
        $status=Get-DevKeyIntegrityStatus
        Assert-DevKeyTest ($status.Status -eq 'MISMATCH' -and @($status.Changed) -contains 'critical.ps1') 'Integrity detects a changed critical file'
    } else {
        Skip-DevKeyTest 'Matching integrity manifest requires Windows path containment'
        Skip-DevKeyTest 'Integrity file tampering requires Windows path containment'
    }

    $dashboard=Get-DevKeyDashboard
    Assert-DevKeyTest (@($dashboard.Name) -contains 'OpenCode') 'Dashboard reports configured application states'

    $portableRoot=Join-Path $sandbox 'PortableLetterF'
    $portableDevKey=Join-Path $portableRoot 'DevKey'
    $portableCore=Join-Path $portableDevKey 'Core'
    New-Item -ItemType Directory -Path $portableCore -Force|Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'Core\PathManager.ps1') -Destination (Join-Path $portableCore 'PathManager.ps1')
    . (Join-Path $portableCore 'PathManager.ps1')
    Initialize-DevKeyPaths
    Assert-DevKeyTest ($script:DevKeyRoot -eq $portableDevKey -and $script:UsbRoot -eq $portableRoot -and $script:KeyFile -eq (Join-Path $portableRoot 'unlock.k3y')) 'Path manager derives USB and DevKey roots from the launcher tree'

    # Each launcher scenario gets an independent USB tree and generated configuration.
    # Never copy Config, user data, credentials, tokens, vaults or projects from checkout/USB.
    $currentHost=(Get-Process -Id $PID).Path
    $worker=Join-Path $PSScriptRoot 'Fixtures\Invoke-LauncherFixture.ps1'
    foreach($scenario in @('Navigation','BadToken','BadPassword','InvalidIntegrity')){
        $fixtureUsb=Join-Path $sandbox ('LauncherFixture-'+$scenario)
        $fixtureDevKey=Join-Path $fixtureUsb 'DevKey'
        New-Item -ItemType Directory -Path $fixtureDevKey -Force|Out-Null
        Set-Content -LiteralPath (Join-Path $fixtureDevKey '.devkey-smoke-fixture') -Value 'temporary test fixture'
        foreach($directory in @('Launcher','Core','Modules','Security','Guardian')){
            $destination=Join-Path $fixtureDevKey $directory
            New-Item -ItemType Directory -Path $destination -Force|Out-Null
            Get-ChildItem -LiteralPath (Join-Path $sourceRoot $directory) -Filter '*.ps1' -File | ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination $destination
            }
        }
        $fixtureConfigRoot=Join-Path $fixtureDevKey 'Config'
        New-Item -ItemType Directory -Path $fixtureConfigRoot -Force|Out-Null
        $fixtureKey=Join-Path $fixtureUsb 'unlock.k3y'
        $fixtureBytes=New-Object byte[] 32
        $rng=[Security.Cryptography.RandomNumberGenerator]::Create()
        try{$rng.GetBytes($fixtureBytes)}finally{$rng.Dispose()}
        [IO.File]::WriteAllBytes($fixtureKey,$fixtureBytes)
        $fixtureHash=(Get-FileHash -LiteralPath $fixtureKey -Algorithm SHA256).Hash
        $fixtureConfig=$script:DevKeyDefaultConfig | ConvertTo-Json -Depth 12 | ConvertFrom-Json
        $fixtureConfig.Security.TokenSha256=$fixtureHash
        $fixtureConfig.Security.MaxAttempts=1
        $fixtureConfig.Guardian.Enabled=$false
        $fixtureConfig.Guardian.AutoLaunch=$false
        foreach($app in $fixtureConfig.Applications.PSObject.Properties){$app.Value.Enabled=$false}
        # A non-executable fixture file allows opening Git's menu without running Git.
        $fixtureConfig.Applications.Git.Enabled=$true
        $fixtureGit=Join-Path $fixtureUsb $fixtureConfig.Applications.Git.Path
        New-Item -ItemType Directory -Path (Split-Path -Parent $fixtureGit) -Force|Out-Null
        Set-Content -LiteralPath $fixtureGit -Value 'test placeholder: never execute'
        if($scenario -eq 'InvalidIntegrity'){
            $fixtureConfig.Applications.Kiro.Enabled=$true
            $fixtureKiro=Join-Path $fixtureUsb $fixtureConfig.Applications.Kiro.Path
            New-Item -ItemType Directory -Path (Split-Path -Parent $fixtureKiro) -Force|Out-Null
            Set-Content -LiteralPath $fixtureKiro -Value 'test placeholder: never execute'
            $manifestDirectory=Join-Path $fixtureConfigRoot 'manifests'
            New-Item -ItemType Directory -Path $manifestDirectory -Force|Out-Null
            Set-Content -LiteralPath (Join-Path $manifestDirectory 'integrity.json') -Value '{invalid fixture manifest' -Encoding UTF8
        }
        $fixtureConfigPath=Join-Path $fixtureConfigRoot 'config.json'
        $fixtureConfig | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $fixtureConfigPath -Encoding UTF8
        if($scenario -eq 'BadPassword'){
            New-DevKeyKdfRecord -Password 'Fixture-password-24' | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $fixtureConfigRoot 'auth.json') -Encoding UTF8
        }
        if($scenario -eq 'BadToken'){
            $fixtureBytes[0]=$fixtureBytes[0] -bxor 255
            [IO.File]::WriteAllBytes($fixtureKey,$fixtureBytes)
        }
        $tokenHashBefore=(Get-FileHash -LiteralPath $fixtureKey -Algorithm SHA256).Hash
        $authHashBefore=if($scenario -eq 'BadPassword'){(Get-FileHash -LiteralPath (Join-Path $fixtureConfigRoot 'auth.json') -Algorithm SHA256).Hash}else{$null}
        # Enrol only the copied launcher with the temporary token, keeping the gate intact.
        $fixtureLauncher=Join-Path $fixtureDevKey 'Launcher\DevKey.ps1'
        $launcherText=[IO.File]::ReadAllText($fixtureLauncher)
        $pinMatch=[regex]::Match($launcherText,"(?m)^\`$script:DevKeyPinnedTokenSha256='([A-Fa-f0-9]{64})'\s*$")
        if(-not $pinMatch.Success){throw 'Fixture launcher token pin was not found.'}
        $launcherText=$launcherText.Replace($pinMatch.Groups[1].Value,$fixtureHash)
        [IO.File]::WriteAllText($fixtureLauncher,$launcherText,(New-Object Text.UTF8Encoding($true)))
        $stdout=Join-Path $fixtureDevKey 'fixture-stdout.txt'
        $stderr=Join-Path $fixtureDevKey 'fixture-stderr.txt'
        $arguments=@('-NoProfile','-NonInteractive','-File',('"'+$worker+'"'),'-FixtureRoot',('"'+$fixtureDevKey+'"'),'-Scenario',$scenario)
        $child=$null
        try {
            $child=Start-Process -FilePath $currentHost -ArgumentList $arguments -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
            # Retain the process handle so .NET Framework/Windows preserves ExitCode.
            [void]$child.Handle
            $completed=$child.WaitForExit(45000)
            if(-not $completed){$child.Kill();[void]$child.WaitForExit(5000)}
            Assert-DevKeyTest $completed ("$scenario launcher terminates within 45 seconds")
            if(-not $completed){continue}
            $child.Refresh()
            Assert-DevKeyTest ($child.ExitCode -eq 0) ("$scenario launcher worker exits successfully")
            $resultPath=Join-Path $fixtureDevKey 'fixture-result.json'
            $hasResult=Test-Path -LiteralPath $resultPath -PathType Leaf
            Assert-DevKeyTest $hasResult ("$scenario writes a current fixture result")
            if(-not $hasResult){continue}
            $result=Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            if(@($result.Failures).Count){$result.Failures | ForEach-Object {Write-Host $_ -ForegroundColor Red}}
            Assert-DevKeyTest (@($result.Failures).Count -eq 0) ("$scenario has no prompt mismatches, launch attempts or logged errors")
            Assert-DevKeyTest (($result.Completed -join '|') -ceq ($result.Expected -join '|')) ("$scenario consumes exactly the expected navigation")
            Assert-DevKeyTest ($result.ProcessAttempts -eq 0) ("$scenario never launches host applications")
            Assert-DevKeyTest ((Get-FileHash -LiteralPath $fixtureKey -Algorithm SHA256).Hash -ceq $tokenHashBefore) ("$scenario preserves the temporary token bytes")
            $accessPath=Join-Path $fixtureDevKey 'Logs\access.log'
            $access=if(Test-Path -LiteralPath $accessPath){Get-Content -LiteralPath $accessPath -Raw}else{''}
            $sessions=[regex]::Matches($access,'Sesion DevKey iniciada\.').Count
            if($scenario -eq 'Navigation'){
                $routeSteps=@{1='software-return';2='github-return';3='projects-return';4='status-return';5='maintenance-return';6='security-return';7='info-return'}
                foreach($key in 1..7){
                    Assert-DevKeyTest ((@($result.Completed) -contains ("main-$key")) -and (@($result.Completed) -contains $routeSteps[$key])) ("Main option $key reaches its real handler")
                }
                foreach($key in 1..4){Assert-DevKeyTest (@($result.Completed) -contains ("software-$key")) ("Software option $key returns safely")}
                foreach($menu in @('software','github','projects','maintenance','security')){
                    Assert-DevKeyTest (@($result.Completed) -contains ($menu+'-return')) ("$menu option 0 returns to main with one selection")
                }
                Assert-DevKeyTest ($sessions -eq 1 -and [regex]::Matches($access,'Initial password configured\.').Count -eq 1 -and [regex]::Matches($access,'Sesion DevKey finalizada\.').Count -eq 1) 'Authentication/setup and session lifecycle occur exactly once'
                $authPath=Join-Path $fixtureConfigRoot 'auth.json'
                $authValid=$false
                if(Test-Path -LiteralPath $authPath){
                    $fixtureAuth=Get-Content -LiteralPath $authPath -Raw | ConvertFrom-Json
                    $authValid=Test-DevKeyKdfRecord -Password 'Fixture-password-24' -Record $fixtureAuth
                }
                Assert-DevKeyTest $authValid 'Launcher persists only the temporary password KDF record'
            } elseif($scenario -eq 'BadToken'){
                Assert-DevKeyTest ($sessions -eq 0 -and -not(Test-Path -LiteralPath (Join-Path $fixtureConfigRoot 'auth.json'))) 'Tampered temporary token blocks authentication and main menu'
            } elseif($scenario -eq 'BadPassword'){
                Assert-DevKeyTest ($sessions -eq 0 -and [regex]::Matches($access,'Authentication failed\.').Count -eq 1) 'Wrong temporary password blocks the session'
                Assert-DevKeyTest ((Get-FileHash -LiteralPath (Join-Path $fixtureConfigRoot 'auth.json') -Algorithm SHA256).Hash -ceq $authHashBefore) 'Rejected password leaves the temporary authentication record unchanged'
            } else {
                Assert-DevKeyTest (@($result.Completed) -contains 'integrity-denied-pause') 'Invalid manifest blocks the software operation through the real integrity gate'
            }
        } finally {
            if($child){if(-not $child.HasExited){$child.Kill();[void]$child.WaitForExit(5000)};$child.Dispose()}
        }
    }
} finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host ("`nSmoke tests passed: {0}; failed: {1}; skipped: {2}" -f $script:Passes,$script:Failures.Count,$script:Skipped)
if($script:Failures.Count){$script:Failures|ForEach-Object{Write-Host " - $_"};exit 1}

