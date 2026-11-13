# M1 / M5 / M7 / M8 / M9 / M10 — Levanta MobSF en Docker (http://localhost:8000).
# Usuario y contraseña por defecto de la imagen: mobsf / mobsf (solo local).
#   -Detener  -> apaga el contenedor

param([switch]$Detener)

. "$PSScriptRoot\comun.ps1"
if (-not $Docker) { throw 'Docker no está instalado' }
$ErrorActionPreference = 'Continue'
$nombre = 'mobsf-auditoria'

if ($Detener) { & $Docker rm -f $nombre; return }

& $Docker info --format '{{.ServerVersion}}' *> $null
if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop está apagado: ábrelo y vuelve a intentar' }

if (-not (& $Docker images -q $MobsfImagen)) { & $Docker pull $MobsfImagen }

if (-not (& $Docker ps -q -f "name=$nombre")) {
    & $Docker rm -f $nombre *> $null
    # Solo en 127.0.0.1: MobSF no debe quedar expuesto a la red.
    & $Docker run -d --name $nombre -p 127.0.0.1:8000:8000 $MobsfImagen | Out-Null
}

Write-Host 'Esperando a MobSF...'
do { Start-Sleep 3 } until ((Test-NetConnection 127.0.0.1 -Port 8000 -WarningAction SilentlyContinue).TcpTestSucceeded)
Start-Process 'http://localhost:8000'
Write-Host @"
MobSF listo en http://localhost:8000
  1. Sube el APK de evidencia\apk\<fecha>\app-release.apk
  2. Descarga el reporte PDF y guárdalo en auditoria\evidencia\mobsf\
  3. Apágalo con: .\auditoria\scripts\mobsf.ps1 -Detener
"@
