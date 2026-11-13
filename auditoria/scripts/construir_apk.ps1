# M7 / M8 — Compila el APK de release para analizarlo con MobSF y apkanalyzer.
# H-04: por defecto el código Dart se ofusca (--obfuscate) y los símbolos para leer
# los stack traces quedan en evidencia\apk\<fecha>\simbolos (fuera del repo).
#   -SinOfuscar -> build como antes de la corrección (solo para reproducir el "antes")

param([switch]$SinOfuscar)

. "$PSScriptRoot\comun.ps1"
$ErrorActionPreference = 'Continue'
$out = Nueva-CarpetaEvidencia 'apk'

Push-Location $Raiz
$argBuild = @('build', 'apk', '--release')
if (-not $SinOfuscar) { $argBuild += @('--obfuscate', "--split-debug-info=$out\simbolos") }
Titulo ("flutter " + ($argBuild -join ' '))
flutter @argBuild 2>&1 | Tee-Object (Join-Path $out 'build.txt')
Pop-Location

$apk = Join-Path $Raiz 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) { throw 'No se generó el APK; revisa build.txt' }
Copy-Item $apk $out

if (Test-Path $ApkAnalyzer) {
    Titulo 'apkanalyzer'
    & $ApkAnalyzer apk summary $apk 2>&1 | Tee-Object (Join-Path $out 'resumen.txt')
    & $ApkAnalyzer manifest debuggable $apk 2>&1 | ForEach-Object { "  debuggable: $_" }
    & $ApkAnalyzer manifest print $apk 2>&1 | Out-File (Join-Path $out 'manifest_apk.xml') -Encoding utf8
    & $ApkAnalyzer files list $apk 2>&1 | Out-File (Join-Path $out 'archivos_apk.txt') -Encoding utf8
}
Titulo 'Firma'
& (Join-Path $AndroidSdk 'build-tools\36.0.0\apksigner.bat') verify --print-certs $apk 2>&1 |
    Select-String 'Signer #1 certificate DN|SHA-256' | ForEach-Object { '  ' + $_.Line }

Write-Host "`nAPK: $out\app-release.apk  ->  súbelo en MobSF (mobsf.ps1)"
