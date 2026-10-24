$ErrorActionPreference='Stop'
$script:TestRoot=Join-Path ([IO.Path]::GetTempPath()) ('DevKey-tests-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
$script:passed=0;$script:failed=0;$script:skipped=0
function Assert-DevKeyTest {param([string]$Name,[bool]$Condition);if($Condition){$script:passed++;Write-Host "PASS $Name" -ForegroundColor Green}else{$script:failed++;Write-Host "FAIL $Name" -ForegroundColor Red}}
try {
    $script:DevKeyRoot=$script:TestRoot;$script:UsbRoot=$script:TestRoot
    $script:ConfigRoot=Join-Path $script:TestRoot 'Config';$script:LogsRoot=Join-Path $script:TestRoot 'Logs';$script:BackupsRoot=Join-Path $script:TestRoot 'Backups';$script:DataRoot=Join-Path $script:TestRoot 'Data';$script:AppsRoot=Join-Path $script:TestRoot 'Apps';$script:ProjectsRoot=Join-Path $script:TestRoot 'Projects';$script:KiroData=Join-Path $script:DataRoot 'KiroUser';$script:GitPath=Join-Path $script:AppsRoot 'Git\cmd\git.exe';$script:KeyFile=Join-Path $script:TestRoot 'unlock.k3y';$script:ConfigFile=Join-Path $script:ConfigRoot 'config.json';$script:VersionFile=Join-Path $script:ConfigRoot 'version.json';$script:AuthFile=Join-Path $script:ConfigRoot 'auth.json';$script:LockoutFile=Join-Path $script:ConfigRoot 'lockout.json';$script:ManifestFile=Join-Path $script:ConfigRoot 'manifests\integrity.json'
    foreach($p in @($script:ConfigRoot,$script:LogsRoot,$script:BackupsRoot,$script:DataRoot,$script:AppsRoot,$script:ProjectsRoot,(Join-Path $script:ConfigRoot 'manifests'))){New-Item -ItemType Directory -Path $p -Force | Out-Null}
    . (Join-Path $PSScriptRoot '..\Core\ErrorHandler.ps1');. (Join-Path $PSScriptRoot '..\Core\Bootstrap.ps1');. (Join-Path $PSScriptRoot '..\Security\Authentication.ps1');. (Join-Path $PSScriptRoot '..\Security\Integrity.ps1');. (Join-Path $PSScriptRoot '..\Modules\Projects.ps1')
    Import-DevKeyConfiguration
    Assert-DevKeyTest 'creates default config when missing' (Test-Path -LiteralPath $script:ConfigFile -PathType Leaf)
    $original=Get-Content -LiteralPath $script:ConfigFile -Raw;Set-Content -LiteralPath $script:ConfigFile -Value '{broken' -Encoding UTF8;$rejected=$false;try{Import-DevKeyConfiguration}catch{$rejected=$true};Assert-DevKeyTest 'rejects invalid config without overwriting' ($rejected -and (Get-Content -LiteralPath $script:ConfigFile -Raw).Trim() -eq '{broken');Set-Content -LiteralPath $script:ConfigFile -Value $original -Encoding UTF8;Import-DevKeyConfiguration
    $record=New-DevKeyKdfRecord -Password 'Test-Pass-123';Assert-DevKeyTest 'PBKDF2 accepts correct password' (Test-DevKeyKdfRecord -Password 'Test-Pass-123' -Record ([pscustomobject]$record));Assert-DevKeyTest 'PBKDF2 rejects wrong password' (-not (Test-DevKeyKdfRecord -Password 'wrong' -Record ([pscustomobject]$record)))
    $salt=New-Object byte[] 16;[Array]::Copy([Text.Encoding]::UTF8.GetBytes('legacy-salt-1234'),$salt,16);$kdf=New-Object Security.Cryptography.Rfc2898DeriveBytes('Old-Pass-123',$salt,150000,[Security.Cryptography.HashAlgorithmName]::SHA256);$bytes=$kdf.GetBytes(32);$kdf.Dispose();$hex=([BitConverter]::ToString($bytes)-replace '-','').ToLowerInvariant();$legacy=[pscustomobject]@{algorithm='PBKDF2-SHA256';iterations=150000;salt=[Convert]::ToBase64String($salt);hash=$hex};Assert-DevKeyTest 'accepts legacy PBKDF2 hex record' (Test-DevKeyKdfRecord -Password 'Old-Pass-123' -Record $legacy)
    Set-DevKeyLockoutState -Failures 2;Assert-DevKeyTest 'lockout failure counter persists' ((Get-DevKeyLockoutState).Failures -eq 2)
    $safe=Get-DevKeySafeProjectPath 'Project-One';Assert-DevKeyTest 'project path remains inside Projects' ($safe.StartsWith($script:ProjectsRoot,[StringComparison]::OrdinalIgnoreCase));$traversalRejected=$false;try{Get-DevKeySafeProjectPath '..\outside'|Out-Null}catch{$traversalRejected=$true};Assert-DevKeyTest 'rejects project traversal' $traversalRejected
    Assert-DevKeyTest 'integrity is explicitly unconfigured without manifest' ((Get-DevKeyIntegrityStatus).Status -eq 'UNCONFIGURED')
    $code=Join-Path $script:DevKeyRoot 'sample.ps1';Set-Content -LiteralPath $code -Value 'one' -Encoding UTF8;$hash=(Get-FileHash -LiteralPath $code -Algorithm SHA256).Hash;@{Version=1;Trust='UNSIGNED-LOCAL';Files=@(@{Path='sample.ps1';SHA256=$hash})}|ConvertTo-Json -Depth 3|Set-Content -LiteralPath $script:ManifestFile -Encoding UTF8
    # The production verifier uses Windows path containment rules.
    # Do not mock those rules or count Linux execution as Windows verification.
    if ([IO.Path]::DirectorySeparatorChar -eq '\') {
        Assert-DevKeyTest 'local manifest reports unsigned status when matching' ((Get-DevKeyIntegrityStatus).Status -eq 'UNSIGNED-LOCAL')
        Set-Content -LiteralPath $code -Value 'two' -Encoding UTF8
        $status=Get-DevKeyIntegrityStatus
        Assert-DevKeyTest 'integrity detects changed file' ($status.Status -eq 'MISMATCH' -and @($status.Changed) -contains 'sample.ps1')
    } else {
        $script:skipped+=2
        Write-Host 'SKIP matching-manifest and changed-file checks require Windows path containment (run on Windows PowerShell 5.1).'
    }
    # Retain regression coverage for the invalid fixture that caused the old failures.
    @{Files=@(@{Path='sample.ps1';SHA256=$hash})}|ConvertTo-Json -Depth 3|Set-Content -LiteralPath $script:ManifestFile -Encoding UTF8
    Assert-DevKeyTest 'manifest missing version and trust is rejected' ((Get-DevKeyIntegrityStatus).Status -eq 'INVALID')
    @{Version=1;Trust='SIGNED';Files=@(@{Path='sample.ps1';SHA256=$hash})}|ConvertTo-Json -Depth 3|Set-Content -LiteralPath $script:ManifestFile -Encoding UTF8
    Assert-DevKeyTest 'unsupported manifest trust is rejected' ((Get-DevKeyIntegrityStatus).Status -eq 'INVALID')

    Write-Host "RESULT passed=$script:passed failed=$script:failed skipped=$script:skipped"
    if($script:failed -gt 0){exit 1}
} finally {Remove-Item -LiteralPath $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue}
