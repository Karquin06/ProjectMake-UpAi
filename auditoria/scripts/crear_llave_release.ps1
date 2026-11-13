# H-01 — Crea la llave de publicación (android/app/llave-release.jks) y android/key.properties.
# Ninguno de los dos se sube al repositorio (.gitignore). Guarda una copia segura de ambos:
# si se pierden, no se pueden publicar actualizaciones firmadas con la misma llave.
#   .\auditoria\scripts\crear_llave_release.ps1                  -> pide la contraseña
#   .\auditoria\scripts\crear_llave_release.ps1 -ContrasenaAleatoria -> genera una (llave de prueba local)

param([switch]$ContrasenaAleatoria, [switch]$Reemplazar)

. "$PSScriptRoot\comun.ps1"

$jks   = Join-Path $Raiz 'android\app\llave-release.jks'
$props = Join-Path $Raiz 'android\key.properties'
if ((Test-Path $jks) -and -not $Reemplazar) { throw "Ya existe $jks (usa -Reemplazar si de verdad quieres otra llave)" }

$keytool = Join-Path $env:JAVA_HOME 'bin\keytool.exe'
if (-not (Test-Path $keytool)) { $keytool = (Get-Command keytool -ErrorAction Stop).Source }

if ($ContrasenaAleatoria) {
    $bytes = New-Object byte[] 24
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $clave = [Convert]::ToBase64String($bytes) -replace '[+/=]', 'x'
} else {
    $s = Read-Host 'Contraseña para la llave (mínimo 12 caracteres)' -AsSecureString
    $clave = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
    if ($clave.Length -lt 12) { throw 'La contraseña debe tener al menos 12 caracteres' }
}

if (Test-Path $jks) { Remove-Item $jks }
& $keytool -genkeypair -v -keystore $jks -storetype PKCS12 -keyalg RSA -keysize 4096 -validity 10000 `
    -alias mackeupai -storepass $clave -keypass $clave `
    -dname 'CN=MackeUp AI, OU=Programacion Movil, O=UNICESAR, C=CO' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'keytool falló' }

@"
# Llave de publicación (H-01). NO subir al repositorio.
storeFile=llave-release.jks
storePassword=$clave
keyAlias=mackeupai
keyPassword=$clave
"@ | Set-Content $props -Encoding ascii

Ok "Llave creada: $jks"
Ok "Configuración: $props"
Titulo 'Huellas para registrar en Firebase (Configuración del proyecto > Tus apps > Android)'
& $keytool -list -v -keystore $jks -storepass $clave -alias mackeupai |
    Select-String 'SHA1:|SHA256:' | ForEach-Object { '  ' + $_.Line.Trim() }
