function Show-DevKeyGitCredentialStatus {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "       CREDENCIALES GITHUB" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    $Helper = Get-DevKeyGitHelper

    Write-Host "Git Portable : $GitPath"
    Write-Host "Helper       : $Helper"
    Write-Host ""

    if (Test-Path -LiteralPath $GitPath -PathType Leaf) {

        Write-Host "Helper global de este PC:"
        & $GitPath config --global --get credential.helper

        Write-Host ""
        Write-Host "Credenciales almacenadas (git):"
        & cmdkey.exe /list 2>$null | Select-String -Pattern "git:" | ForEach-Object {
            Write-Host ("  " + $_.Line.Trim())
        }
    }
    else {
        Write-Host "[ERROR] Git Portable no encontrado." -ForegroundColor Red
    }

    Write-Host ""
    Pause
}

function Set-DevKeyGitCredentialHelper {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "     CONFIGURAR CREDENTIAL HELPER" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Test-Path -LiteralPath $GitPath -PathType Leaf)) {
        Write-Host "[ERROR] Git Portable no encontrado." -ForegroundColor Red
        Pause
        return
    }

    $Helper = Get-DevKeyGitHelper

    if (-not $Helper) {
        Write-Host "[ERROR] No se encontro un credential helper portable." -ForegroundColor Red
        Write-Host "Coloca Git Portable en Apps\Git."
        Pause
        return
    }

    Write-Host "Helper detectado:"
    Write-Host $Helper
    Write-Host ""

    $Confirm = Read-Host "Aplicarlo a este PC? (S/N)"

    if ($Confirm -ne "S" -and $Confirm -ne "s") {
        return
    }

    & $GitPath config --global credential.helper $Helper

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[OK] Helper configurado." -ForegroundColor Green
        Write-DevKeyLog "Credential helper configurado: $Helper"
    }
    else {
        Write-Host ""
        Write-Host "[ERROR] No se pudo configurar el helper." -ForegroundColor Red
    }

    Write-Host ""
    Pause
}

function Test-DevKeyGitHubAccess {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "        PROBAR ACCESO GITHUB" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Test-Path -LiteralPath $GitPath -PathType Leaf)) {
        Write-Host "[ERROR] Git Portable no encontrado." -ForegroundColor Red
        Pause
        return
    }

    $Url = Read-Host "URL del repositorio (ENTER para usar Hello-World)"

    if ([string]::IsNullOrWhiteSpace($Url)) {
        $Url = "https://github.com/octocat/Hello-World.git"
    }

    Write-Host ""
    Write-Host "Consultando $Url ..."
    Write-Host ""

    $Output = & $GitPath ls-remote $Url HEAD 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Acceso correcto." -ForegroundColor Green
        $Output | ForEach-Object { Write-Host "  $_" }
        Write-DevKeyLog "Prueba de acceso GitHub correcta: $Url"
    }
    else {
        Write-Host "[ERROR] No se pudo acceder al repositorio." -ForegroundColor Red
        $Output | ForEach-Object { Write-Host "  $_" }
        Write-DevKeyLog "Prueba de acceso GitHub fallida: $Url"
    }

    Write-Host ""
    Pause
}

function Clear-DevKeyGitHubCredentials {

    Clear-Host

    Write-Host ""
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host "      BORRAR CREDENCIALES GITHUB" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Se eliminaran las credenciales git de GitHub"
    Write-Host "guardadas en el Administrador de credenciales"
    Write-Host "de Windows para este usuario."
    Write-Host ""
    Write-Host "El password manager de DevKey no se modifica."
    Write-Host ""

    $Confirm = Read-Host "Continuar? (S/N)"

    if ($Confirm -ne "S" -and $Confirm -ne "s") {
        return
    }

    $Targets = @(
        "git:https://github.com"
        "LegacyGeneric:target=git:https://github.com"
        "git:https://github.com/"
    )

    foreach ($Target in $Targets) {
        & cmdkey.exe "/delete:$Target" 2>&1 | Out-Null
    }

    Write-Host ""
    Write-Host "[OK] Credenciales eliminadas (si existian)." -ForegroundColor Green
    Write-DevKeyLog "Credenciales GitHub eliminadas del Administrador de credenciales."
    Write-Host ""
    Pause
}

function Show-GitCredentialMenu {

    while ($true) {

        Clear-Host

        Write-Host ""
        Write-Host "======================================" -ForegroundColor DarkGray
        Write-Host "       DEVKEY GITHUB / CREDENCIALES" -ForegroundColor Cyan
        Write-Host "======================================" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host " [1] Ver estado" -ForegroundColor White
        Write-Host " [2] Configurar credential helper" -ForegroundColor White
        Write-Host " [3] Probar acceso a GitHub" -ForegroundColor White
        Write-Host " [4] Borrar credenciales GitHub" -ForegroundColor White
        Write-Host " [0] Volver" -ForegroundColor DarkGray
        Write-Host ""

        $Option = Read-Host "Selecciona una opcion"

        switch ($Option) {

            "1" { Show-DevKeyGitCredentialStatus }
            "2" { Set-DevKeyGitCredentialHelper }
            "3" { Test-DevKeyGitHubAccess }
            "4" { Clear-DevKeyGitHubCredentials }
            "0" { return }

            default {
                Write-Host ""
                Write-Host "Opcion no valida." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
    }
}
