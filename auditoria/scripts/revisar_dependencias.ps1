# M2 — Dependencias desactualizadas o con vulnerabilidades conocidas (Flutter y Cloud Functions).

. "$PSScriptRoot\comun.ps1"
$ErrorActionPreference = 'Continue'
$out = Nueva-CarpetaEvidencia 'dependencias'

Titulo 'flutter pub outdated'
Push-Location $Raiz
flutter pub outdated --no-dev-dependencies 2>&1 | Tee-Object (Join-Path $out 'flutter_outdated.txt')
flutter pub outdated --json 2>$null | Out-File (Join-Path $out 'flutter_outdated.json') -Encoding utf8
Pop-Location

Titulo 'npm audit (functions)'
Push-Location (Join-Path $Raiz 'functions')
npm audit --omit=dev 2>&1 | Tee-Object (Join-Path $out 'npm_audit.txt')
npm audit --json 2>$null | Out-File (Join-Path $out 'npm_audit.json') -Encoding utf8
npm outdated 2>&1 | Tee-Object (Join-Path $out 'npm_outdated.txt')
Pop-Location

Write-Host "`nReportes en: $out"
Write-Host 'Revisa también dependency_overrides en pubspec.yaml: fija una versión vieja a propósito.'
