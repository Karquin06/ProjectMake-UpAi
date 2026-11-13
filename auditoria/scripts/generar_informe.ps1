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
if (-not (Test-Path $pdf)) { throw 'Chrome no generó el PDF' }

# APA 7: número de página arriba a la derecha (pdf-lib se instala una sola vez, fuera del repo).
$herramientas = Join-Path $env:LOCALAPPDATA 'mackeupai-informe'
if (-not (Test-Path (Join-Path $herramientas 'node_modules\pdf-lib'))) {
    New-Item -ItemType Directory -Force $herramientas | Out-Null
    Push-Location $herramientas
    if (-not (Test-Path package.json)) { npm init -y *> $null }
    npm install pdf-lib@1.17.1 --silent *> $null
    Pop-Location
}
node (Join-Path $PSScriptRoot 'numerar_paginas.mjs') $herramientas $pdf
Ok ("PDF listo ({0:N0} KB): {1}" -f ((Get-Item $pdf).Length / 1KB), $pdf)
