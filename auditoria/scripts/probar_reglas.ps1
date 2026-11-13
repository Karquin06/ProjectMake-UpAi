# H-03 / H-08 — Prueba las reglas de Firestore y Storage en el emulador local (proyecto demo, nunca el real).
#   .\auditoria\scripts\probar_reglas.ps1                 -> reglas actuales del repo
#   .\auditoria\scripts\probar_reglas.ps1 -Commit 28fc2f7 -> reglas de ese commit (para el "antes")

param([string]$Commit)

. "$PSScriptRoot\comun.ps1"
$ErrorActionPreference = 'Continue'
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) { throw 'Falta la CLI de Firebase (npm i -g firebase-tools)' }

$etiqueta = if ($Commit) { $Commit } else { 'actual' }
$out = Nueva-CarpetaEvidencia "reglas_$etiqueta"
$dir = Join-Path $out 'config'
New-Item -ItemType Directory -Force $dir | Out-Null

foreach ($f in 'firestore.rules', 'storage.rules') {
    # cmd copia los bytes exactos (sin BOM: el compilador de reglas no lo acepta).
    if ($Commit) { cmd /c "git -C `"$Raiz`" show ${Commit}:$f > `"$(Join-Path $dir $f)`"" }
    else { Copy-Item (Join-Path $Raiz $f) $dir }
}
$json = @'
{
  "firestore": { "rules": "firestore.rules" },
  "storage": { "rules": "storage.rules" },
  "emulators": { "firestore": { "port": 8085 }, "storage": { "port": 9199 }, "ui": { "enabled": false } }
}
'@
[IO.File]::WriteAllText((Join-Path $dir 'firebase.json'), $json, (New-Object Text.UTF8Encoding $false))
Copy-Item (Join-Path $PSScriptRoot 'probar_reglas.mjs') $dir

Titulo "Reglas: $etiqueta"
# Se espera solo al proceso de la CLI: el emulador Java a veces queda vivo con la
# salida abierta y un pipe normal se quedaría esperando para siempre.
$log = Join-Path $out 'salida_cli.txt'
$cli = Start-Process cmd -ArgumentList "/c firebase emulators:exec --project demo-auditoria --only firestore,storage `"node probar_reglas.mjs`" > `"$log`" 2>&1" `
    -WorkingDirectory $dir -WindowStyle Hidden -PassThru
$cli.WaitForExit()
Get-CimInstance Win32_Process -Filter "Name='java.exe'" |
    Where-Object { $_.CommandLine -match 'cloud-firestore-emulator|cloud-storage-rules-runtime' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
$salida = Get-Content $log -Encoding utf8 | ForEach-Object { "$_" -replace "$([char]27)\[[0-9;]*m", '' }
$salida | Out-File (Join-Path $out 'resultado_completo.txt') -Encoding utf8
$resumen = $salida | Where-Object { $_ -match '^(OK|FALLA|==|Resultado)' }
$resumen | Out-File (Join-Path $out 'resultado.txt') -Encoding utf8
$resumen | Write-Host
Write-Host "`nEvidencia: $out"
