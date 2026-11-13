# Certificate pinning (M5) — plan de rotación.
# Lee los pines de android/app/src/main/res/xml/network_security_config.xml, descarga la cadena TLS real
# de cada dominio de Firebase y comprueba que encadena a alguno de ellos. Correrlo antes del vencimiento
# de los pines y cuando Google anuncie cambios de CA:
#   .\auditoria\scripts\verificar_pines.ps1
# Si un dominio da NO COINCIDE: NO publicar; agregar el pin de la raíz nueva (https://pki.goog/repo/certs/).

. "$PSScriptRoot\comun.ps1"
$ErrorActionPreference = 'Continue'

$openssl = Buscar-Herramienta 'openssl' @('C:\Program Files\Git\usr\bin\openssl.exe', 'C:\Program Files\Git\mingw64\bin\openssl.exe')
if (-not $openssl) { throw 'Falta openssl (viene con Git for Windows)' }

$xmlRuta = Join-Path $Raiz 'android\app\src\main\res\xml\network_security_config.xml'
[xml]$nsc = Get-Content $xmlRuta -Raw
$pinSet = $nsc.'network-security-config'.'domain-config'.'pin-set'
$pines = @($pinSet.pin | ForEach-Object { $_.'#text'.Trim() })
Titulo "Pines configurados: $($pines.Count) (vencen $($pinSet.expiration))"
$dias = ([datetime]$pinSet.expiration - (Get-Date)).Days
if ($dias -lt 60) { Falta "Los pines vencen en $dias días: hay que renovarlos" } else { Ok "Faltan $dias días para el vencimiento" }

$dominios = 'firestore.googleapis.com', 'firebasestorage.googleapis.com', 'identitytoolkit.googleapis.com',
            'securetoken.googleapis.com', 'firebaseinstallations.googleapis.com', 'fcmregistrations.googleapis.com',
            'us-central1-macke-up-ai.cloudfunctions.net'
$out = Nueva-CarpetaEvidencia 'pines'
$tmp = Join-Path $env:TEMP 'verificar_pines'
New-Item -ItemType Directory -Force $tmp | Out-Null
$fallos = 0

foreach ($d in $dominios) {
    $cadena = '' | & $openssl s_client -connect "${d}:443" -servername $d -showcerts 2>$null | Out-String
    $certs = [regex]::Matches($cadena, '-----BEGIN CERTIFICATE-----[\s\S]+?-----END CERTIFICATE-----') | ForEach-Object { $_.Value }
    $coincide = $null; $detalle = @()
    $i = 0
    foreach ($c in $certs) {
        $f = Join-Path $tmp "c$i.pem"; $i++
        [IO.File]::WriteAllText($f, $c + "`n")
        $sujeto = (& $openssl x509 -in $f -noout -subject) -replace '^subject=', ''
        $der = Join-Path $tmp 'spki.der'
        & $openssl x509 -in $f -pubkey -noout | & $openssl pkey -pubin -outform der -out $der 2>$null
        $hash = [Convert]::ToBase64String([Security.Cryptography.SHA256]::Create().ComputeHash([IO.File]::ReadAllBytes($der)))
        $detalle += "    $hash  $sujeto"
        if ($pines -contains $hash -and -not $coincide) { $coincide = $sujeto }
    }
    if ($coincide) { Ok "$d -> coincide con: $coincide" }
    else { $fallos++; Falta "$d -> NO COINCIDE con ningún pin" }
    $detalle | Write-Host
    "$d`n$($detalle -join "`n")`n" | Out-File (Join-Path $out 'cadenas.txt') -Append -Encoding utf8
}

Write-Host ''
if ($fallos -eq 0) { Ok "Todos los dominios encadenan a un pin. Evidencia: $out" }
else { Falta "$fallos dominio(s) sin coincidencia: no publicar hasta actualizar los pines" }
exit $fallos
