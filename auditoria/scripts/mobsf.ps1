# M1 / M5 / M7 / M8 / M9 / M10 — Levanta MobSF en Docker (http://localhost:8000).
# Usuario y contraseña por defecto de la imagen: mobsf / mobsf (solo local).
#   -Detener  -> apaga el contenedor

param([switch]$Detener)

. "$PSScriptRoot\comun.ps1"
if (-not $Docker) { throw 'Docker no está instalado' }
$ErrorActionPreference = 'Continue'
$nombre = 'mobsf-auditoria'

if ($Detener) { & $Docker rm -f $nombre; return }

& $Docker version --format '{{.Server.Version}}' *> $null
if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop está apagado: ábrelo y vuelve a intentar (si falla, ver README)' }

if (-not (& $Docker images -q $MobsfImagen)) { & $Docker pull $MobsfImagen }

# Llave de la API REST de MobSF: local, fuera del repositorio (la usa mobsf_analizar.ps1).
$archivoLlave = Join-Path $env:LOCALAPPDATA 'mackeupai-informe\mobsf_api_key.txt'
if (-not (Test-Path $archivoLlave)) {
    New-Item -ItemType Directory -Force (Split-Path $archivoLlave) | Out-Null
    $b = New-Object byte[] 32; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
    -join ($b | ForEach-Object { $_.ToString('x2') }) | Set-Content $archivoLlave -Encoding ascii -NoNewline
}
$llave = (Get-Content $archivoLlave -Raw).Trim()

if (-not (& $Docker ps -q -f "name=$nombre")) {
    & $Docker rm -f $nombre *> $null
    # Solo en 127.0.0.1: MobSF no debe quedar expuesto a la red.
    & $Docker run -d --name $nombre -p 127.0.0.1:8000:8000 -e "MOBSF_API_KEY=$llave" $MobsfImagen | Out-Null
}

Write-Host 'Esperando a MobSF...'
$fin = (Get-Date).AddMinutes(5)
do {
    Start-Sleep 5
    try { $listo = (Invoke-WebRequest 'http://127.0.0.1:8000/login/' -UseBasicParsing -TimeoutSec 5).StatusCode -eq 200 } catch { $listo = $false }
} until ($listo -or (Get-Date) -gt $fin)
if (-not $listo) { throw "MobSF no respondió; revisa: docker logs $nombre" }
Write-Host @"
MobSF listo en http://localhost:8000 (usuario y contraseña: mobsf / mobsf)
  Analizar un APK automáticamente:  .\auditoria\scripts\mobsf_analizar.ps1 -Apk <ruta.apk> -Etiqueta antes
  Apagarlo:                         .\auditoria\scripts\mobsf.ps1 -Detener
"@
