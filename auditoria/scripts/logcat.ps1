# M9 — Captura los logs de la app mientras se usa (login, selfie, perfil...).
# Busca tokens, correos o contraseñas impresos con print/debugPrint/Log.
#   -Release  -> instala el APK de release antes (lo que importa para la nota es release)

param([switch]$Release)

. "$PSScriptRoot\comun.ps1"
$ErrorActionPreference = 'Continue'
if (-not ((& $Adb devices) -match '\sdevice$')) { throw 'No hay dispositivo: corre entorno.ps1 -Emulador' }

if ($Release) {
    $apk = Join-Path $Raiz 'build\app\outputs\flutter-apk\app-release.apk'
    if (-not (Test-Path $apk)) { throw 'Primero corre construir_apk.ps1' }
    & $Adb install -r $apk
}

$out = Nueva-CarpetaEvidencia 'logcat'
$archivo = Join-Path $out 'logcat.txt'

& $Adb logcat -c
& $Adb shell monkey -p $PaqueteApp -c android.intent.category.LAUNCHER 1 *> $null
Start-Sleep 2
$appPid = (& $Adb shell pidof $PaqueteApp).Trim()
if (-not $appPid) { throw "La app $PaqueteApp no está corriendo" }

Write-Host "Capturando logs del proceso $appPid. Usa la app y presiona Ctrl+C para terminar."
try { & $Adb logcat --pid=$appPid -v time | Tee-Object $archivo }
finally {
    Titulo 'Posibles fugas'
    $patron = 'token|bearer|password|contrase|secret|apikey|api_key|AIza|eyJ[A-Za-z0-9_-]{10,}|@[A-Za-z0-9.-]+\.[a-z]{2,}'
    Select-String -Path $archivo -Pattern $patron -AllMatches |
        Tee-Object -Variable sospechas | ForEach-Object { '  L{0}: {1}' -f $_.LineNumber, $_.Line.Substring(0, [Math]::Min(160, $_.Line.Length)) }
    Write-Host ("`n{0} línea(s) sospechosas. Log completo: {1}" -f @($sospechas).Count, $archivo)
}
