# Comprueba que el ambiente de auditoría está listo.
#   .\auditoria\scripts\entorno.ps1            -> solo comprueba
#   .\auditoria\scripts\entorno.ps1 -Emulador  -> además arranca el emulador y espera a que inicie
param([switch]$Emulador)

. "$PSScriptRoot\comun.ps1"
$ErrorActionPreference = 'Continue'

Titulo 'Herramientas'
$items = [ordered]@{
    'git'        = (Get-Command git -ErrorAction SilentlyContinue).Source
    'flutter'    = (Get-Command flutter -ErrorAction SilentlyContinue).Source
    'npm'        = (Get-Command npm -ErrorAction SilentlyContinue).Source
    'gitleaks'   = $Gitleaks
    'mitmweb'    = $Mitmweb
    'docker'     = $Docker
    'adb'        = $(if (Test-Path $Adb) { $Adb })
    'emulator'   = $(if (Test-Path $EmuladorExe) { $EmuladorExe })
    'apkanalyzer'= $(if (Test-Path $ApkAnalyzer) { $ApkAnalyzer })
}
foreach ($k in $items.Keys) { if ($items[$k]) { Ok "$k -> $($items[$k])" } else { Falta "$k no encontrado" } }

if ($Gitleaks) { Ok ("gitleaks " + (& $Gitleaks version)) }

Titulo 'Docker / MobSF'
if ($Docker) {
    # docker info se queda colgado mientras el motor arranca: se le da un máximo de 15 s.
    $job = Start-Job { param($d) & $d version --format '{{.Server.Version}}' 2>$null } -ArgumentList $Docker
    $motor = if (Wait-Job $job -Timeout 15) { Receive-Job $job } else { $null }
    Remove-Job $job -Force
    if ($motor) {
        Ok "Docker Desktop en ejecución (motor $motor)"
        $img = & $Docker images -q $MobsfImagen 2>$null
        if ($img) { Ok "Imagen MobSF descargada ($MobsfImagen)" } else { Falta "Falta la imagen: docker pull $MobsfImagen" }
    } else { Falta 'Docker no responde (apagado o arrancando). Si falla con "dockerInference", ver README' }
}

Titulo 'Emulador / dispositivo'
$avds = & $EmuladorExe -list-avds 2>$null
if ($avds -contains $AvdNombre) { Ok "AVD $AvdNombre creado" } else { Falta "No existe el AVD $AvdNombre" }

if ($Emulador -and -not ((& $Adb devices) -match 'emulator-\d+\s+device')) {
    Write-Host "  Arrancando $AvdNombre (puede tardar 1-2 min)..."
    Start-Process $EmuladorExe -ArgumentList "-avd $AvdNombre -writable-system -no-snapshot-load"
    & $Adb wait-for-device
    do { Start-Sleep 3 } until ((& $Adb shell getprop sys.boot_completed 2>$null) -match '1')
    Ok 'Emulador iniciado'
}
& $Adb devices -l

Titulo 'Repositorio'
Ok ("Rama: " + (git -C $Raiz branch --show-current))
if (git -C $Raiz check-ignore -q "$Evidencia\x.txt") { Ok 'auditoria/evidencia está ignorada por Git' } else { Falta 'auditoria/evidencia NO está ignorada' }
