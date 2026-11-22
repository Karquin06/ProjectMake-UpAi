# Compila el APK de release (M7 / M8) y lo analiza. Con -PorArquitectura es el comando recomendado:
#   flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
# (más --tree-shake-icons, que recorta la fuente de íconos de Material a los que la app usa).
# H-04: el código Dart se ofusca (--obfuscate) y los símbolos para leer los stack traces quedan en
# build\symbols. Como "flutter clean" borra build\, se guardan además en evidencia\apk\<fecha>\symbols
# y en Documentos\MakeUpAI-simbolos\<versión> (fuera del repo): sin ellos no se pueden leer los
# errores que reporte esa versión. Lo que no se usa no llega al APK: Dart compila solo lo alcanzable
# desde main() y R8 quita el código Java/Kotlin y los recursos sin uso (isMinifyEnabled /
# isShrinkResources en android/app/build.gradle.kts).
#   -PorArquitectura -> un APK por procesador (más livianos): arm64-v8a (casi todos los teléfonos
#                       actuales), armeabi-v7a (teléfonos antiguos de 32 bits) y x86_64 (emuladores);
#                       se copian también a dist\MakeUpAI-<versión>-<arquitectura>.apk para el release
#   -SinOfuscar      -> build como antes de la corrección (solo para reproducir el "antes")

param([switch]$PorArquitectura, [switch]$SinOfuscar)

. "$PSScriptRoot\comun.ps1"
$ErrorActionPreference = 'Continue'
$out = Nueva-CarpetaEvidencia 'apk'
$version = ((Select-String -Path (Join-Path $Raiz 'pubspec.yaml') -Pattern '^version:\s*([^+\s]+)').Matches[0].Groups[1].Value)
$simbolos = Join-Path $Raiz 'build\symbols'

Push-Location $Raiz
# Símbolos limpios: que la carpeta sea solo de esta compilación.
if (Test-Path $simbolos) { Remove-Item -Recurse -Force $simbolos }
$argBuild = @('build', 'apk', '--release')
if ($PorArquitectura) { $argBuild += '--split-per-abi' }
if (-not $SinOfuscar) { $argBuild += @('--obfuscate', '--split-debug-info=build/symbols') }
$argBuild += '--tree-shake-icons'
Titulo ("flutter " + ($argBuild -join ' '))
flutter @argBuild 2>&1 | Tee-Object (Join-Path $out 'build.txt')
Pop-Location

if (-not $SinOfuscar) {
    if (-not (Get-ChildItem $simbolos -Filter '*.symbols' -ErrorAction SilentlyContinue)) {
        throw 'No se generaron los símbolos en build\symbols; revisa build.txt'
    }
    $commit = (git -C $Raiz rev-parse --short HEAD)
    $respaldo = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "MakeUpAI-simbolos\$version`_$commit"
    foreach ($destino in @((Join-Path $out 'symbols'), $respaldo)) {
        New-Item -ItemType Directory -Force $destino | Out-Null
        Copy-Item (Join-Path $simbolos '*') $destino -Recurse -Force
    }
    Titulo 'Símbolos de depuración (guardarlos: sin ellos no se leen los errores de esta versión)'
    Get-ChildItem $simbolos | ForEach-Object { '  {0,-28} {1,6:N1} MB' -f $_.Name, ($_.Length / 1MB) }
    "  Copia en: $respaldo"
}

$carpeta = Join-Path $Raiz 'build\app\outputs\flutter-apk'
$apks = if ($PorArquitectura) { Get-ChildItem $carpeta -Filter 'app-*-release.apk' }
        else { Get-ChildItem $carpeta -Filter 'app-release.apk' }
if (-not $apks) { throw 'No se generó el APK; revisa build.txt' }
$apks | ForEach-Object { Copy-Item $_.FullName $out }
Titulo 'APK generados'
$apks | ForEach-Object { '  {0,-34} {1,6:N1} MB' -f $_.Name, ($_.Length / 1MB) }
if ($PorArquitectura -and -not $SinOfuscar) {
    $dist = Join-Path $Raiz 'dist'
    New-Item -ItemType Directory -Force $dist | Out-Null
    $apks | ForEach-Object {
        $abi = $_.Name -replace '^app-(.+)-release\.apk$', '$1'
        Copy-Item $_.FullName (Join-Path $dist "MakeUpAI-$version-$abi.apk") -Force
    }
    "  Copiados a: $dist (MakeUpAI-$version-<arquitectura>.apk)"
}

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
