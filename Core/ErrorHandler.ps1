function Protect-DevKeyLogText {
    param([string]$Text)
    $safe=([string]$Text -replace '[\r\n\t]',' ')
    $safe=$safe -replace '(?i)(https?://)[^/@\s]+:[^/@\s]+@','$1[REDACTED]@'
    $safe=$safe -replace '(?i)(https?://)[^/@\s]+@','$1[REDACTED]@'
    $safe=$safe -replace '(?i)(Bearer\s+)[A-Za-z0-9._~+/-]+=*','$1[REDACTED]'
    $safe=$safe -replace '(?i)(gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})','[REDACTED_TOKEN]'
    $safe=$safe -replace '(?i)(token|password|secret)(\s*[=:]\s*)[^\s,;]+','$1$2[REDACTED]'
    return $safe
}
function Write-DevKeyLog {
    param([Parameter(Mandatory=$true)][string]$Message,[ValidateSet('INFO','WARN','ERROR','AUDIT')][string]$Level='INFO',[string]$Log='error.log')
    if (-not $script:DevKeyConfig -or -not $script:DevKeyConfig.Logging.Enabled) { return }
    if ($Log -eq 'guardian.log' -and -not [bool]$script:DevKeyConfig.Guardian.LogEvents) { return }
    if ($Log -notmatch '^[A-Za-z0-9_-]+\.log$') { return }
    try {
        $path=Join-Path $script:LogsRoot $Log
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $item=Get-Item -LiteralPath $path
            $max=[Math]::Max(1,[int]$script:DevKeyConfig.Logging.MaxFileSizeMB)*1MB
            if ($item.Length -ge $max) { Move-Item -LiteralPath $path -Destination ($path+'.'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.old') -ErrorAction Stop }
        }
        $safe=Protect-DevKeyLogText -Text $Message
        Add-Content -LiteralPath $path -Value ('{0:o} [{1}] {2}' -f (Get-Date),$Level,$safe) -Encoding UTF8 -ErrorAction Stop
        $cutoff=(Get-Date).AddDays(-[Math]::Max(1,[int]$script:DevKeyConfig.Logging.RetentionDays))
        Get-ChildItem -LiteralPath $script:LogsRoot -Filter '*.log.*.old' -File -ErrorAction SilentlyContinue | Where-Object LastWriteTime -lt $cutoff | Remove-Item -Force -ErrorAction SilentlyContinue
    } catch { }
}
function Invoke-DevKeyLogged {
    param([Parameter(Mandatory=$true)][string]$Context,[Parameter(Mandatory=$true)][scriptblock]$Action)
    try { & $Action } catch { Write-DevKeyLog -Level ERROR -Message ($Context+': '+$_.Exception.GetType().Name) -Log 'error.log';Write-Host "Error en $Context. Consulta Logs\error.log." -ForegroundColor Red;return $null }
}
