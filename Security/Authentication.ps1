function ConvertTo-DevKeySecureText {
    param([Security.SecureString]$Value)
    $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

function New-DevKeyKdfRecord {
    param([Parameter(Mandatory=$true)][string]$Password,[int]$Iterations=[int]$script:DevKeyConfig.Security.PBKDF2Iterations)
    $salt=New-Object byte[] 16; $rng=[Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($salt) } finally { $rng.Dispose() }
    $kdf=New-Object Security.Cryptography.Rfc2898DeriveBytes($Password,$salt,$Iterations,[Security.Cryptography.HashAlgorithmName]::SHA256)
    try { $hash=$kdf.GetBytes(32) } finally { $kdf.Dispose() }
    return [ordered]@{Version=1;Algorithm='PBKDF2-SHA256';Iterations=$Iterations;Salt=[Convert]::ToBase64String($salt);Hash=[Convert]::ToBase64String($hash)}
}

function Test-DevKeyKdfRecord {
    param([string]$Password,$Record)
    if (-not $Record -or [string]$Record.Algorithm -notin @('PBKDF2-SHA256','PBKDF2-SHA1') -or [int]$Record.Iterations -lt 100000 -or [int]$Record.Iterations -gt 2000000) { throw 'Invalid authentication record.' }
    $salt=[Convert]::FromBase64String([string]$Record.Salt)
    $hashText=[string]$Record.Hash
    if ($hashText -match '^[A-Fa-f0-9]{64}$') { $expected=New-Object byte[] 32; for($i=0;$i -lt 32;$i++){$expected[$i]=[Convert]::ToByte($hashText.Substring($i*2,2),16)} }
    else { $expected=[Convert]::FromBase64String($hashText) }
    if ($salt.Length -lt 16 -or $expected.Length -ne 32) { throw 'Invalid authentication record.' }
    if ([string]$Record.Algorithm -eq 'PBKDF2-SHA1') { $kdf=New-Object Security.Cryptography.Rfc2898DeriveBytes($Password,$salt,[int]$Record.Iterations) }
    else { $kdf=New-Object Security.Cryptography.Rfc2898DeriveBytes($Password,$salt,[int]$Record.Iterations,[Security.Cryptography.HashAlgorithmName]::SHA256) }
    try { $actual=$kdf.GetBytes(32) } finally { $kdf.Dispose() }
    $diff=0; for($i=0;$i -lt 32;$i++){$diff=$diff -bor ($actual[$i] -bxor $expected[$i])}
    return ($diff -eq 0)
}

function Save-DevKeyAuthRecord {
    param([Parameter(Mandatory=$true)]$Record)
    if (Test-Path -LiteralPath $script:AuthFile -PathType Leaf) {
        $backup=Join-Path $script:BackupsRoot ('auth-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.json')
        Copy-Item -LiteralPath $script:AuthFile -Destination $backup -ErrorAction Stop
    }
    $temp=$script:AuthFile+'.tmp'
    try { $Record | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $temp -Encoding UTF8 -ErrorAction Stop; Move-Item -LiteralPath $temp -Destination $script:AuthFile -Force -ErrorAction Stop }
    catch { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue; throw 'Could not save auth.json; the existing file was preserved.' }
}

function Test-DevKeyPhysicalToken {
    if (-not (Test-Path -LiteralPath $script:KeyFile -PathType Leaf)) { return $false }
    try { $actual=(Get-FileHash -LiteralPath $script:KeyFile -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant() } catch { return $false }
    $expected=[string]$script:DevKeyConfig.Security.TokenSha256
    return ($expected -match '^[A-Fa-f0-9]{64}$' -and $actual -ceq $expected.ToUpperInvariant())
}

function Get-DevKeyLockoutState {
    if (-not (Test-Path -LiteralPath $script:LockoutFile -PathType Leaf)) { return [pscustomobject]@{Failures=0;UntilUtc=$null} }
    try {
        $v=Get-Content -LiteralPath $script:LockoutFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ([int]$v.Failures -lt 0) { throw 'invalid' }
        return [pscustomobject]@{Failures=[int]$v.Failures;UntilUtc=$v.UntilUtc}
    } catch { throw 'Lockout state is invalid. No authentication files were changed.' }
}
function Set-DevKeyLockoutState {
    param([int]$Failures,[datetime]$UntilUtc)
    $obj=@{Failures=[Math]::Max(0,$Failures);UntilUtc=$(if($PSBoundParameters.ContainsKey('UntilUtc')){$UntilUtc.ToUniversalTime().ToString('o')}else{$null})}
    $temp=$script:LockoutFile+'.tmp';$obj | ConvertTo-Json | Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $script:LockoutFile -Force
}

function Initialize-DevKeyAuthentication {
    if (Test-Path -LiteralPath $script:AuthFile -PathType Leaf) { throw 'auth.json already exists and will not be replaced during setup.' }
    Write-Host 'First use: configure a DevKey password.' -ForegroundColor Cyan
    while ($true) {
        $secure=Read-Host 'New password (minimum 8 characters)' -AsSecureString
        $password=ConvertTo-DevKeySecureText $secure
        if ($password.Length -lt [int]$script:DevKeyConfig.Security.MinimumPasswordLength) { $password=$null;Write-Host 'Password is too short.' -ForegroundColor Yellow;continue }
        $confirm=ConvertTo-DevKeySecureText (Read-Host 'Confirm password' -AsSecureString)
        if ($password -cne $confirm) { $password=$null;$confirm=$null;Write-Host 'Passwords do not match.' -ForegroundColor Yellow;continue }
        try { Save-DevKeyAuthRecord -Record (New-DevKeyKdfRecord -Password $password) }
        finally { $password=$null;$confirm=$null;$secure=$null }
        Write-DevKeyLog -Log access.log -Level AUDIT -Message 'Initial password configured.'
        Write-Host 'Password configured.' -ForegroundColor Green
        return $true
    }
}

function Test-DevKeyAuthentication {
    if (-not (Test-Path -LiteralPath $script:AuthFile -PathType Leaf)) { return (Initialize-DevKeyAuthentication) }
    try { $auth=Get-Content -LiteralPath $script:AuthFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop; [void](Test-DevKeyKdfRecord -Password '' -Record $auth) }
    catch { Write-DevKeyLog -Level ERROR -Message 'auth.json is invalid or unreadable.'; throw 'auth.json could not be validated. It was not overwritten.' }
    $state=Get-DevKeyLockoutState
    if ($state.UntilUtc) {
        try { $until=[datetime]::Parse([string]$state.UntilUtc).ToUniversalTime() } catch { throw 'Lockout timestamp is invalid. No files were changed.' }
        if ($until -gt [datetime]::UtcNow) { $seconds=[int][Math]::Ceiling(($until-[datetime]::UtcNow).TotalSeconds);Write-Host "Access is temporarily locked ($seconds seconds)." -ForegroundColor Yellow;return $false }
    }
    for ($attempt=1;$attempt -le [int]$script:DevKeyConfig.Security.MaxAttempts;$attempt++) {
        $secure=Read-Host 'DevKey password' -AsSecureString;$password=ConvertTo-DevKeySecureText $secure
        try { $valid=Test-DevKeyKdfRecord -Password $password -Record $auth }
        catch { $password=$null;throw 'auth.json could not be validated. The original file was preserved.' }
        if ($valid) {
            if ([string]$auth.Hash -match '^[A-Fa-f0-9]{64}$' -or [string]$auth.Algorithm -eq 'PBKDF2-SHA1') { Save-DevKeyAuthRecord -Record (New-DevKeyKdfRecord -Password $password) }
            $password=$null;$secure=$null;Set-DevKeyLockoutState -Failures 0
            Write-DevKeyLog -Log access.log -Level AUDIT -Message 'Authentication succeeded.'
            return $true
        }
        $password=$null;$secure=$null
        $failures=[int]$state.Failures+1
        Write-DevKeyLog -Log access.log -Level AUDIT -Message 'Authentication failed.'
        Write-Host 'Incorrect password.' -ForegroundColor Red
        $delay=0
        if ($script:DevKeyConfig.Security.ProgressiveLockout) { if($failures -ge 10){$delay=1800}elseif($failures -ge 5){$delay=300}elseif($failures -ge 3){$delay=30} }
        if ($delay -gt 0) { Set-DevKeyLockoutState -Failures $failures -UntilUtc ([datetime]::UtcNow.AddSeconds($delay));Write-Host "Temporary lockout: $delay seconds." -ForegroundColor Yellow;return $false }
        Set-DevKeyLockoutState -Failures $failures
        if ($attempt -lt [int]$script:DevKeyConfig.Security.MaxAttempts) { Start-Sleep -Seconds 1 }
    }
    return $false
}

function Set-DevKeyPassword {
    try { $auth=Get-Content -LiteralPath $script:AuthFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop } catch { Write-Host 'auth.json could not be read; it was not changed.' -ForegroundColor Red;return $false }
    $current=ConvertTo-DevKeySecureText (Read-Host 'Current password' -AsSecureString)
    try { $valid=Test-DevKeyKdfRecord -Password $current -Record $auth } catch { $current=$null;Write-Host 'auth.json is invalid.' -ForegroundColor Red;return $false }
    if (-not $valid) { $current=$null;Write-DevKeyLog -Log access.log -Level AUDIT -Message 'Password change rejected.';Write-Host 'Current password is incorrect.' -ForegroundColor Red;return $false }
    $new=ConvertTo-DevKeySecureText (Read-Host 'New password' -AsSecureString)
    if ($new.Length -lt [int]$script:DevKeyConfig.Security.MinimumPasswordLength) { $current=$null;$new=$null;Write-Host 'Password is too short.' -ForegroundColor Yellow;return $false }
    $confirm=ConvertTo-DevKeySecureText (Read-Host 'Confirm new password' -AsSecureString)
    if ($new -cne $confirm) { $current=$null;$new=$null;$confirm=$null;Write-Host 'Passwords do not match.' -ForegroundColor Yellow;return $false }
    try { Save-DevKeyAuthRecord -Record (New-DevKeyKdfRecord -Password $new) } finally { $current=$null;$new=$null;$confirm=$null }
    Write-DevKeyLog -Log access.log -Level AUDIT -Message 'Password changed.';Write-Host 'Password changed.' -ForegroundColor Green;return $true
}

function New-DevKeyRecoveryKey {
    $path=Join-Path $script:ConfigRoot 'recovery.json'
    if (Test-Path -LiteralPath $path) { Write-Host 'A recovery key is already configured.' -ForegroundColor Yellow;return }
    $bytes=New-Object byte[] 32;$rng=[Security.Cryptography.RandomNumberGenerator]::Create();try{$rng.GetBytes($bytes)}finally{$rng.Dispose()}
    $key=[Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+','-').Replace('/','_')
    (New-DevKeyKdfRecord -Password $key) | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding UTF8
    Write-Host 'Save this one-time key somewhere separate from the USB. It will only be shown now:' -ForegroundColor Yellow
    Write-Host $key -ForegroundColor Cyan
    Write-DevKeyLog -Log access.log -Level AUDIT -Message 'Recovery key created; value omitted from log.'
    [void](Read-Host 'Press ENTER after saving it')
}

function Invoke-DevKeyRecovery {
    $path=Join-Path $script:ConfigRoot 'recovery.json'
    if (-not (Test-Path -LiteralPath $path)) { Write-Host 'No recovery key is configured.' -ForegroundColor Yellow;return $false }
    try { $record=Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop;$key=Read-Host 'Recovery key';$valid=Test-DevKeyKdfRecord -Password $key -Record $record }
    catch { $key=$null;Write-Host 'The recovery key could not be validated.' -ForegroundColor Red;return $false }
    if (-not $valid) { $key=$null;Write-DevKeyLog -Log access.log -Level AUDIT -Message 'Recovery failed.';Write-Host 'Incorrect recovery key.' -ForegroundColor Red;return $false }
    $key=$null
    while($true){
        $secure=Read-Host 'Nueva contrasena (minimo 8 caracteres)' -AsSecureString;$new=ConvertTo-DevKeySecureText $secure
        if($new.Length -lt [int]$script:DevKeyConfig.Security.MinimumPasswordLength){$new=$null;Write-Host 'Contrasena demasiado corta.' -ForegroundColor Yellow;continue}
        $confirm=ConvertTo-DevKeySecureText (Read-Host 'Confirma la nueva contrasena' -AsSecureString)
        if($new -cne $confirm){$new=$null;$confirm=$null;Write-Host 'Las contrasenas no coinciden.' -ForegroundColor Yellow;continue}
        try { Save-DevKeyAuthRecord -Record (New-DevKeyKdfRecord -Password $new) }
        catch { $new=$null;$confirm=$null;Write-Host 'No se pudo guardar auth.json; la clave de recuperacion se conserva.' -ForegroundColor Red;return $false }
        finally { $new=$null;$confirm=$null;$secure=$null }
        break
    }
    Remove-Item -LiteralPath $path -Force -ErrorAction Stop
    Set-DevKeyLockoutState -Failures 0
    Write-DevKeyLog -Log access.log -Level AUDIT -Message 'Recovery completed; recovery key consumed.'
    Write-Host 'Acceso recuperado; la clave de recuperacion se consumio.' -ForegroundColor Green
    return $true
}
