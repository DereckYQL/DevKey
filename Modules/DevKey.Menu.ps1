function Write-DevKeyPanel {
    param([string]$Title,[string[]]$Rows)
    $width=54
    try {
        if($Host.UI.RawUI.WindowSize.Width -ge 30){$width=[Math]::Min($width,$Host.UI.RawUI.WindowSize.Width-4)}
    } catch { }
    # UTF-8 alone does not guarantee a font; ASCII is the conservative fallback.
    $unicode=$false
    try {$unicode=([Console]::OutputEncoding.CodePage -eq 65001 -and -not [Console]::IsOutputRedirected)} catch { }
    $horizontal='-';$vertical='|';$tl='+';$tr='+';$bl='+';$br='+';$ml='+';$mr='+'
    if($unicode){$horizontal='═';$vertical='║';$tl='╔';$tr='╗';$bl='╚';$br='╝';$ml='╠';$mr='╣'}
    Write-Host ('  '+$tl+($horizontal*$width)+$tr) -ForegroundColor Blue
    $allRows=@($Title,'PORTABLE DEV ENVIRONMENT')
    foreach($row in $allRows){
        $text=$row
        if($text.Length -gt $width-2){$text=$text.Substring(0,$width-2)}
        $left=[int][Math]::Floor(($width-$text.Length)/2)
        Write-Host ('  '+$vertical+(' '*$left)+$text+(' '*($width-$left-$text.Length))+$vertical) -ForegroundColor Cyan
    }
    Write-Host ('  '+$ml+($horizontal*$width)+$mr) -ForegroundColor Blue
    foreach($row in @('')+$Rows+@('')){
        $text='  '+$row
        if($text.Length -gt $width){$text=$text.Substring(0,$width)}
        Write-Host ('  '+$vertical+$text.PadRight($width)+$vertical) -ForegroundColor Gray
    }
    Write-Host ('  '+$bl+($horizontal*$width)+$br) -ForegroundColor Blue
}

function Show-DevKeyMainMenu {
    param([string]$Version,[string]$Build,[string]$Channel,[string]$USBRoot,[string]$Profile,[string]$ProjectsPath)
    Write-DevKeyPanel -Title 'DEVKEY' -Rows @(
        '[1] Abrir software','[2] GitHub','[3] Projects','[4] Estado del sistema',
        '[5] Mantenimiento','[6] Seguridad / DevKey Vault','[7] Información del sistema','','[0] Salir'
    )
}

function Show-DevKeyFrame {
    try {$Host.UI.RawUI.BackgroundColor='DarkBlue';$Host.UI.RawUI.ForegroundColor='Gray'} catch { }
    Clear-Host
    Show-DevKeyMainMenu
    $status=Get-DevKeyDisplayStatus
    $tokenText=if($status.Token){'OK'}else{'ERROR'}
    $authText=if($status.Auth){'OK'}else{'PENDIENTE'}
    Write-Host ('  Versión {0} | {1}' -f (Get-DevKeyVersion),$script:DevKeyRoot) -ForegroundColor Cyan
    Write-Host ('  Token: {0} | Integridad: {1} | Autenticación: {2}' -f $tokenText,$status.Integrity,$authText) -ForegroundColor $(if(-not $status.Token -or $status.Integrity -in @('ERROR','INVALID')){'Red'}else{'Yellow'})
}

function Show-DevKeyStatus {
    Clear-Host
    Write-DevKeyPanel -Title 'ESTADO DEL SISTEMA' -Rows @()
    Get-DevKeyDashboard | Format-Table -AutoSize
    Pause-DevKey
}
