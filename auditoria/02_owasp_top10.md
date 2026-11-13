# Fase 2 — OWASP Mobile Top 10 (2024)

Auditoría hecha el 12 de noviembre de 2026 sobre la rama `feature/seguridad`, commit `28fc2f7`
(incluye el módulo de marcas). Alcance: app Android en Flutter, reglas de Firestore y Storage y
Cloud Functions del proyecto `macke-up-ai`. El repositorio en GitHub es **público**, lo que sube
la severidad de todo lo que esté versionado.

## Resumen

| ID | Riesgo | Estado | Hallazgos |
|---|---|---|---|
| M1 | Improper Credential Usage | **No cumple** | H-01 |
| M2 | Inadequate Supply Chain Security | **No cumple** | H-05 |
| M3 | Insecure Authentication/Authorization | **No cumple** | H-03, H-06 |
| M4 | Insufficient Input/Output Validation | Cumple | — |
| M5 | Insecure Communication | Cumple | — (falta la prueba dinámica con mitmproxy) |
| M6 | Inadequate Privacy Controls | **No cumple** | H-07, H-08 |
| M7 | Insufficient Binary Protections | **No cumple** | H-04 |
| M8 | Security Misconfiguration | **No cumple** | H-01, H-07 |
| M9 | Insecure Data Storage | **No cumple** | H-02, H-09 |
| M10 | Insufficient Cryptography | Cumple | — |

## Detalle por riesgo

### M1 — Improper Credential Usage · No cumple

- **Pregunta:** ¿hay llaves, contraseñas o tokens en el código, el repositorio o el paquete?
- **Técnica:** gitleaks sobre el historial completo (81 commits, todas las ramas) y sobre los
  archivos actuales; revisión de `git ls-files`.
- **Resultado:**
  - gitleaks reporta 6 coincidencias `gcp-api-key` en el historial y 3 en los archivos actuales,
    todas en `lib/firebase_options.dart` y `android/app/google-services.json`. Son las llaves de
    **cliente** de Firebase (4 distintas en el historial, por el cambio de proyecto). Google las
    trata como identificadores públicos: no dan acceso por sí solas, el acceso lo controlan las
    reglas y la autenticación. Se aceptan como falso positivo, con la condición de restringirlas
    en Google Cloud (ver H-06).
  - La llave de Gemini **no** está en el código: se lee con `defineSecret("GEMINI_API_KEY")`
    desde Secret Manager. `functions/.env` solo contiene el nombre del modelo, también en todo su
    historial. Las llaves de cuentas de servicio están en `.gitignore`.
  - **Sí hay una credencial expuesta:** `android/app/debug.keystore` está versionado y su
    contraseña (`android`) está escrita en `android/app/build.gradle.kts`. El build de release
    se firma con esa misma llave → **H-01**.

### M2 — Inadequate Supply Chain Security · No cumple

- **Técnica:** `flutter pub outdated` y `npm audit` / `npm outdated` en `functions/`.
- **Resultado:** `npm audit` reporta **10 vulnerabilidades** (1 alta en `body-parser`, 8
  moderadas, 1 baja), todas transitivas y con arreglo disponible → **H-05**. En Flutter hay
  versiones mayores pendientes de todos los paquetes de Firebase y de ML Kit (sin avisos de
  seguridad publicados), y `pubspec.yaml` fija `permission_handler_android: 13.0.1` con
  `dependency_overrides`.

### M3 — Insecure Authentication/Authorization · No cumple

- **Técnica:** revisión de `firestore.rules`, `storage.rules` y de las 14 Cloud Functions.
- **Lo que cumple:**
  - Todas las funciones `onCall` exigen sesión (`exigirSesion`). Las de administración
    (`asignarAdminMarca`, `resumenAdmin`) verifican el claim `admin` **en el servidor**, y
    `enviarNotificacion` impide escribir a otra usuaria.
  - Las reglas restringen cada colección a su dueña. Nadie puede asignarse `rol` o `marcaId`
    desde el cliente, las colecciones internas (`credenciales`, `estadisticasProductos`) están
    cerradas y los catálogos solo los escribe la admin o la admin de la marca.
  - Las rutas de administración de la app (`_Destino.admin`) solo esconden pantallas; el control
    real lo hacen el servidor y las reglas, como debe ser.
  - `eliminarCuenta` exige reautenticación reciente.
- **Lo que falla:**
  - **H-03:** una marca desactivada pierde su panel, pero las reglas le siguen permitiendo
    escribir productos e imágenes. Y quitarle el rol a una admin de marca no revoca su sesión.
  - **H-06:** no hay Firebase App Check. El backend acepta peticiones de cualquier cliente que
    tenga la configuración pública (que está en un repositorio público).

### M4 — Insufficient Input/Output Validation · Cumple

- **Técnica:** revisión de las funciones de lectura de parámetros y de las reglas.
- **Resultado:** cada función valida tipos, largos y listas blancas antes de usar los datos:
  `leerPeticionChat` (máximo 500 caracteres, historial de 10), `leerPeticion` (límite entre 1 y
  50), `leerEvento` (sin `/`, máximo 200), `rutaTemporalValida` (evita rutas con `..`). El chat
  tiene límite de mensajes por minuto. Las reglas validan tipos y rangos (`productoValido`,
  `marcaValida`, enumeraciones de estación y subtono). Los formularios validan URL y correo. La
  app no declara deep links.
- **Observación:** el historial del chat lo envía el cliente, que podría falsear turnos previos
  del modelo. El impacto queda limitado a la propia conversación de quien lo haga.

### M5 — Insecure Communication · Cumple (falta verificación dinámica)

- **Técnica:** revisión del manifiesto, de `Info.plist` y búsqueda de `http://` en el código.
- **Resultado:** la app no define `usesCleartextTraffic` ni `network_security_config`. Con
  `targetSdk` 36 el tráfico en claro está bloqueado por defecto. Todo el tráfico va a servicios
  de Google por HTTPS. `Info.plist` no tiene `NSAllowsArbitraryLoads`. No se encontraron URL
  `http://` salvo en textos de validación de formularios.
- **Prueba dinámica (parcial):** con el APK de release en el emulador y mitmproxy como proxy
  sin certificado confiable, la pantalla de bienvenida no generó tráfico propio de la app
  (`evidencia/mitmproxy_sin_ca/20261112-172441_…`). El resto del tráfico solo aparece con sesión
  iniciada y la auditoría no inicia sesión en el proyecto real de Firebase. El equipo debe
  repetirla con su cuenta de prueba: `mitmproxy.ps1 -SinCertificado`, y el login tiene que
  fallar por el certificado. En Android 15 la CA de mitmproxy ya no se puede instalar como
  certificado de sistema (los certificados viven en un módulo APEX). No hay certificate pinning;
  queda como mejora opcional.

### M6 — Inadequate Privacy Controls · No cumple

- **Técnica:** revisión de permisos, reglas de Storage y manejo de selfies.
- **Lo que cumple:** la colorimetría pide consentimiento explícito. Las selfies se analizan en
  un temporal privado que se borra al terminar, y las que van a Cloud Functions se borran en
  menos de una hora (`limpiarImagenesTemporales`). Además existe la función de eliminar cuenta
  y los datos (habeas data).
- **Lo que falla:**
  - **H-07:** se piden `READ_MEDIA_IMAGES` y `READ_EXTERNAL_STORAGE`, aunque el selector de
    imágenes no los necesita en Android 13+. El APK final además declara `RECORD_AUDIO`
    (micrófono), `WRITE_EXTERNAL_STORAGE`, `USE_BIOMETRIC` y `USE_FINGERPRINT`, que agregan los
    plugins y que la app no usa (las dos cámaras usan `enableAudio: false`).
  - **H-08:** cualquier usuaria con sesión puede leer la foto de perfil de otra, y la app no
    tiene ninguna función que lo requiera.

### M7 — Insufficient Binary Protections · No cumple

- **Técnica:** compilación de release y análisis del APK con `apkanalyzer`/`apksigner`
  (`scripts/construir_apk.ps1`); revisión de `build.gradle.kts`.
- **Resultado:** el código Dart se compila sin `--obfuscate` ni `--split-debug-info`. En el
  `lib/arm64-v8a/libapp.so` del APK aparecen **209 rutas** `package:mackeupai/…dart` y nombres como
  `CredencialRepository`, `asignarAdminMarca` o `correoRecordado` → **H-04**. R8 sí está activo
  del lado Java/Kotlin: `classes.dex` tiene 989 clases renombradas, y Logcat muestra trazas
  como `t7.b.call()(r8-map-id-…)`. No hay detección de root ni de manipulación (Play Integrity /
  App Check, ver H-06).

### M8 — Security Misconfiguration · No cumple

- **Técnica:** `scripts/revisar_manifiesto.ps1` (manifiesto fuente y fusionado de release) y
  `apksigner`.
- **Resultado:**
  - El release no es `debuggable`: `apkanalyzer manifest debuggable` da `false` y Logcat
    registra "Not starting debugger since process cannot load the jdwp agent". El único
    componente exportado del manifiesto fuente es `MainActivity`, el lanzador. Los que agregan
    los plugins (receptores de FCM, actividades de Firebase Auth) están protegidos con permisos
    de sistema.
  - `dumpsys package` en el emulador muestra `flags=[ HAS_CODE ALLOW_CLEAR_USER_DATA ALLOW_BACKUP ]`
    (ver H-02).
  - El release se firma con la llave de depuración pública (**H-01**) y pide permisos de más
    (**H-07**).
  - En iOS, `Info.plist` no tiene `NSCameraUsageDescription` ni
    `NSPhotoLibraryUsageDescription`: la app se cerraría al pedir la cámara y Apple la
    rechazaría. Se anota como observación porque la entrega es Android.

### M9 — Insecure Data Storage · No cumple

- **Técnica:** revisión de repositorios y servicios que escriben en disco, búsqueda de
  `print`/`debugPrint`, manifiesto. La captura con Logcat queda pendiente del emulador.
- **Lo que cumple:** `flutter_secure_storage` (Keystore) solo guarda el correo recordado y la
  marca del onboarding. **Nunca** se guardan contraseñas ni tokens: la sesión la maneja Firebase
  Auth.
- **Lo que falla:**
  - **H-02:** las capturas del simulador AR (fotos del rostro) se guardan en PNG sin cifrar
    y, como `allowBackup` no está definido, entran en el respaldo de Android.
  - **H-09:** 16 `debugPrint` sin `kDebugMode` imprimen errores, stack traces y metadatos de
    cámara también en release.

### M10 — Insufficient Cryptography · Cumple

- **Técnica:** búsqueda de MD5, SHA-1, DES, ECB, `Random()` y llaves embebidas en `lib/` y
  `functions/src`, más gitleaks.
- **Resultado:** no se usan algoritmos débiles. El único hash propio es SHA-256 para seudonimizar
  la usuaria en las estadísticas (`codigoAnonimo`, solo en el servidor). El cifrado local lo
  delega `flutter_secure_storage` al Keystore. No hay llaves criptográficas en el código.

## Técnicas usadas

- [x] Secretos con gitleaks (código + historial) — `scripts/escanear_secretos.ps1`
- [x] Dependencias con `flutter pub outdated` / `npm audit` — `scripts/revisar_dependencias.ps1`
- [x] Revisión de `AndroidManifest.xml`, `Info.plist` y permisos — `scripts/revisar_manifiesto.ps1`
- [x] Análisis del APK de release con `apkanalyzer` y `apksigner` — `scripts/construir_apk.ps1`
- [x] Revisión de código de reglas y Cloud Functions
- [x] Logs con Logcat: arranque del APK de release en el emulador `auditoria_api35` (Android 15),
      sin datos sensibles
- [x] Tráfico con mitmproxy: con sesión iniciada (cuenta de prueba escrita por el equipo en el
      emulador) el inicio de sesión falla con `CertPathValidatorException`; 18 conexiones rechazadas
- [x] Análisis del APK con MobSF v4.6.5 (Docker): APK antes 48/100 y después 52/100 —
      `scripts/mobsf_analizar.ps1`, reportes en `evidencia/mobsf_*`
