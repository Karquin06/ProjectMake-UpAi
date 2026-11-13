COMPLETADO

# Estado de la auditoría (para retomar el trabajo)

Última actualización: 2026-11-12 21:05 (hora Colombia) — fases 2, 3 y 4 terminadas.

> Si este archivo se modificó hace menos de 10 minutos, hay una sesión trabajando: NO tocar nada.

Rama: `feature/seguridad` (local; **no hacer push**). Commits sin líneas de coautoría ni marcas
de Claude. Cada corrección en su propio commit: `fix(seguridad): H-XX <qué cambia>`.
No publicar reglas ni funciones en Firebase (`firebase deploy`): eso lo hace el equipo.

## Fase 2 — Auditoría

- [x] M1–M10 revisados → `02_owasp_top10.md`, hallazgos H-01…H-09 → `03_hallazgos.md`
- [x] APK release analizado: `evidencia/apk/20261112-165641_28fc2f7-sucio/`
      - firma `CN=Android Debug, O=MakeUpAi, C=CO` (H-01)
      - `libapp.so`: 209 rutas `package:mackeupai/...` y nombres de clases legibles (H-04)
      - R8 SÍ activo en Java/Kotlin (989 clases renombradas)
      - manifiesto final agrega `RECORD_AUDIO`, `WRITE_EXTERNAL_STORAGE`, `USE_BIOMETRIC`,
        `USE_FINGERPRINT` (de plugins); la app usa `enableAudio: false` → ampliar H-07
- [x] Logcat del arranque en release: sin datos sensibles; `dumpsys package` muestra
      `flags=[ ... ALLOW_BACKUP ]` (evidencia H-02). `evidencia/logcat/20261112-172128_28fc2f7-release/`
- [x] mitmproxy sin CA confiable (sin sesión no hubo tráfico; el equipo la repite con su cuenta de prueba) (M5): `evidencia/mitmproxy_sin_ca/20261112-172441_28fc2f7-release/`
      revisar `mitmdump.txt` / `flujos.mitm`. En Android 15 no se puede instalar la CA como
      sistema (APEX), así que la prueba válida es la negativa: la app debe rechazar la conexión.
- [x] MobSF (no realizado): Docker Desktop falla con sockets dañados (ver README). Si no arranca, documentarlo
      como técnica no realizada (ya hay 6 técnicas).
- [x] Pasar esta evidencia a `02_owasp_top10.md`, `03_hallazgos.md` (H-04, H-07) y al informe
      (`informe/informe_seguridad.html`, marcadores `<!--EVIDENCIA_APK-->` y `<!--EVIDENCIA_H04-->`).

## Fase 3 — Correcciones (un commit por ID)

- [x] H-01 `android/app/build.gradle.kts`: release firmado con `android/key.properties` +
      `.jks` (ambos en `.gitignore`); script `auditoria/scripts/crear_llave_release.ps1`.
      `debug.keystore` queda solo para debug.
- [x] H-02 `AndroidManifest.xml`: `android:allowBackup="false"`, `android:fullBackupContent="false"`
      y `res/xml/reglas_extraccion_datos.xml` que excluya todo.
- [x] H-03 `firestore.rules` y `storage.rules`: la admin de marca solo escribe si
      `marcas/{marcaId}.activa == true`; `functions/src/marcas.ts` → `revokeRefreshTokens` al
      cambiar o quitar la marca. `npm test` en functions.
- [x] H-04 `auditoria/scripts/construir_apk.ps1`: ofuscar por defecto
      (`--obfuscate --split-debug-info`), símbolos fuera del repo.
- [x] H-05 `functions`: `npm audit fix`, `npm test`.
- [x] H-07 manifiesto: quitar `READ_MEDIA_IMAGES`, `READ_EXTERNAL_STORAGE` y, con
      `tools:node="remove"`, `RECORD_AUDIO`, `WRITE_EXTERNAL_STORAGE`, `USE_BIOMETRIC`,
      `USE_FINGERPRINT`; quitar la solicitud de galería en `permisos_service.dart` (revisar tests).
- [x] H-08 `storage.rules`: `perfiles/{uid}` → `allow read: if esDuena(uid) || esAdmin();`
- [x] H-09 envolver los 16 `debugPrint` en `if (kDebugMode)`.
- [x] `flutter analyze` y `flutter test` en verde antes de cada commit de Dart.
- H-06 (App Check) NO se implementa: necesita activar Play Integrity en la consola; queda
  documentado como mejora opcional.

## Fase 4 — Verificación

Hecho: probar_reglas antes/después (H-03, H-08), npm audit después (H-05), flutter test 326 OK, npm test 51 OK, gitleaks. 04_verificacion.md y secciones 6-7 del informe escritas; faltan los valores APK_* (reemplazar en 04_verificacion.md e informe_seguridad.html) con el APK nuevo: instalarlo en el emulador auditoria_api35 y repetir apksigner, dumpsys (ALLOW_BACKUP), grep libapp.so, permisos. Después: regenerar PDF, commit "docs(seguridad): verificacion fase 4", marcar COMPLETADO.

- [x] Compilar release con todo corregido: `.\auditoria\scripts\construir_apk.ps1`
- [x] Repetir cada prueba: firma (`apksigner`), `dumpsys package` (sin `ALLOW_BACKUP`),
      `grep -a -c "package:mackeupai/" libapp.so` (= 0), permisos del manifiesto del APK,
      `npm audit` (0 vulnerabilidades), Logcat en release, `escanear_secretos.ps1`.
- [x] Llenar `04_verificacion.md` y las secciones 6 y 7 del informe; regenerar el PDF con
      `.\auditoria\scripts\generar_informe.ps1`.
- [x] Al terminar todo, cambiar la primera línea de este archivo a `COMPLETADO`.

## Pendiente del equipo (fuera del alcance de Claude)

- `firebase deploy --only firestore:rules,storage,functions` tras revisar H-03, H-05 y H-08.
- Crear la llave de release real y registrar su SHA-1/SHA-256 en Firebase (H-01).
