# Rutas y utilidades compartidas por los scripts de auditoría.
# Se carga con:  . "$PSScriptRoot\comun.ps1"

$ErrorActionPreference = 'Stop'

$Script:Raiz       = (Resolve-Path "$PSScriptRoot\..\..").Path
$Script:Auditoria  = Join-Path $Raiz 'auditoria'
$Script:Evidencia  = Join-Path $Auditoria 'evidencia'
$Script:PaqueteApp = 'com.example.mackeupai'
$Script:AvdNombre  = 'auditoria_api35'
$Script:MobsfImagen = 'opensecurity/mobile-security-framework-mobsf:latest'

$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$Script:AndroidSdk = $sdk
$Script:Adb        = Join-Path $sdk 'platform-tools\adb.exe'
$Script:EmuladorExe = Join-Path $sdk 'emulator\emulator.exe'
$Script:ApkAnalyzer = Join-Path $sdk 'cmdline-tools\latest\bin\apkanalyzer.bat'

# Java de Android Studio para las herramientas del SDK.
if (-not $env:JAVA_HOME -and (Test-Path 'C:\Program Files\Android\Android Studio\jbr')) {
    $env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
}

function Buscar-Herramienta([string]$nombre, [string[]]$rutas) {
    $cmd = Get-Command $nombre -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($r in $rutas) { if (Test-Path $r) { return $r } }
    return $null
}

$Script:Gitleaks = Buscar-Herramienta 'gitleaks' @("$env:LOCALAPPDATA\Microsoft\WinGet\Links\gitleaks.exe")
$Script:Mitmweb  = Buscar-Herramienta 'mitmweb'  @('C:\Program Files\mitmproxy\bin\mitmweb.exe')
$Script:Docker   = Buscar-Herramienta 'docker'   @("$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin\docker.exe",
                                                   'C:\Program Files\Docker\Docker\resources\bin\docker.exe')

# Carpeta de salida con marca de tiempo: evidencia\<tecnica>\<fecha>_<commit>
function Nueva-CarpetaEvidencia([string]$tecnica) {
    $commit = (git -C $Raiz rev-parse --short HEAD 2>$null)
    if (-not $commit) { $commit = 'sin-commit' }
    $sucio = if (git -C $Raiz status --porcelain 2>$null) { '-sucio' } else { '' }
    $nombre = '{0}_{1}{2}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $commit, $sucio
    $dir = Join-Path $Evidencia (Join-Path $tecnica $nombre)
    New-Item -ItemType Directory -Force $dir | Out-Null
    return $dir
}

function Titulo([string]$texto) { Write-Host "`n== $texto ==" -ForegroundColor Magenta }
function Ok([string]$texto)     { Write-Host "  [OK] $texto" -ForegroundColor Green }
function Falta([string]$texto)  { Write-Host "  [!!] $texto" -ForegroundColor Yellow }
