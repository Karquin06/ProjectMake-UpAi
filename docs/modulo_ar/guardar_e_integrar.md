# Guardar e integrar el trabajo de Mauricio

**Estado actualizado:** el merge ya quedó cerrado por Mauricio en `4422235`. Continúa desde el paso 2. Los 31 commits pendientes de publicar incluyen el historial del equipo incorporado por ese merge.

Esta guía corresponde al estado revisado el 26 de octubre de 2026 en C:\proyectos\ProjectMake-UpAi: rama feature/ar, HEAD de7d519, merge pendiente con develop 2db4a29 y sin conflictos por resolver. Si el estado cambia, revisa antes de seguir. Mauricio ejecuta los commits y la publicación; Codex no los ejecutó.

## Recorrido

feature/ar → Pull Request a develop → revisión del equipo → Pull Request de develop a main. Los commits guardan versiones locales; push los publica en GitHub; el merge del PR incorpora esos commits al historial de integración. No hace falta repetir los mismos cambios como un commit independiente en main.

## 1. Cerrar la integración pendiente

Los siguientes 152 archivos ya están preparados y corresponden a las novedades del equipo. El primer commit guarda esa integración; los cambios locales nuevos de AR y Armario siguen pendientes para los pasos posteriores.

~~~text
README.md
analysis_options.yaml
android/.gitignore
android/app/build.gradle.kts
android/app/debug.keystore
android/app/google-services.json
android/app/src/main/res/drawable-hdpi/android12splash.png
android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png
android/app/src/main/res/drawable-hdpi/splash.png
android/app/src/main/res/drawable-mdpi/android12splash.png
android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png
android/app/src/main/res/drawable-mdpi/splash.png
android/app/src/main/res/drawable-night-hdpi/android12splash.png
android/app/src/main/res/drawable-night-mdpi/android12splash.png
android/app/src/main/res/drawable-night-xhdpi/android12splash.png
android/app/src/main/res/drawable-night-xxhdpi/android12splash.png
android/app/src/main/res/drawable-night-xxxhdpi/android12splash.png
android/app/src/main/res/drawable-v21/background.png
android/app/src/main/res/drawable-v21/launch_background.xml
android/app/src/main/res/drawable-xhdpi/android12splash.png
android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png
android/app/src/main/res/drawable-xhdpi/splash.png
android/app/src/main/res/drawable-xxhdpi/android12splash.png
android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png
android/app/src/main/res/drawable-xxhdpi/splash.png
android/app/src/main/res/drawable-xxxhdpi/android12splash.png
android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png
android/app/src/main/res/drawable-xxxhdpi/splash.png
android/app/src/main/res/drawable/background.png
android/app/src/main/res/drawable/launch_background.xml
android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
android/app/src/main/res/mipmap-hdpi/ic_launcher.png
android/app/src/main/res/mipmap-mdpi/ic_launcher.png
android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
android/app/src/main/res/values-night-v31/styles.xml
android/app/src/main/res/values-night/styles.xml
android/app/src/main/res/values-v31/styles.xml
android/app/src/main/res/values/colors.xml
android/app/src/main/res/values/styles.xml
assets/icon/icono_adaptativo.png
assets/icon/icono_app.png
assets/icon/splash_fondo.png
assets/icon/splash_logo.png
assets/images/logo_proyecto.jpeg
firebase.json
functions/.env
functions/README.md
functions/src/ana.test.ts
functions/src/asistente.ts
functions/src/catalogo.test.ts
functions/src/cuenta.ts
functions/src/datos/catalogo.ts
functions/src/index.ts
functions/src/notificaciones.ts
functions/src/puntaje.ts
functions/src/recomendaciones.ts
functions/src/scripts/documentos_catalogo.ts
functions/src/scripts/sembrar_catalogo.ts
ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@1x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@2x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@1x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@2x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@1x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@2x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png
ios/Runner/Assets.xcassets/LaunchBackground.imageset/Contents.json
ios/Runner/Assets.xcassets/LaunchBackground.imageset/background.png
ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json
ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png
ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png
ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png
ios/Runner/Base.lproj/LaunchScreen.storyboard
lib/core/constants/app_assets.dart
lib/core/constants/app_constants.dart
lib/core/constants/app_strings.dart
lib/core/routes/app_router.dart
lib/data/datos/catalogo_ejemplo.dart
lib/data/repositories/auth_repository.dart
lib/data/repositories/catalogo_repository.dart
lib/data/repositories/conversacion_repository.dart
lib/data/repositories/recomendacion_repository.dart
lib/data/services/analisis/analisis_color.dart
lib/data/services/detector_rostro_vivo.dart
lib/data/services/funciones_ia_service.dart
lib/data/services/permisos_service.dart
lib/data/services/puntaje_compatibilidad.dart
lib/models/recomendacion.dart
lib/providers/app_providers.dart
lib/providers/asistente_provider.dart
lib/providers/producto_provider.dart
lib/providers/recomendacion_provider.dart
lib/ui/admin/catalogo_admin_view_model.dart
lib/ui/colorimetria/captura_selfie_view.dart
lib/ui/colorimetria/captura_selfie_view_model.dart
lib/ui/colorimetria/colorimetria_home.dart
lib/ui/colorimetria/widgets/encuadre_rostro.dart
lib/ui/colorimetria/widgets/guia_captura_selfie.dart
lib/ui/home/home_view.dart
lib/ui/home/home_view_model.dart
lib/ui/recomendaciones/destacadas_home.dart
lib/ui/recomendaciones/detalle_prenda_view.dart
lib/ui/recomendaciones/detalle_producto_view.dart
lib/ui/recomendaciones/detalle_recomendacion_view_model.dart
lib/ui/recomendaciones/esperar_perfil.dart
lib/ui/recomendaciones/recomendaciones_view.dart
lib/ui/recomendaciones/recomendaciones_view_model.dart
lib/ui/recomendaciones/widgets/calificacion_recomendacion.dart
lib/ui/recomendaciones/widgets/detalle_recomendacion.dart
lib/ui/recomendaciones/widgets/etiqueta_compatibilidad.dart
lib/ui/recomendaciones/widgets/filtro_ocasion.dart
lib/ui/recomendaciones/widgets/imagen_item.dart
lib/ui/recomendaciones/widgets/motivo_compatibilidad.dart
lib/ui/recomendaciones/widgets/selector_tipo_recomendacion.dart
lib/ui/recomendaciones/widgets/tarjeta_prenda.dart
lib/ui/recomendaciones/widgets/tarjeta_producto.dart
lib/ui/recomendaciones/widgets/tarjeta_recomendacion.dart
lib/ui/splash/splash_view.dart
lib/ui/splash/splash_view_model.dart
lib/ui/splash/widgets/logo_animado.dart
pubspec.lock
pubspec.yaml
storage.rules
test/catalogo/formularios_catalogo_test.dart
test/colorimetria/encuadre_rostro_test.dart
test/colorimetria/pantallas_colorimetria_test.dart
test/home/home_test.dart
test/integracion/flujo_completo_test.dart
test/recomendaciones/recomendaciones_test.dart
test/splash/splash_view_model_test.dart
web/favicon.png
web/icons/Icon-192.png
web/icons/Icon-512.png
web/icons/Icon-maskable-192.png
web/icons/Icon-maskable-512.png
web/manifest.json
~~~

Estos comandos solo consultan el estado y lo que entrará al commit:

~~~powershell
cd C:\proyectos\ProjectMake-UpAi
git branch --show-current
git status
git diff --cached --name-only
git diff --cached --stat
git diff --cached --check
~~~

Debe indicar feature/ar y que los conflictos están resueltos pero el merge continúa abierto. Después de revisar los archivos, este comando crea el commit de integración con el índice actual:

~~~powershell
git commit -m "merge(ar): integrar develop actualizado"
git status
~~~

No ejecutes git add . antes de este paso. No cambies a main mientras tienes el merge abierto. Si Git anuncia conflictos o falla el commit, resuelve esa situación antes de seguir; los siguientes pasos asumen que el merge ya quedó cerrado.

## 2. Persistencia del Armario y de las capturas

Incluye modelos, almacenamiento personal, mensajes compartidos y la dependencia path_provider. No modifica el catálogo remoto.

Archivos o carpetas que se incluirán:

- lib/models/elemento_armario.dart
- lib/models/captura_ar.dart
- lib/data/repositories/armario_repository.dart
- lib/data/repositories/capturas_ar_repository.dart
- lib/providers/armario_provider.dart
- lib/core/constants/app_strings.dart
- pubspec.yaml
- pubspec.lock
- test/armario/armario_test.dart
- test/armario/capturas_ar_test.dart

git add prepara únicamente los archivos indicados, sin crear el commit. Los comandos diff permiten comprobar el contenido y su lista; ejecútalos y revisa su salida antes del commit.

~~~powershell
$archivosCommit = @(
  'lib/models/elemento_armario.dart'
  'lib/models/captura_ar.dart'
  'lib/data/repositories/armario_repository.dart'
  'lib/data/repositories/capturas_ar_repository.dart'
  'lib/providers/armario_provider.dart'
  'lib/core/constants/app_strings.dart'
  'pubspec.yaml'
  'pubspec.lock'
  'test/armario/armario_test.dart'
  'test/armario/capturas_ar_test.dart'
)
git add -- $archivosCommit
git diff --cached --name-only
git diff --cached --stat
git diff --cached --check
git diff --cached
~~~

Después de revisar esa selección, git commit guarda la versión preparada:

~~~powershell
git commit -m "feat(armario): guardar articulos y capturas por cuenta"
git status
~~~

## 3. Cámara, detección y simulación de labial

Incluye procesamiento de cámara Android, corrección del formato Samsung, repintado, selección por estación, intensidad, comparación, captura y vista previa de webcam en web. Registra las dependencias del módulo.

Archivos o carpetas que se incluirán:

- lib/models/deteccion_facial_ar.dart
- lib/data/services/deteccion_facial_ar_service.dart
- lib/ui/simulador_ar/
- lib/providers/app_providers.dart
- lib/providers/producto_provider.dart
- test/simulador_ar/

git add prepara únicamente los archivos indicados, sin crear el commit. Los comandos diff permiten comprobar el contenido y su lista; ejecútalos y revisa su salida antes del commit.

~~~powershell
$archivosCommit = @(
  'lib/models/deteccion_facial_ar.dart'
  'lib/data/services/deteccion_facial_ar_service.dart'
  'lib/ui/simulador_ar/'
  'lib/providers/app_providers.dart'
  'lib/providers/producto_provider.dart'
  'test/simulador_ar/'
)
git add -- $archivosCommit
git diff --cached --name-only
git diff --cached --stat
git diff --cached --check
git diff --cached
~~~

Después de revisar esa selección, git commit guarda la versión preparada:

~~~powershell
git commit -m "feat(ar): integrar deteccion de labios y simulador de labial"
git status
~~~

## 4. Pantallas del Armario e integración con recomendaciones

Incluye las pantallas personales, consulta y eliminación de capturas, guardado desde recomendaciones, ruta autenticada y pruebas de navegación.

Archivos o carpetas que se incluirán:

- lib/ui/armario/
- lib/core/routes/app_router.dart
- lib/ui/recomendaciones/detalle_prenda_view.dart
- lib/ui/recomendaciones/detalle_producto_view.dart
- test/home/home_test.dart
- test/armario/armario_widget_test.dart

git add prepara únicamente los archivos indicados, sin crear el commit. Los comandos diff permiten comprobar el contenido y su lista; ejecútalos y revisa su salida antes del commit.

~~~powershell
$archivosCommit = @(
  'lib/ui/armario/'
  'lib/core/routes/app_router.dart'
  'lib/ui/recomendaciones/detalle_prenda_view.dart'
  'lib/ui/recomendaciones/detalle_producto_view.dart'
  'test/home/home_test.dart'
  'test/armario/armario_widget_test.dart'
)
git add -- $archivosCommit
git diff --cached --name-only
git diff --cached --stat
git diff --cached --check
git diff --cached
~~~

Después de revisar esa selección, git commit guarda la versión preparada:

~~~powershell
git commit -m "feat(armario): conectar catalogo recomendaciones y resultados"
git status
~~~

## 5. Documentación

Incluye funcionamiento, pruebas, límites de la versión y esta guía.

Archivos o carpetas que se incluirán:

- docs/modulo_ar/fase_2_deteccion_facial.md
- docs/modulo_ar/guardar_e_integrar.md

git add prepara únicamente los archivos indicados, sin crear el commit. Los comandos diff permiten comprobar el contenido y su lista; ejecútalos y revisa su salida antes del commit.

~~~powershell
$archivosCommit = @(
  'docs/modulo_ar/fase_2_deteccion_facial.md'
  'docs/modulo_ar/guardar_e_integrar.md'
)
git add -- $archivosCommit
git diff --cached --name-only
git diff --cached --stat
git diff --cached --check
git diff --cached
~~~

Después de revisar esa selección, git commit guarda la versión preparada:

~~~powershell
git commit -m "docs(ar): documentar simulador armario y sustentacion"
git status
~~~

## 6. Comprobar antes de publicar

Estos comandos analizan y prueban el árbol de trabajo y revisan el historial; no publican nada:

~~~powershell
flutter analyze
flutter test
git status
git log -6 --oneline
~~~

Si alguna prueba falla, corrige y revisa su cambio antes de publicar. Las pruebas automáticas no sustituyen la validación física del maquillaje y las capturas en el Samsung, que sigue pendiente. Describe esa limitación en el PR.

Pueden seguir apareciendo cambios anteriores en analysis_options.yaml y los archivos generados de Linux, macOS y Windows; se conservan fuera de los commits propuestos. El archivo accidental cuyo nombre empieza por "olver conflictos" también queda fuera. No borres estos archivos para conseguir un estado limpio.

## 7. Publicar tu rama

Comprueba otra vez que sigues en feature/ar. El siguiente push envía los commits locales de esa rama a origin/feature/ar; no modifica main ni develop. Hazlo cuando hayas revisado los commits y las pruebas.

~~~powershell
git branch --show-current
git push origin feature/ar
$LASTEXITCODE
git log -1 --oneline
git ls-remote --heads origin feature/ar
~~~

El código de salida del push debe ser 0 y el hash remoto debe coincidir con HEAD. Si el push falla o es rechazado, no uses --force. Revisa el mensaje antes de continuar. Para el problema HTTPS que ocurrió antes, esta alternativa limita los ajustes a ese comando:

~~~powershell
git -c credential.interactive=false -c http.version=HTTP/1.1 push --verbose --progress origin feature/ar
~~~

## 8. Llevar el trabajo a develop y main

1. Abre https://github.com/Karquin06/ProjectMake-UpAi/compare/develop...feature/ar?expand=1. Comprueba base=develop y compare=feature/ar.
2. Revisa Files changed y la lista de commits. Título propuesto: "Integrar simulador de labiales y Armario local". Describe: selector por estación, labial Android, vista previa web, guardado local por cuenta, pruebas y validación física pendiente.
3. Create pull request publica la propuesta de integración. Solicita la revisión del equipo. Si aparecen conflictos, se resuelven en feature/ar conservando ambos módulos; no se fuerza el push.
4. Cuando el equipo apruebe el PR, las pruebas pasen y el alcance esté validado, Merge pull request integra feature/ar en develop, si tus permisos lo permiten.
5. Para la principal, abre https://github.com/Karquin06/ProjectMake-UpAi/compare/main...develop?expand=1. Comprueba base=main y compare=develop. Este PR puede incluir trabajo de otros integrantes que también esté listo en develop.
6. Revisa y acuerda con el equipo todos los cambios de ese segundo PR antes de publicarlo y fusionarlo. Su merge incorpora la versión aprobada en main.

No hagas git push origin main ni copies a mano los archivos en main. Tu main local está atrasada respecto de origin/main y no se necesita para crear estos PRs.
