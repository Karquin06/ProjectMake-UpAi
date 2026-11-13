# M5 — Intercepta el tráfico del emulador con mitmweb (interfaz en http://127.0.0.1:8081).
#   -InstalarCertificado  -> instala la CA de mitmproxy como certificado de SISTEMA en el emulador
#                            (requiere la imagen Google APIs y arrancar con -writable-system)
#   -SinCertificado       -> prueba negativa: proxy activo pero sin CA confiable (la app debe fallar)
#   -Quitar               -> quita el proxy del emulador

param([switch]$InstalarCertificado, [switch]$SinCertificado, [switch]$Quitar)

. "$PSScriptRoot\comun.ps1"
$ErrorActionPreference = 'Continue'
if (-not $Mitmweb) { throw 'mitmproxy no está instalado (winget install mitmproxy.mitmproxy)' }
if (-not ((& $Adb devices) -match 'emulator-\d+\s+device')) { throw 'Arranca el emulador: entorno.ps1 -Emulador' }

if ($Quitar) { & $Adb shell settings put global http_proxy :0; Ok 'Proxy quitado'; return }

$ca = Join-Path $env:USERPROFILE '.mitmproxy\mitmproxy-ca-cert.cer'
if (-not (Test-Path $ca)) {
    # La CA se genera la primera vez que arranca mitmproxy.
    $p = Start-Process (Split-Path $Mitmweb | Join-Path -ChildPath 'mitmdump.exe') -PassThru -WindowStyle Hidden
    Start-Sleep 4; Stop-Process $p -Force
}

if ($InstalarCertificado) {
    Titulo 'Instalando CA de mitmproxy como certificado de sistema'
    $pem = Join-Path $env:USERPROFILE '.mitmproxy\mitmproxy-ca-cert.pem'
    # Nombre = hash subject_hash_old de OpenSSL (calculado con el openssl de Git).
    $openssl = Buscar-Herramienta 'openssl' @('C:\Program Files\Git\usr\bin\openssl.exe', 'C:\Program Files\Git\mingw64\bin\openssl.exe')
    $hash = (& $openssl x509 -inform PEM -subject_hash_old -in $pem -noout).Trim()
    & $Adb root; Start-Sleep 2
    & $Adb remount
    & $Adb push $pem "/system/etc/security/cacerts/$hash.0"
    & $Adb shell chmod 644 "/system/etc/security/cacerts/$hash.0"
    & $Adb reboot; & $Adb wait-for-device
    do { Start-Sleep 3 } until ((& $Adb shell getprop sys.boot_completed 2>$null) -match '1')
    Ok "CA instalada ($hash.0)"
}

# 10.0.2.2 es el localhost del PC visto desde el emulador.
& $Adb shell settings put global http_proxy 10.0.2.2:8080
Ok 'Proxy del emulador -> 10.0.2.2:8080'

$out = Nueva-CarpetaEvidencia $(if ($SinCertificado) { 'mitmproxy_sin_ca' } else { 'mitmproxy' })
Write-Host @"

mitmweb abre en http://127.0.0.1:8081 . Usa la app (login, selfie, armario...).
Al terminar: Ctrl+C aquí y luego  .\auditoria\scripts\mitmproxy.ps1 -Quitar
Flujos guardados en: $out\flujos.mitm   (pueden contener tokens: NO subir)
"@
& $Mitmweb --listen-port 8080 --web-port 8081 --save-stream-file (Join-Path $out 'flujos.mitm')
