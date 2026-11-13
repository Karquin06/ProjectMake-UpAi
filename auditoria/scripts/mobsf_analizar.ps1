# Analiza un APK con MobSF por su API REST y guarda el reporte (JSON y PDF) y el puntaje.
#   .\auditoria\scripts\mobsf_analizar.ps1 -Apk <ruta.apk> -Etiqueta antes
# MobSF debe estar corriendo (.\auditoria\scripts\mobsf.ps1).

param([Parameter(Mandatory)][string]$Apk, [string]$Etiqueta = 'apk')

. "$PSScriptRoot\comun.ps1"
$ErrorActionPreference = 'Stop'
$api = 'http://127.0.0.1:8000/api/v1'
$llave = (Get-Content (Join-Path $env:LOCALAPPDATA 'mackeupai-informe\mobsf_api_key.txt') -Raw).Trim()
$out = Nueva-CarpetaEvidencia "mobsf_$Etiqueta"
$Apk = (Resolve-Path $Apk).Path

Titulo "Subiendo $Apk"
$subida = curl.exe -s -S -F "file=@$Apk" -H "Authorization: $llave" "$api/upload" | ConvertFrom-Json
if (-not $subida.hash) { throw "La subida falló: $subida" }
Ok "hash $($subida.hash)"

Titulo 'Escaneando (puede tardar varios minutos)'
$null = curl.exe -s -S -X POST --max-time 1800 -H "Authorization: $llave" --data "hash=$($subida.hash)" "$api/scan"

curl.exe -s -S -X POST -H "Authorization: $llave" --data "hash=$($subida.hash)" "$api/report_json" -o (Join-Path $out 'reporte.json')
curl.exe -s -S -X POST -H "Authorization: $llave" --data "hash=$($subida.hash)" "$api/scorecard" -o (Join-Path $out 'puntaje.json')
curl.exe -s -S -X POST -H "Authorization: $llave" --data "hash=$($subida.hash)" "$api/download_pdf" -o (Join-Path $out 'reporte_mobsf.pdf')

$p = Get-Content (Join-Path $out 'puntaje.json') -Raw -Encoding utf8 | ConvertFrom-Json
Titulo "Resultado ($Etiqueta)"
Write-Host ("  Puntaje de seguridad: {0}/100" -f $p.security_score)
foreach ($nivel in 'high', 'warning', 'info', 'secure', 'hotspot') {
    $items = @($p.$nivel)
    Write-Host ("  {0,-8} {1}" -f $nivel, $items.Count)
    if ($nivel -in 'high', 'warning') { $items | ForEach-Object { Write-Host "     - $($_.title)" } }
}
Write-Host "`nReportes en: $out"
