# M5 / M6 / M8 — Revisa el AndroidManifest fuente y el fusionado del build de release
# (el fusionado incluye lo que agregan los plugins: permisos, servicios, receivers exportados).
#   -SinCompilar  -> solo el manifiesto fuente, sin correr Gradle

param([switch]$SinCompilar)

. "$PSScriptRoot\comun.ps1"
$ErrorActionPreference = 'Continue'
$out = Nueva-CarpetaEvidencia 'manifiesto'

$fuente = Join-Path $Raiz 'android\app\src\main\AndroidManifest.xml'
$fusionado = Join-Path $Raiz 'build\app\intermediates\merged_manifests\release\processReleaseManifest\AndroidManifest.xml'

if (-not $SinCompilar) {
    Titulo 'Generando manifiesto fusionado de release (Gradle)'
    Push-Location (Join-Path $Raiz 'android')
    .\gradlew.bat :app:processReleaseManifest -q 2>&1 | Out-File (Join-Path $out 'gradle.txt') -Encoding utf8
    Pop-Location
    if (-not (Test-Path $fusionado)) {
        $fusionado = Get-ChildItem (Join-Path $Raiz 'build\app\intermediates') -Recurse -Filter AndroidManifest.xml -ErrorAction SilentlyContinue |
            Where-Object FullName -match 'merged_manifest.*release' | Select-Object -First 1 -ExpandProperty FullName
    }
}

function Analizar([string]$ruta, [string]$etiqueta) {
    if (-not $ruta -or -not (Test-Path $ruta)) { Falta "$etiqueta no disponible"; return }
    Copy-Item $ruta (Join-Path $out "$etiqueta.xml")
    [xml]$m = Get-Content $ruta -Raw
    $ns = @{ a = 'http://schemas.android.com/apk/res/android' }
    $app = $m.manifest.application
    $attr = { param($n, $k) $n.GetAttribute($k, $ns.a) }

    Titulo "$etiqueta — atributos de <application>"
    foreach ($k in 'debuggable', 'allowBackup', 'fullBackupContent', 'dataExtractionRules', 'usesCleartextTraffic', 'networkSecurityConfig') {
        $v = & $attr $app $k
        Write-Host ("  {0,-22} {1}" -f $k, $(if ($v) { $v } else { '(sin definir)' }))
    }

    Titulo "$etiqueta — permisos"
    $m.manifest.'uses-permission' | ForEach-Object {
        $max = & $attr $_ 'maxSdkVersion'
        '  ' + (& $attr $_ 'name') + $(if ($max) { " (maxSdk $max)" })
    } | Sort-Object -Unique | Write-Host

    Titulo "$etiqueta — componentes exportados"
    foreach ($tipo in 'activity', 'activity-alias', 'service', 'receiver', 'provider') {
        $app.$tipo | Where-Object { $_ } | ForEach-Object {
            $exp = & $attr $_ 'exported'
            $perm = & $attr $_ 'permission'
            $filtros = @($_.'intent-filter').Count
            if ($exp -eq 'true' -or ($filtros -gt 0 -and -not $exp)) {
                Write-Host ("  [{0}] {1}  permission={2}" -f $tipo, (& $attr $_ 'name'), $(if ($perm) { $perm } else { 'ninguno' }))
            }
        }
    }
}

Analizar $fuente 'fuente'
Analizar $fusionado 'fusionado_release'

Titulo 'Network Security Config'
$nsc = Get-ChildItem (Join-Path $Raiz 'android\app\src') -Recurse -Filter '*network_security*' -ErrorAction SilentlyContinue
if ($nsc) { $nsc.FullName } else { Falta 'No hay network_security_config.xml' }

Titulo 'Build de release (android/app/build.gradle.kts)'
Select-String -Path (Join-Path $Raiz 'android\app\build.gradle.kts') -Pattern 'isMinifyEnabled|isShrinkResources|proguard|signingConfig|isDebuggable' |
    ForEach-Object { '  L{0}: {1}' -f $_.LineNumber, $_.Line.Trim() }

Titulo 'iOS Info.plist (permisos y ATS)'
Select-String -Path (Join-Path $Raiz 'ios\Runner\Info.plist') -Pattern 'UsageDescription|NSAppTransportSecurity|NSAllowsArbitraryLoads' -Context 0, 1 |
    ForEach-Object { '  ' + $_.Line.Trim() + ' ' + ($_.Context.PostContext -join ' ').Trim() }

Write-Host "`nCopias en: $out"
