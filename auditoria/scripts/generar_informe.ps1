# Convierte auditoria\informe\informe_seguridad.html en el PDF de entrega con Chrome (o Edge) headless.
#   .\auditoria\scripts\generar_informe.ps1

. "$PSScriptRoot\comun.ps1"
$ErrorActionPreference = 'Continue'

$navegador = Buscar-Herramienta 'chrome' @(
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe')
if (-not $navegador) { throw 'No se encontró Chrome ni Edge' }

$html = Join-Path $Auditoria 'informe\informe_seguridad.html'
$pdf  = Join-Path $Auditoria 'informe\Informe_Seguridad_MackeUpAI.pdf'
$url  = 'file:///' + ($html -replace '\\', '/')
$perfil = Join-Path $env:TEMP 'informe_chrome_perfil'

Titulo "Generando $pdf"
& $navegador --headless=new --disable-gpu --no-first-run --user-data-dir="$perfil" `
    --no-pdf-header-footer --print-to-pdf="$pdf" $url 2>&1 | Out-Null
Start-Sleep 1
if (Test-Path $pdf) { Ok ("PDF listo ({0:N0} KB): {1}" -f ((Get-Item $pdf).Length / 1KB), $pdf) }
else { throw 'Chrome no generó el PDF' }
