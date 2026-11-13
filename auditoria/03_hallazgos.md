# Fase 2 y 3 — Hallazgos y correcciones

Severidad: **Alta**, **Media**, **Baja**. Se corrigen primero los de mayor severidad; mínimo cinco.
La evidencia nunca muestra el secreto completo. Los reportes crudos están en
`auditoria/evidencia/` (no versionada).

## Registro

| ID | Riesgo OWASP | Descripción | Evidencia | Severidad | Corrección propuesta | Commit | Estado |
|---|---|---|---|---|---|---|---|
| H-01 | M1, M8 | El APK de release se firma con `debug.keystore`, que está versionado en un repositorio público con su contraseña escrita en Gradle. Cualquiera puede firmar un APK idéntico en firma: puede distribuir una "actualización" falsa por fuera de la tienda, y su huella SHA-1 está registrada en Firebase para el inicio con Google. | `android/app/build.gradle.kts` L31-44 (`signingConfig = signingConfigs.getByName("debug")` en `release`); `git ls-files` → `android/app/debug.keystore` (commit `6830141`); `apksigner verify --print-certs` sobre el APK | Alta | Crear una llave de release fuera del repo (`key.properties` + `.jks` en `.gitignore`), usarla en `buildTypes.release` y registrar su SHA en Firebase. Sacar `debug.keystore` del repo, generar una nueva y **rotar** la huella SHA-1 registrada. | `e85e1aa` | Cerrado |
| H-02 | M9 | Las capturas del simulador AR (fotos del rostro) se guardan en PNG sin cifrar en `getApplicationDocumentsDirectory()/resultados_ar/<uid en base64>/`. Como `android:allowBackup` no está definido (por defecto `true`), entran en el respaldo de Google y en la transferencia entre dispositivos, junto con la caché local de Firestore. | `lib/data/repositories/capturas_ar_repository.dart` L10-33; `AndroidManifest.xml` L12 (`<application>` sin `allowBackup`, `fullBackupContent` ni `dataExtractionRules`); salida de `revisar_manifiesto.ps1` | Media | `android:allowBackup="false"`, o reglas `dataExtractionRules` / `fullBackupContent` que excluyan `resultados_ar/` y la base de Firestore. Opcional: cifrar las capturas con una llave guardada en Keystore. | `868452b` | Cerrado |
| H-03 | M3 | Una marca desactivada (`activa: false`) ya no ve su panel (`resumenDeMarca`), pero las reglas solo miran el claim `marcaId`: su admin puede seguir creando, editando y borrando productos e imágenes. Además, `asignarAdminMarca` cambia el claim sin revocar la sesión, así que quien pierde el rol conserva permisos hasta que expire su token (hasta 1 h). | `firestore.rules` L131-139 (`esAdminMarca` sin revisar `activa`); `storage.rules` L35-40; `functions/src/marcas.ts` L367 (`setCustomUserClaims` sin `revokeRefreshTokens`) | Media | En las reglas, exigir `get(/databases/$(database)/documents/marcas/$(marcaId)).data.activa == true` para la admin de marca (también en Storage con `firestore.get`). En `asignarAdminMarca`, llamar a `auth.revokeRefreshTokens(uid)` al quitar o cambiar la marca. | `bca8a32` | Cerrado |
| H-04 | M7 | El código Dart del release no está ofuscado: se compila sin `--obfuscate --split-debug-info`, así que nombres de clases, métodos y rutas del proyecto quedan legibles en `libapp.so`. Eso facilita la ingeniería inversa de la lógica de roles y de las llamadas al backend. | `grep -a -o "package:mackeupai/…dart"` sobre `lib/arm64-v8a/libapp.so` del APK de release → **209 rutas** y nombres como `CredencialRepository`, `asignarAdminMarca`, `correoRecordado`. R8 sí está activo en Java (989 clases renombradas en `classes.dex`) | Media | Compilar con `flutter build apk --release --obfuscate --split-debug-info=build/simbolos` (opción `-Ofuscado` del script) y guardar los símbolos fuera del repo. Confirmar R8 activo en el release. | `4d1386e` | Cerrado |
| H-05 | M2 | `npm audit` en `functions/` reporta 10 vulnerabilidades conocidas en dependencias transitivas: 1 alta (`body-parser`, denegación de servicio), 8 moderadas (`minimatch`, `qs`, `uuid`, `google-gax`…) y 1 baja. Todas tienen arreglo disponible. | `evidencia/dependencias/<fecha>/npm_audit.txt` y `.json`; `npm outdated` (`firebase-admin` 14.5.0 → 14.5.1) | Media | `npm audit fix` y actualizar `firebase-admin`/`firebase-functions`; volver a correr `npm test` y `revisar_dependencias.ps1`. Planificar la subida de versiones mayores de Firebase en Flutter y quitar el `dependency_overrides` al actualizar AGP. | `0e8c8f5` | Cerrado parcial (7 moderadas residuales) |
| H-06 | M3, M1 | No hay Firebase App Check: Cloud Functions, Firestore y Storage aceptan peticiones de cualquier cliente que use la configuración pública (llaves `AIza…` en un repositorio público). Un script puede crear cuentas y llamar a `chatAsistente` (que gasta cuota de Gemini) o a las demás funciones sin usar la app. No se pudo verificar si las llaves tienen restricciones de API en Google Cloud. | Búsqueda de `app_check` / `enforceAppCheck` en `pubspec.yaml`, `lib/` y `functions/src`: sin resultados; gitleaks: 4 llaves de cliente en el historial | Media | Agregar `firebase_app_check` con Play Integrity (y depuración en desarrollo), `enforceAppCheck: true` en las funciones `onCall` y aplicación en Firestore y Storage desde la consola. Restringir cada llave de API a su app (paquete + SHA) y a las API que usa. *(Cuenta como mejora opcional: integridad.)* | — | Abierto (mejora opcional) |
| H-07 | M6, M8 | La app pide `READ_MEDIA_IMAGES` y `READ_EXTERNAL_STORAGE` y solicita `Permission.photos` en tiempo de ejecución, aunque `image_picker` usa el selector del sistema, que no necesita permisos en Android 13+. Además, el APK final declara `RECORD_AUDIO`, `WRITE_EXTERNAL_STORAGE`, `USE_BIOMETRIC` y `USE_FINGERPRINT`, que agregan los plugins y que la app no usa (`enableAudio: false`). | `AndroidManifest.xml` L6-9; `permisos_service.dart` L34-39; `apkanalyzer manifest print` del APK de release | Baja | Quitar esos permisos (los de plugins con `tools:node="remove"`) y la solicitud de `Permission.photos`; dejar que `image_picker` use el Photo Picker. | `2738357` | Cerrado |
| H-08 | M6 | Cualquier usuaria con sesión puede leer la foto de perfil de cualquier otra si conoce su uid (`perfiles/{uid}/foto.jpg`), y ninguna función de la app muestra fotos de otras usuarias. | `storage.rules` L18-19 (`allow read: if logueada();`) | Baja | `allow read: if esDuena(uid) \|\| esAdmin();` | `32401ed` | Cerrado |
| H-09 | M9 | 16 llamadas a `debugPrint` sin `kDebugMode` escriben en Logcat también en release: errores de Firebase Messaging, mensajes de error del detector AR, stack traces y metadatos de la cámara. No se vieron tokens ni datos personales, pero dan información interna a quien lea los logs. | `lib/ui/simulador_ar/simulador_ar_view_model.dart` L267-268, 374, 431, 437, 477, 572; `maquillaje_ar_view_model.dart` L246, 349, 388; `malla_facial_ar_service.dart` L281, 294, 314; `notificaciones_provider.dart` L42, 51, 64 | Baja | Envolver en `if (kDebugMode)` o usar un logger que se apague en release. Verificar con `scripts/logcat.ps1 -Release` antes y después. | `f88462c` | Cerrado |

## Orden sugerido para la Fase 3

Las cinco primeras cubren las mejoras obligatorias del PDF:

1. **H-01** → "Ningún secreto en el código ni en el repositorio. Si alguno se publicó, rotarlo."
2. **H-03** → "Validación de permisos en el servidor."
3. **H-02** → "Tokens y datos sensibles guardados de forma segura" (sin respaldo, cifrado opcional).
4. **H-04 + H-09** → "Build de release sin modo debug, sin logs sensibles y con R8 activo."
5. **H-05** → dependencias sin vulnerabilidades conocidas.
6. **H-06** → mejora opcional (+5): integridad con Play Integrity / App Check.

## Mejoras obligatorias (Fase 3)

- [x] Ningún secreto en el código ni en el repositorio. Si alguno se publicó, **rotarlo**. (H-01)
- [x] Tokens y datos sensibles guardados con Keystore (`flutter_secure_storage`). Ya cumple; H-02 lo completa.
- [x] Todo el tráfico por HTTPS, sin excepciones de tráfico en claro en release. (falta la prueba con mitmproxy)
- [x] Validación de entradas en la app y validación de permisos en el servidor. (H-03)
- [x] Build de release sin modo debug, sin logs sensibles y con R8 activo en Android. (H-04, H-09)

## Mejora opcional (hasta +5)

- [ ] Biometría ligada a una llave
- [x] Certificate pinning con plan de rotación — commit `793f84a` (`network_security_config.xml`, `scripts/verificar_pines.ps1`)
- [ ] Integridad con Play Integrity / App Check (H-06)

## Mejoras adicionales (además de los hallazgos)

| Mejora | Riesgo | Commit | Qué hace |
|---|---|---|---|
| Certificate pinning con plan de rotación | M5 | `793f84a` | `*.googleapis.com` y `*.cloudfunctions.net` solo aceptan cadenas de Google Trust Services (R1–R4) o GlobalSign Root CA; tráfico en claro prohibido; pines con vencimiento 2027-06-30 y script `verificar_pines.ps1` para renovarlos |
| `FLAG_SECURE` en pantallas con el rostro | M6, M9 | `3a0f001` | Selfie, simulador AR y capturas AR bloquean capturas y grabaciones de pantalla y no aparecen en "apps recientes" |
