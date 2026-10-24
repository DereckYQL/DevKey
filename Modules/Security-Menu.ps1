$script:DevKeyVaultRoot = Join-Path $USBRoot "Data\Vault"
$script:DevKeyVaultFile = Join-Path $script:DevKeyVaultRoot "devkey.kdbx"

function Get-DevKeyKeePassPath {

    $Candidates = @(
        (Join-Path $USBRoot "Apps\KeePass\KeePass.exe")
        (Join-Path $USBRoot "Apps\KeePassXC\KeePassXC.exe")
        (Join-Path $USBRoot "Apps\KeePassXC\keepassxc.exe")
    )

    foreach ($Candidate in $Candidates) {
        if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
            return $Candidate
        }
    }

    return $null
}

function Get-DevKeyKeePassCliPath {

    $Candidates = @(
        (Join-Path $USBRoot "Apps\KeePassXC\keepassxc-cli.exe")
        (Join-Path $USBRoot "Apps\KeePass\keepassxc-cli.exe")
    )

    foreach ($Candidate in $Candidates) {
        if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
            return $Candidate
        }
    }

    return $null
}

function Show-DevKeyVaultStatus {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "          DEVKEY VAULT" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    $KeePass = Get-DevKeyKeePassPath
    $KeePassCli = Get-DevKeyKeePassCliPath

    if ($KeePass) {
        Write-Host "[OK] KeePass detectado" -ForegroundColor Green
        Write-Host "     $KeePass"
    }
    else {
        Write-Host "[--] KeePass no encontrado" -ForegroundColor Yellow
        Write-Host "     Coloca KeePass portable en Apps\KeePass\KeePass.exe"
    }

    if ($KeePassCli) {
        Write-Host "[OK] keepassxc-cli detectado" -ForegroundColor Green
        Write-Host "     $KeePassCli"
    }

    Write-Host ""
    Write-Host "Carpeta Vault:"
    Write-Host "  $script:DevKeyVaultRoot"
    Write-Host ""

    if (Test-Path -LiteralPath $script:DevKeyVaultFile -PathType Leaf) {

        $Vault = Get-Item -LiteralPath $script:DevKeyVaultFile
        $SizeKB = [math]::Round($Vault.Length / 1KB, 2)

        Write-Host "[OK] Boveda:" -ForegroundColor Green
        Write-Host "     $($Vault.FullName)"
        Write-Host "     $SizeKB KB"
        Write-Host "     Modificada: $($Vault.LastWriteTime)"
    }
    else {
        Write-Host "[--] Boveda no creada." -ForegroundColor Yellow
        Write-Host "     Usa [2] Crear boveda."
    }

    Write-Host ""
    Pause
}

function New-DevKeyVault {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "          CREAR BOVEDA" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Test-Path -LiteralPath $script:DevKeyVaultRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $script:DevKeyVaultRoot -Force | Out-Null
    }

    if (Test-Path -LiteralPath $script:DevKeyVaultFile -PathType Leaf) {

        Write-Host "[--] La boveda ya existe:" -ForegroundColor Yellow
        Write-Host "    $script:DevKeyVaultFile"
        Write-Host ""
        Pause
        return
    }

    $KeePass = Get-DevKeyKeePassPath

    if (-not $KeePass) {

        $Readme = Join-Path $script:DevKeyVaultRoot "LEEME-VAULT.txt"

        @(
            "DEVKEY VAULT",
            "",
            "No se encontro KeePass portable.",
            "",
            "Para habilitar la boveda:",
            "1. Descarga KeePass 2.x portable (o KeePassXC portable).",
            "2. Descomprime en: $USBRoot\Apps\KeePass",
            "3. Verifica que exista: $USBRoot\Apps\KeePass\KeePass.exe",
            "4. Vuelve a DevKey > Seguridad > Crear boveda.",
            "",
            "La boveda se guardara en:",
            "$script:DevKeyVaultFile",
            "",
            "Usa una contrasena maestra fuerte y no la guardes en el mismo USB."
        ) | Set-Content -LiteralPath $Readme -Encoding UTF8

        Write-Host "[ERROR] KeePass no encontrado." -ForegroundColor Red
        Write-Host ""
        Write-Host "Se creo un archivo de instrucciones:"
        Write-Host $Readme
        Write-Host ""
        Pause
        return
    }

    Write-Host "Se abrira KeePass para crear la boveda."
    Write-Host ""
    Write-Host "Ruta:"
    Write-Host "  $script:DevKeyVaultFile"
    Write-Host ""
    Write-Host "Guarda la base de datos exactamente en esa ruta."
    Write-Host ""

    $Confirm = Read-Host "Continuar? (S/N)"

    if ($Confirm -ne "S" -and $Confirm -ne "s") {
        return
    }

    try {

        Start-Process `
            -FilePath $KeePass `
            -ArgumentList "`"$script:DevKeyVaultFile`"" `
            -WorkingDirectory (Split-Path -Parent $KeePass)

        Write-DevKeyLog "KeePass abierto para crear boveda: $script:DevKeyVaultFile"
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] No se pudo abrir KeePass." -ForegroundColor Red
        Write-Host $_.Exception.Message
    }

    Write-Host ""
    Pause
}

function Open-DevKeyVault {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "          ABRIR BOVEDA" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Test-Path -LiteralPath $script:DevKeyVaultFile -PathType Leaf)) {

        Write-Host "[--] La boveda no existe." -ForegroundColor Yellow
        Write-Host ""

        $Create = Read-Host "Crear boveda ahora? (S/N)"

        if ($Create -eq "S" -or $Create -eq "s") {
            New-DevKeyVault
        }

        return
    }

    $KeePass = Get-DevKeyKeePassPath
    $KeePassCli = Get-DevKeyKeePassCliPath

    if ($KeePass) {

        try {

            Start-Process `
                -FilePath $KeePass `
                -ArgumentList "`"$script:DevKeyVaultFile`"" `
                -WorkingDirectory (Split-Path -Parent $KeePass)

            Write-Host "[OK] KeePass iniciado." -ForegroundColor Green
            Write-DevKeyLog "Boveda abierta: $script:DevKeyVaultFile"
        }
        catch {
            Write-Host "[ERROR] No se pudo abrir KeePass." -ForegroundColor Red
            Write-Host $_.Exception.Message
        }
    }
    else {
        Write-Host "[--] KeePass GUI no encontrado." -ForegroundColor Yellow

        if ($KeePassCli) {
            Write-Host "keepassxc-cli disponible:"
            Write-Host "  $KeePassCli"
            Write-Host ""
            Write-Host "Puedes listar entradas con:"
            Write-Host "  & `"$KeePassCli`" ls `"$script:DevKeyVaultFile`""
        }
        else {
            Write-Host "Coloca KeePass portable en Apps\KeePass\KeePass.exe"
        }
    }

    Write-Host ""
    Pause
}

function New-DevKeyStrongPassword {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "       GENERAR CONTRASENA FUERTE" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    $Length = 24
    $Chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%&*+-=?"

    $Rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $Bytes = New-Object byte[] ($Length * 4)
    $Rng.GetBytes($Bytes)
    $Rng.Dispose()

    $Builder = New-Object System.Text.StringBuilder

    for ($Index = 0; $Index -lt $Bytes.Length; $Index++) {

        if ($Builder.Length -ge $Length) {
            break
        }

        $Value = [int]$Bytes[$Index]
        $Limit = 256 - (256 % $Chars.Length)

        if ($Value -lt $Limit) {
            [void]$Builder.Append($Chars[$Value % $Chars.Length])
        }
    }

    $Password = $Builder.ToString()

    Set-Clipboard -Value $Password

    try {
        Start-Job -ScriptBlock {
            Start-Sleep -Seconds 45
            Set-Clipboard -Value $null
        } | Out-Null
    }
    catch {
        # Si el job falla, la contrasena permanece en el portapapeles
    }

    Write-Host "Contrasena generada:"
    Write-Host ""
    Write-Host "  $Password" -ForegroundColor Green
    Write-Host ""
    Write-Host "Copiada al portapapeles."
    Write-Host "Se intentara borrar en 45 segundos."
    Write-Host ""
    Write-Host "Guardala en tu boveda KeePass."
    Write-Host ""

    Write-DevKeyLog "Contrasena fuerte generada y copiada al portapapeles."

    Pause
}

function Show-DevKeySecurityInfo {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "        INFORMACION DE SEGURIDAD" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "Capas de seguridad de DevKey:" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  1. unlock.k3y"
    Write-Host "     Token fisico verificado por SHA-256 al iniciar."
    Write-Host "     Archivo: $KeyFile"
    Write-Host ""
    Write-Host "  2. auth.json"
    Write-Host "     Contrasena de acceso DevKey con PBKDF2-SHA256."
    Write-Host "     Archivo: $AuthFile"
    Write-Host ""
    Write-Host "  3. Boveda KeePass"
    Write-Host "     Contrasenas de proyectos y servicios."
    Write-Host "     Archivo: $script:DevKeyVaultFile"
    Write-Host ""
    Write-Host "  4. Manifest de integridad"
    Write-Host "     SHA-256 de los archivos de DevKey."
    Write-Host "     Archivo: $(Join-Path $ConfigRoot 'integrity.json')"
    Write-Host ""
    Write-Host "Recomendaciones:" -ForegroundColor Magenta
    Write-Host "  - No guardes la contrasena maestra de KeePass en la USB."
    Write-Host "  - Usa una contrasena distinta para DevKey y para KeePass."
    Write-Host "  - Si pierdes unlock.k3y, actualiza ExpectedHash o restaura el archivo."
    Write-Host "  - Haz backups de la boveda en un lugar cifrado."
    Write-Host ""

    Pause
}

function Show-DevKeySecurityMenu {

    while ($true) {

        Clear-Host

        Write-Host ""
        Write-Host "======================================" -ForegroundColor DarkGray
        Write-Host "      SEGURIDAD / DEVKEY VAULT" -ForegroundColor Cyan
        Write-Host "======================================" -ForegroundColor DarkGray
        Write-Host ""

        $KeePass = Get-DevKeyKeePassPath

        if ($KeePass) {
            Write-Host "[OK] KeePass" -ForegroundColor Green
        }
        else {
            Write-Host "[--] KeePass no encontrado" -ForegroundColor Yellow
        }

        if (Test-Path -LiteralPath $script:DevKeyVaultFile -PathType Leaf) {
            Write-Host "[OK] Boveda" -ForegroundColor Green
        }
        else {
            Write-Host "[--] Boveda no creada" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host " [1] Abrir boveda" -ForegroundColor White
        Write-Host " [2] Crear boveda" -ForegroundColor White
        Write-Host " [3] Estado de la boveda" -ForegroundColor White
        Write-Host " [4] Generar contrasena fuerte" -ForegroundColor White
        Write-Host " [5] Abrir carpeta Vault" -ForegroundColor White
        Write-Host " [6] Informacion de seguridad" -ForegroundColor White
        Write-Host " [0] Volver" -ForegroundColor DarkGray
        Write-Host ""

        $Option = Read-Host "Selecciona una opcion"

        switch ($Option) {

            "1" { Open-DevKeyVault }
            "2" { New-DevKeyVault }
            "3" { Show-DevKeyVaultStatus }
            "4" { New-DevKeyStrongPassword }

            "5" {
                if (-not (Test-Path -LiteralPath $script:DevKeyVaultRoot)) {
                    New-Item -ItemType Directory -Path $script:DevKeyVaultRoot -Force | Out-Null
                }

                Start-Process -FilePath "explorer.exe" -ArgumentList "`"$script:DevKeyVaultRoot`""
            }

            "6" { Show-DevKeySecurityInfo }
            "0" { return }

            default {
                Write-Host ""
                Write-Host "Opcion no valida." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
    }
}

Show-DevKeySecurityMenu
