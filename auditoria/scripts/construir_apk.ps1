# Compila el APK de release (M7 / M8) y lo analiza.
# H-04: el código Dart se ofusca (--obfuscate) y los símbolos para leer los stack traces quedan en
# evidencia\apk\<fecha>\simbolos (fuera del repo). Lo que no se usa no llega al APK: Dart compila
# solo lo alcanzable desde main(), R8 quita el código Java/Kotlin y los recursos sin uso, y los
# íconos de Material se recortan a los que la app usa (--tree-shake-icons).
#   -PorArquitectura -> un APK por procesador (más livianos): arm64-v8a (casi todos los teléfonos
#                       actuales), armeabi-v7a (teléfonos antiguos de 32 bits) y x86_64 (emuladores)
#   -SinOfuscar      -> build como antes de la corrección (solo para reproducir el "antes")

param([switch]$PorArquitectura, [switch]$SinOfuscar)

. "$PSScriptRoot\comun.ps1"
$ErrorActionPreference = 'Continue'
$out = Nueva-CarpetaEvidencia 'apk'

Push-Location $Raiz
$argBuild = @('build', 'apk', '--release', '--tree-shake-icons')
if (-not $SinOfuscar) { $argBuild += @('--obfuscate', "--split-debug-info=$out\simbolos") }
if ($PorArquitectura) { $argBuild += '--split-per-abi' }
Titulo ("flutter " + ($argBuild -join ' '))
flutter @argBuild 2>&1 | Tee-Object (Join-Path $out 'build.txt')
Pop-Location

$carpeta = Join-Path $Raiz 'build\app\outputs\flutter-apk'
$apks = if ($PorArquitectura) { Get-ChildItem $carpeta -Filter 'app-*-release.apk' }
        else { Get-ChildItem $carpeta -Filter 'app-release.apk' }
if (-not $apks) { throw 'No se generó el APK; revisa build.txt' }
$apks | ForEach-Object { Copy-Item $_.FullName $out }
Titulo 'APK generados'
$apks | ForEach-Object { '  {0,-34} {1,6:N1} MB' -f $_.Name, ($_.Length / 1MB) }

# Se analiza el principal (arm64 si hay varios).
$apk = ($apks | Where-Object Name -match 'arm64' | Select-Object -First 1)
if (-not $apk) { $apk = $apks | Select-Object -First 1 }
$apk = $apk.FullName
if (Test-Path $ApkAnalyzer) {
    Titulo "apkanalyzer ($(Split-Path $apk -Leaf))"
    & $ApkAnalyzer apk summary $apk 2>&1 | Tee-Object (Join-Path $out 'resumen.txt')
    & $ApkAnalyzer manifest debuggable $apk 2>&1 | ForEach-Object { "  debuggable: $_" }
    & $ApkAnalyzer manifest print $apk 2>&1 | Out-File (Join-Path $out 'manifest_apk.xml') -Encoding utf8
    & $ApkAnalyzer files list $apk 2>&1 | Out-File (Join-Path $out 'archivos_apk.txt') -Encoding utf8
}
Titulo 'Firma'
& (Join-Path $AndroidSdk 'build-tools\36.0.0\apksigner.bat') verify --print-certs $apk 2>&1 |
    Select-String 'Signer #1 certificate DN|SHA-256' | ForEach-Object { '  ' + $_.Line }

Write-Host "`nAPK en: $out"
