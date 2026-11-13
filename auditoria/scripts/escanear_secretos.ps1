# M1 / M10 — Busca secretos con gitleaks en el historial de Git y en los archivos actuales.
# Los reportes salen con los secretos ocultos (--redact), pero igual quedan en evidencia\ (ignorada).

. "$PSScriptRoot\comun.ps1"
if (-not $Gitleaks) { throw 'gitleaks no está instalado (winget install Gitleaks.Gitleaks)' }

$out = Nueva-CarpetaEvidencia 'secretos'
$cfg = Join-Path $Auditoria '.gitleaks.toml'
$ErrorActionPreference = 'Continue'

Titulo 'Historial de Git (todas las ramas)'
& $Gitleaks git $Raiz --config $cfg --redact --log-opts="--all" `
    --report-format json --report-path (Join-Path $out 'historial.json') --no-banner
$codHist = $LASTEXITCODE

Titulo 'Archivos actuales (incluye lo no versionado)'
& $Gitleaks dir $Raiz --config $cfg --redact `
    --report-format json --report-path (Join-Path $out 'archivos.json') --no-banner
$codDir = $LASTEXITCODE

Titulo 'Resumen'
foreach ($f in 'historial.json', 'archivos.json') {
    # En PowerShell 5.1 ConvertFrom-Json entrega el arreglo como un solo objeto: se desenrolla.
    $json = Get-Content (Join-Path $out $f) -Raw | ConvertFrom-Json
    $hallazgos = @($json | ForEach-Object { $_ })
    Write-Host ("  {0}: {1} hallazgo(s)" -f $f, $hallazgos.Count)
    $hallazgos | Group-Object RuleID, File | Sort-Object Count -Descending |
        Select-Object Count, @{ n = 'Regla, archivo'; e = { $_.Name } } |
        Format-Table -AutoSize | Out-String -Width 200 | Write-Host
}
Write-Host "Reportes en: $out"
Write-Host "Recuerda: un secreto que llegó al historial se ROTA, borrarlo del código no basta."
exit ([int]($codHist -ne 0 -or $codDir -ne 0))
