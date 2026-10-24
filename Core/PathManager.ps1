function Initialize-DevKeyPaths {
    $script:DevKeyRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
    $script:UsbRoot = [IO.Path]::GetFullPath((Split-Path -Parent $script:DevKeyRoot))
    $script:LauncherRoot = Join-Path $script:DevKeyRoot 'Launcher'
    $script:ConfigRoot = Join-Path $script:DevKeyRoot 'Config'
    $script:ModulesRoot = Join-Path $script:DevKeyRoot 'Modules'
    $script:SecurityRoot = Join-Path $script:DevKeyRoot 'Security'
    $script:GuardianRoot = Join-Path $script:DevKeyRoot 'Guardian'
    $script:CoreRoot = Join-Path $script:DevKeyRoot 'Core'
    $script:LogsRoot = Join-Path $script:DevKeyRoot 'Logs'
    $script:AppsRoot = Join-Path $script:UsbRoot 'Apps'
    $script:DataRoot = Join-Path $script:UsbRoot 'Data'
    $script:ProjectsRoot = Join-Path $script:UsbRoot 'Projects'
    $script:LegacyBackupsRoot = Join-Path $script:UsbRoot 'Backups'
    if (Test-Path -LiteralPath $script:LegacyBackupsRoot -PathType Container) { $script:BackupsRoot=$script:LegacyBackupsRoot }
    else { $script:BackupsRoot=Join-Path $script:DevKeyRoot 'Backups' }
    $script:RuntimeRoot = Join-Path $script:DevKeyRoot 'Data\Runtime'
    $script:DevKeySessionId = [guid]::NewGuid().ToString('N')
    $script:KeyFile = Join-Path $script:UsbRoot 'unlock.k3y'
    $script:ConfigFile = Join-Path $script:ConfigRoot 'config.json'
    $script:VersionFile = Join-Path $script:ConfigRoot 'version.json'
    $script:AuthFile = Join-Path $script:ConfigRoot 'auth.json'
    $script:LockoutFile = Join-Path $script:ConfigRoot 'lockout.json'
    $script:ManifestFile = Join-Path $script:ConfigRoot 'manifests\integrity.json'
    $script:KiroData = Join-Path $script:DataRoot 'KiroUser'
    $script:VaultFile = Join-Path $script:DataRoot 'Vault\devkey.kdbx'
    $script:GitConfigFile = Join-Path $script:ConfigRoot 'git.json'
    $script:GitPath = $null
    foreach ($candidate in @((Join-Path $script:AppsRoot 'Git\cmd\git.exe'),(Join-Path $script:AppsRoot 'Git\bin\git.exe'),(Join-Path $script:AppsRoot 'PortableGit\cmd\git.exe'))) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $script:GitPath = $candidate; break }
    }
    if (-not $script:GitPath) { $script:GitPath = Join-Path $script:AppsRoot 'Git\cmd\git.exe' }

    foreach ($folder in @($script:ConfigRoot,$script:LogsRoot,$script:BackupsRoot,(Join-Path $script:ConfigRoot 'manifests'),$script:RuntimeRoot)) {
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) { New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop | Out-Null }
    }
    $script:DevKey = [ordered]@{ DevKeyRoot=$script:DevKeyRoot; UsbRoot=$script:UsbRoot; ConfigRoot=$script:ConfigRoot; ModulesRoot=$script:ModulesRoot; LogsRoot=$script:LogsRoot; AppsRoot=$script:AppsRoot; DataRoot=$script:DataRoot; ProjectsRoot=$script:ProjectsRoot; BackupsRoot=$script:BackupsRoot; KeyFile=$script:KeyFile; AuthFile=$script:AuthFile }

    # Keep the variable names used by preserved legacy modules available.
    foreach ($name in @('DevKeyRoot','USBRoot','ConfigRoot','ModulesRoot','LogsRoot','AppsRoot','DataRoot','ProjectsPath','BackupsRoot','KeyFile','AuthFile','GitPath','KiroData','GitConfigFile','DevKeyLogFile')) {
        $value = switch ($name) {
            'USBRoot' { $script:UsbRoot }
            'ProjectsPath' { $script:ProjectsRoot }
            'DevKeyLogFile' { Join-Path $script:LogsRoot 'devkey.log' }
            default { if ($script:DevKey.Contains($name)) { $script:DevKey[$name] } else { Get-Variable -Name $name -Scope Script -ValueOnly -ErrorAction SilentlyContinue } }
        }
        if ($null -ne $value) { Set-Variable -Name $name -Value $value -Scope Script }
    }
}

function Get-DevKeyDriveIdentity {
    param([string]$Path=$script:UsbRoot)
    try {
        $root=[IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path))
        $drive=New-Object IO.DriveInfo($root)
        if (-not $drive.IsReady) { return $null }
        if (-not ('DevKeyVolume' -as [type])) {
            $source=@'
using System;
using System.Runtime.InteropServices;
public static class DevKeyVolume {
 [DllImport("kernel32.dll", CharSet=CharSet.Auto, SetLastError=true)]
 public static extern bool GetVolumeInformation(string root, System.Text.StringBuilder name, int nameSize, out uint serial, out uint maxComponent, out uint flags, System.Text.StringBuilder fs, int fsSize);
}
'@
            Add-Type -TypeDefinition $source -ErrorAction Stop | Out-Null
        }
        $name=New-Object Text.StringBuilder 261; $fs=New-Object Text.StringBuilder 261; [uint32]$serial=0; [uint32]$max=0; [uint32]$flags=0
        if (-not [DevKeyVolume]::GetVolumeInformation($root,$name,260,[ref]$serial,[ref]$max,[ref]$flags,$fs,260)) { return $null }
        return [pscustomobject]@{ Root=$root; Serial=('{0:X8}' -f $serial); Label=$drive.VolumeLabel; FileSystem=$drive.DriveFormat }
    } catch { return $null }
}
