# Convierte auditoria\informe\informe_seguridad.html en el PDF de entrega con Chrome (o Edge) headless.
#   .\auditoria\scripts\generar_informe.ps1                    -> versión APA 7 (Informe_Seguridad_MackeUpAI.pdf)
#   .\auditoria\scripts\generar_informe.ps1 -Version unicesar  -> mismo contenido con el diseño de la guía
#                                                                 (Informe_Seguridad_MackeUpAI_UNICESAR.pdf)
# El contenido se edita solo en informe_seguridad.html; la versión UNICESAR cambia el estilo
# (informe\unicesar\estilo.css) y la portada (informe\unicesar\portada.html).
# Si el PDF está abierto en un visor, ciérralo antes: Windows no deja reemplazarlo.

param([ValidateSet('apa', 'unicesar')][string]$Version = 'apa')

. "$PSScriptRoot\comun.ps1"
$ErrorActionPreference = 'Continue'

$navegador = Buscar-Herramienta 'chrome' @(
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe')
if (-not $navegador) { throw 'No se encontró Chrome ni Edge' }

$html  = Join-Path $Auditoria 'informe\informe_seguridad.html'
$pdf   = Join-Path $Auditoria 'informe\Informe_Seguridad_MackeUpAI.pdf'
$tmp   = Join-Path $env:TEMP "informe_seguridad_${Version}_tmp.pdf"

if ($Version -eq 'unicesar') {
    $dirU = Join-Path $Auditoria 'informe\unicesar'
    $utf8 = New-Object Text.UTF8Encoding $false
    $doc  = [IO.File]::ReadAllText($html, $utf8)
    $css  = [IO.File]::ReadAllText((Join-Path $dirU 'estilo.css'), $utf8)
    $logo = 'file:///' + ((Join-Path $Auditoria 'informe\logo_unicesar.png') -replace '\\', '/')
    $portada = [IO.File]::ReadAllText((Join-Path $dirU 'portada.html'), $utf8).Replace('LOGO_UNICESAR', $logo)
    $doc = [regex]::Replace($doc, '<style>[\s\S]*?</style>', [Text.RegularExpressions.MatchEvaluator] { param($m) "<style>`n$css`n</style>" })
    $doc = [regex]::Replace($doc, '(?s)<!-- =+ PORTADA.*?(?=<!-- =+ RESUMEN)', [Text.RegularExpressions.MatchEvaluator] { param($m) "$portada`n" })
    $html = Join-Path $env:TEMP 'informe_seguridad_unicesar.html'
    [IO.File]::WriteAllText($html, $doc, $utf8)
    $pdf = Join-Path $Auditoria 'informe\Informe_Seguridad_MackeUpAI_UNICESAR.pdf'
}
$url   = 'file:///' + ($html -replace '\\', '/')
$perfil = Join-Path $env:TEMP 'informe_chrome_perfil'

Titulo "Generando $pdf"
# Chrome headless que haya quedado abierto con este perfil bloquearía la generación.
Get-CimInstance Win32_Process -Filter "Name='chrome.exe' OR Name='msedge.exe'" |
    Where-Object { $_.CommandLine -like '*informe_chrome_perfil*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# Se genera en un temporal: así un fallo nunca deja pasar el PDF viejo como si fuera nuevo.
if (Test-Path $tmp) { Remove-Item $tmp -Force }
& $navegador --headless=new --disable-gpu --no-first-run --user-data-dir="$perfil" `
    --no-pdf-header-footer --print-to-pdf="$tmp" $url 2>&1 | Out-Null
Start-Sleep 1
if (-not (Test-Path $tmp)) { throw 'Chrome no generó el PDF' }

# Numeración: APA arriba a la derecha; UNICESAR en el pie (pdf-lib se instala una sola vez, fuera del repo).
$herramientas = Join-Path $env:LOCALAPPDATA 'mackeupai-informe'
if (-not (Test-Path (Join-Path $herramientas 'node_modules\pdf-lib'))) {
    New-Item -ItemType Directory -Force $herramientas | Out-Null
    Push-Location $herramientas
    if (-not (Test-Path package.json)) { npm init -y *> $null }
    npm install pdf-lib@1.17.1 --silent *> $null
    Pop-Location
}
node (Join-Path $PSScriptRoot 'numerar_paginas.mjs') $herramientas $tmp $Version
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron numerar las páginas' }

try { Copy-Item $tmp $pdf -Force -ErrorAction Stop }
catch { throw "No se pudo reemplazar $pdf (¿está abierto en un visor? Ciérralo y vuelve a correr el script)" }
Ok ("PDF listo ({0:N0} KB): {1}" -f ((Get-Item $pdf).Length / 1KB), $pdf)
