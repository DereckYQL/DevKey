@echo off
setlocal

REM ============================================================
REM DEVKEY PORTABLE LAUNCHER
REM Ejecuta el launcher desde la carpeta DevKey\Launcher
REM ============================================================

for %%I in ("%~dp0..\..") do set "USBROOT=%%~fI"
set "SCRIPT=%USBROOT%\DevKey\Launcher\DevKey.ps1"

if not exist "%SCRIPT%" (
    echo.
    echo ========================================
    echo          DEVKEY NO ENCONTRADO
    echo ========================================
    echo.
    echo Ruta esperada:
    echo %SCRIPT%
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -File "%SCRIPT%"

endlocal
exit /b 0
