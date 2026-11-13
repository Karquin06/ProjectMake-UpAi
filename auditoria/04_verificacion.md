# Fase 4 — Verificación

Un hallazgo solo se cierra si **la misma prueba**, repetida después de la corrección, ya no lo
reproduce. "Antes" = commit `28fc2f7` (versión auditada); "después" = rama `feature/seguridad`
con las correcciones. Los reportes crudos quedan en `evidencia/` (no se suben).

## Resumen

| ID | Sev. | Commit | Prueba repetida | Antes | Después | ¿Cerrado? |
|---|---|---|---|---|---|---|
| H-01 | Alta | `e85e1aa` | `apksigner verify --print-certs` sobre el APK de release | `CN=Android Debug, O=MakeUpAi, C=CO` (llave del repo) | `CN=MackeUp AI, OU=Programacion Movil, O=UNICESAR` (llave propia, fuera del repo) | Sí |
| H-02 | Media | `868452b` | `dumpsys package com.example.mackeupai` en el emulador | `flags=[ HAS_CODE ALLOW_CLEAR_USER_DATA ALLOW_BACKUP ]` | `flags=[ HAS_CODE ALLOW_CLEAR_USER_DATA ]` (sin `ALLOW_BACKUP`) | Sí |
| H-03 | Media | `bca8a32` | `probar_reglas.ps1` (emulador de Firestore y Storage, proyecto demo) | 3 de 5 casos de marcas FALLAN: ex-admin y marca desactivada escriben (200) | 5 de 5 OK: ex-admin y marca desactivada → 403 | Sí |
| H-04 | Media | `4d1386e` | `grep -a -o "package:mackeupai/…dart" libapp.so \| sort -u \| wc -l` | 209 rutas; `CredencialRepository` visible | 0 rutas; los nombres de clases ya no aparecen (solo quedan textos literales, como el nombre de la función que se llama) | Sí |
| H-05 | Media | `0e8c8f5` | `npm audit` en `functions/` | 10 (1 alta, 8 moderadas, 1 baja) | 7 moderadas, 0 altas (riesgo residual en SDK de Google) | Parcial |
| H-07 | Baja | `2738357` | Permisos del manifiesto del APK (`apkanalyzer manifest print`) | 14 permisos, con `RECORD_AUDIO`, `READ_MEDIA_IMAGES`, `READ/WRITE_EXTERNAL_STORAGE`, `USE_BIOMETRIC`, `USE_FINGERPRINT` | 8 permisos: sin micrófono, almacenamiento ni biometría | Sí |
| H-08 | Baja | `32401ed` | `probar_reglas.ps1` | Otra usuaria lee la foto de perfil (200) | Otra usuaria → 403; la dueña sigue leyendo (200) | Sí |
| H-09 | Baja | `f88462c` | Revisión de código + Logcat del release | 16 `debugPrint` activos en release | `debugPrint` es una función vacía en release (`lib/main.dart`) | Sí |
| H-06 | Media | — | — | Sin App Check | No corregido: requiere activar Play Integrity en la consola (mejora opcional) | No |

Pruebas generales después de las correcciones: `flutter test` → **326 tests OK**;
`npm test` (functions) → **51 tests OK** (incluye el nuevo de H-03); gitleaks sobre el historial →
mismas 6 llaves de cliente de Firebase, ningún secreto nuevo (`android/key.properties` y el `.jks`
están ignorados: `git ls-files` no los lista).

## Detalle

### H-03 y H-08 — Reglas en el emulador

`.\auditoria\scripts\probar_reglas.ps1 -Commit 28fc2f7` (antes) y `.\auditoria\scripts\probar_reglas.ps1`
(después). Corre en el emulador local con el proyecto `demo-auditoria`, sin tocar Firebase real.

```text
ANTES (28fc2f7)
OK    | Admin vigente crea producto de su marca                 | esperado PERMITIDO | obtenido PERMITIDO (200)
FALLA | Ex-admin (claim viejo, fuera de admins) crea producto   | esperado DENEGADO  | obtenido PERMITIDO (200)
FALLA | Admin de marca DESACTIVADA crea producto                | esperado DENEGADO  | obtenido PERMITIDO (200)
OK    | Admin vigente sube imagen de su marca                   | esperado PERMITIDO | obtenido PERMITIDO (200)
FALLA | Admin de marca DESACTIVADA sube imagen                  | esperado DENEGADO  | obtenido PERMITIDO (200)
OK    | Usuaria sube su propia foto de perfil                   | esperado PERMITIDO | obtenido PERMITIDO (200)
OK    | Usuaria lee su propia foto de perfil                    | esperado PERMITIDO | obtenido PERMITIDO (200)
FALLA | OTRA usuaria lee esa foto de perfil                     | esperado DENEGADO  | obtenido PERMITIDO (200)
Resultado: 4 caso(s) no cumplen

DESPUÉS (feature/seguridad)
OK    | Admin vigente crea producto de su marca                 | esperado PERMITIDO | obtenido PERMITIDO (200)
OK    | Ex-admin (claim viejo, fuera de admins) crea producto   | esperado DENEGADO  | obtenido DENEGADO (403)
OK    | Admin de marca DESACTIVADA crea producto                | esperado DENEGADO  | obtenido DENEGADO (403)
OK    | Admin vigente sube imagen de su marca                   | esperado PERMITIDO | obtenido PERMITIDO (200)
OK    | Admin de marca DESACTIVADA sube imagen                  | esperado DENEGADO  | obtenido DENEGADO (403)
OK    | Usuaria sube su propia foto de perfil                   | esperado PERMITIDO | obtenido PERMITIDO (200)
OK    | Usuaria lee su propia foto de perfil                    | esperado PERMITIDO | obtenido PERMITIDO (200)
OK    | OTRA usuaria lee esa foto de perfil                     | esperado DENEGADO  | obtenido DENEGADO (403)
Resultado: todas las reglas se comportan como se espera
```

> Las reglas corregidas están en el repositorio, pero **no se han publicado**. El equipo debe
> correr `firebase deploy --only firestore:rules,storage` para que apliquen en producción.

### H-05 — Dependencias

```text
ANTES:   10 vulnerabilities (1 low, 8 moderate, 1 high)   body-parser 2.0.0-2.3.0  Severity: high
DESPUÉS:  7 moderate severity vulnerabilities             (gaxios/uuid, google-gax/rimraf/glob/minimatch)
```

Las 7 restantes vienen de `firebase-admin` → `@google-cloud/storage` → `gaxios@6` → `uuid@9` y de
`google-gax` → `rimraf` → `glob` → `minimatch`. Solo se quitarían forzando versiones mayores con
`overrides`, con riesgo de romper el SDK. Tampoco tienen ruta de ataque aquí: el fallo de `uuid`
exige v3/v5/v6 con un buffer propio, y `glob`/`minimatch` no procesan entradas de usuarias. Se
aceptan como riesgo residual hasta la próxima versión de `firebase-admin`.

### Pruebas que el equipo debe repetir con sesión iniciada

- **M5, mitmproxy sin CA:** `.\auditoria\scripts\mitmproxy.ps1 -SinCertificado`, iniciar sesión con
  la cuenta de prueba: el login debe fallar por el certificado.
- **H-09, Logcat:** `.\auditoria\scripts\logcat.ps1 -Release` usando el simulador AR y las
  notificaciones: no debe aparecer ninguna línea `I/flutter` de la app.

### Verificación independiente con MobSF v4.6.5

`.\auditoria\scripts\mobsf.ps1` y `.\auditoria\scripts\mobsf_analizar.ps1` sobre los dos APK de release.

| Indicador | Antes (`28fc2f7`) | Después (`4d1386e`) |
|---|---|---|
| Puntaje de seguridad | 48/100 | 52/100 |
| Alertas altas | 2: firma con certificado de depuración (H-01); `minSdk` 24 | 1: `minSdk` 24 |
| Avisos | 15, incluido `allowBackup` sin definir (H-02) | 14 |
| Permisos peligrosos | 6 (cámara, notificaciones, micrófono, imágenes, lectura/escritura de almacenamiento) | 2 (cámara, notificaciones) (H-07) |
| Secretos | llave de cliente de Firebase + tablas hexadecimales | igual (falsos positivos) |

MobSF analiza también las librerías de Google: los avisos de MD5, SHA-1, `Random`, SQLite y archivos
temporales vienen de ellas, no del código de la app. Alerta nueva, no corregida: `minSdk` 24 permite
instalar la app en Android 7.0 sin parches; queda como recomendación para el equipo.

### Prueba en vivo con sesión iniciada (APK `3a0f001`: pinning + `FLAG_SECURE`)

Un integrante escribió la cuenta de prueba directamente en el emulador; las evidencias no incluyen la contraseña.

| Paso | Qué se hizo | Resultado |
|---|---|---|
| 1. Sin interceptor | Inicio de sesión y entrada a la selfie | Firebase Auth autentica la cuenta: el pinning no rompe la conexión. `dumpsys window` marca la ventana con `SECURE` y `screencap` de la selfie sale negro (solo se ve el diálogo de permiso del sistema) |
| 2. Con mitmproxy como proxy | Mismo inicio de sesión | Falla: `RecaptchaAction(signInWithPassword) … CertPathValidatorException: Trust anchor for certification path not found`; mitmproxy registra 18 conexiones con "the client does not trust the proxy's certificate" (incluida `firebaseinstallations.googleapis.com`) |

Observación (M9, residual): el SDK de Firebase Auth escribe el correo en Logcat (`I/FirebaseAuth: Logging in as …`).
No es código de la app. Limitación: con el APK de release la falla se debe a que no confía en la CA de mitmproxy; para
aislar el pinning hay que repetirla sobre un build de depuración con la CA instalada (los `debug-overrides` aceptan
CA de usuario y mantienen los pines). Evidencias: `evidencia/sesion_paso1/` y `evidencia/sesion_paso2_mitm/`.
