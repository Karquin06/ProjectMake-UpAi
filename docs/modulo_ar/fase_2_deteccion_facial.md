# Fase 2: detección facial y guía del contorno de labios

## Objetivo y alcance

Make-Up AI permitirá probar labiales compatibles con la colorimetría de la
usuaria. Esta etapa implementa la base geométrica: detecta un rostro y dibuja
cuatro contornos de labios en verde sobre la cámara frontal. Todavía no aplica
labial ni muestra productos. Escáner y Armario no se implementan.

## Integración comprobada con el equipo

- `ColorimetriaProvider.perfil` expone `PerfilColorimetria`, con estación y subtono.
- `CatalogoRepository.listarProductos` admite `FiltroCatalogo` con categoría,
  estación y `soloActivos`; devuelve páginas con `ultimo` y `hayMas`.
- `ProductoMaquillaje` ya incluye `colorHex`, `tono`, `categoria`,
  `estacionesCompatibles`, `subtonoCompatible`, `activo` y `acabado`.

La conexión posterior consultará labiales activos de la estación y evaluará su
compatibilidad de subtono. Tendrá que recorrer páginas (no confundir una página
vacía tras filtrar con el fin del catálogo), tratar falta de perfil/errores y
acordar la interpretación de listas de compatibilidad vacías con Ana y Jaider.
No se inventó una política de recomendaciones ni se modificaron esos módulos.
El colorHex será la base visual aproximada; no reproduce físicamente un acabado.
La fase 2 no consulta Firestore ni necesita productos mock.

## Archivos y responsabilidades

- `lib/models/deteccion_facial_ar.dart`: datos inmutables; dimensiones originales,
  rotación aplicada, frontal/espejo, presencia de rostro y cuatro listas de puntos.
  `proyectar` escala las coordenadas orientadas al lienzo y refleja el eje X frontal.
- `lib/data/services/deteccion_facial_ar_service.dart`: interfaz DetectorLabiosAr,
  conversión NV21 y ejecución local de ML Kit. No usa Firebase ni archivos temporales.
- `lib/ui/simulador_ar/simulador_ar_view_model.dart`: inicia el stream, procesa
  solo un fotograma a la vez, publica resultados y coordina el cierre de recursos.
- `lib/ui/simulador_ar/widgets/contorno_labios_painter.dart`: dibuja líneas verdes,
  sin rellenar ni colorear los labios. Requiere cuatro contornos completos.
- `lib/ui/simulador_ar/simulador_ar_view.dart`: superpone CustomPaint como child
  de CameraPreview y muestra búsqueda, ausencia de rostro/labios y error.
- `lib/core/constants/app_strings.dart`: textos de detección, en español.
- `test/simulador_ar/deteccion_facial_ar_test.dart`: conversión, dimensiones,
  padding, pixel stride, rotaciones, escala, espejo e inmutabilidad.
- `test/simulador_ar/simulador_ar_view_model_test.dart`: amplía las pruebas de
  cámara con descarte de frames ocupados, resultados antiguos y cierre del detector.

Se mantienen View, ViewModel, Service y Model separados. La dependencia de detección
se inyecta por constructor mediante DetectorLabiosAr; las pruebas usan DetectorFalso.
El estado sigue siendo local a la pantalla: no se agrega otro Provider global.

## APIs y elección del detector

Se usan las versiones existentes: camera 0.12.1, CameraX 0.7.5+1,
google_mlkit_face_detection 0.15.1 y su commons 0.13.0. No se cambió pubspec.yaml.
Las APIs se comprobaron en el código instalado, no solo en ejemplos recientes.

```dart
FaceDetectorOptions(
  enableContours: true,
  performanceMode: FaceDetectorMode.fast,
  minFaceSize: 0.15,
)
```

Se desactivan por defecto clasificación, landmarks y tracking. Se utilizan
upperLipTop, upperLipBottom, lowerLipTop y lowerLipBottom. El modo contornos
se orienta al rostro prominente: no se promete maquillaje para múltiples personas.
Se eligió Face Detection porque ya existe y proporciona estos contornos. Face Mesh
no se instala en esta fase; su API Android sigue en beta.

Referencias para consultar junto con el código instalado:
- https://developers.google.com/ml-kit/vision/face-detection/android
- https://developers.google.com/ml-kit/vision/face-mesh-detection/android
- https://github.com/flutter-ml/google_ml_kit_flutter/tree/develop/packages/google_mlkit_commons

## Flujo del fotograma

1. CameraController se crea con enableAudio:false e ImageFormatGroup.nv21.
2. Después de initialize, startImageStream entrega CameraImage.
3. procesarFotograma descarta la imagen si hay otra operación pendiente, la app
   está inactiva, el controlador ya cambió o la pantalla está cerrada.
4. El servicio calcula la rotación a partir del sensor y DeviceOrientation.
5. Un plano NV21 compacto se usa directamente; tres planos YUV se compactan
   en un buffer Y + VU, respetando bytesPorFila y bytesPorPixel.
6. InputImage.fromBytes recibe dimensiones sin rotar y rotación explícita.
7. processImage devuelve rostros. Se toma el de mayor área y sus contornos.
8. El ViewModel verifica que la orientación y la generación sigan vigentes.
9. La vista recibe notifyListeners; CustomPainter dibuja los contornos.
10. Un resultado sin rostro elimina el dibujo anterior; no conserva labios ficticios.

CameraX 0.7.5+1 puede reportar yuv420 aunque entregue un plano NV21 al solicitarlo.
Por eso no se identifica el formato únicamente por image.format.raw. Se comprueba
la estructura de planos y la longitud compacta antes de crear InputImage NV21.
No se concatenan planos YUV con padding sin convertirlos.

## Coordenadas, orientación y espejo

ML Kit recibe los grados de rotación de la imagen; sus puntos están en el espacio
orientado. Para 90/270 grados, tamanoOrientado intercambia ancho y alto originales.
No se vuelve a rotar cada punto: hacerlo duplicaría la transformación de ML Kit.

La proyección frontal es:

```
xPantalla = (anchoOrientado - xDetector) * anchoLienzo / anchoOrientado
yPantalla = yDetector * altoLienzo / altoOrientado
```

CustomPaint es hijo directo de CameraPreview, de modo que comparte la región de
imagen y no incluye las bandas negras externas. Al cambiar la orientación se
limpia la guía y se descarta la detección anterior que aún estuviera en proceso.
Las pruebas geométricas verifican el cálculo; la correspondencia con el sensor,
la vista previa nativa y el espejo debe validarse visualmente en el Android real.
No se afirma que la alineación física ya haya sido validada en esta fase.

## Ciclo de vida y asincronía

`Future<void>? _procesamiento` representa la detección en curso. No hay cola de
fotogramas: se omiten los que llegan mientras está ocupado. Así se limita memoria
y se evita acumular imágenes antiguas. No se fija una cuota de 20 FPS.

`_generacion` invalida resultados de una sesión de cámara previa. Antes de pausar:
se separa el controlador, se incrementa la generación, se detiene el stream,
se espera la detección pendiente, se cierra ML Kit y finalmente se libera la cámara.
Al volver, el servicio puede crear un detector nuevo. Al salir se impiden futuras
notificaciones. Esto evita cerrar ML Kit mientras procesa una imagen o dibujar un
resultado que llegó después de abandonar la pantalla.

Un error de detección borra contornos y muestra un mensaje; un fotograma posterior
válido permite recuperarse. Si persiste, se indica salir y volver al simulador.
El stream no implica captura guardada: los bytes se procesan en memoria.

## Permisos y privacidad

Se reutiliza android.permission.CAMERA, ya declarado y solicitado en fase 1.
Permite obtener fotogramas del rostro y es necesario para usar el simulador.
Si se rechaza o bloquea se conservan los estados y acciones de fase 1.
No se añaden permisos de audio, almacenamiento ni internet para la detección.
No se guardan fotos, puntos ni perfiles biométricos y no se suben a servicios externos.
Android es el alcance implementado; no se declara compatible la detección web/iOS.

## Verificación

La suite automatizada pasó 140 pruebas tras implementar la detección. Las cámaras
y el detector se simulan en los tests del ViewModel: eso no prueba ML Kit nativo.
Se ejecutan además flutter analyze --no-pub y compilación APK debug; sus resultados
finales se registran al terminar las comprobaciones.

El teléfono no estaba conectado al comprobar ADB. Pendiente en el Samsung:

- Entrar al simulador y ver búsqueda de rostro y después cuatro contornos verdes.
- Acercarse/alejarse y moverse suavemente para comprobar escala y alineación.
- Girar el dispositivo y verificar que la guía no quede desplazada o invertida.
- Salir del encuadre: el dibujo debe desaparecer y debe aparecer el aviso.
- Cubrir los labios o usar poca luz: comprobar el estado sin labios.
- Cambiar de aplicación y volver; salir/reentrar sin cámara bloqueada.
- Probar permisos denegados/bloqueados y cámara no disponible.

No se midieron FPS, memoria ni latencia en dispositivo. El objetivo de 20 FPS está
pendiente; tampoco se valida estabilidad para grandes giros ni maquillaje realista.
No hay commits ni push automáticos.

## Resultado automatizado final

- flutter analyze --no-pub: sin problemas tras retirar cuatro imports redundantes.
- flutter test --no-pub --reporter expanded: 140 pruebas aprobadas.
- El primer build APK debug falló porque el daemon Gradle desapareció; no se reportó error Dart. Se reintenta solo para android-arm64, con GRADLE_OPTS temporal: -Dorg.gradle.jvmargs=-Xmx2048m -Dorg.gradle.workers.max=2 -Dorg.gradle.parallel=false. No se modificó gradle.properties.
- No había Android conectado: prueba de alineación y rendimiento físico pendiente.


- Resultado del reintento: flutter build apk --debug --no-pub --target-platform android-arm64 completado correctamente (153,2 s). APK: build/app/outputs/flutter-apk/app-debug.apk. No instalado ni ejecutado en dispositivo en esta fase.


## Corrección observada en Samsung SM-A325M

Durante la prueba física apareció el aviso de error de detección. El diagnóstico
mostró `FormatException: El plano NV21 no está compactado`: fotograma 720x480,
formato 17, un plano de 541392 bytes. Su tamaño NV21 útil es 518400 bytes.
No era ausencia de labios: el conversor rechazaba la entrada antes de ML Kit.

Se inspeccionó `ImageProxyUtils.planesToNV21` de camera_android_camerax 0.7.5+1:
compacta las filas Y y los pares VU al principio de un byte[], pero lo reserva
usando el tamaño original Y con padding. Los bytes sobrantes quedan a cero.
Por eso el conversor ahora admite esa cola solo si todos sus bytes son cero y
crea una vista de los primeros width*height*3/2 bytes mediante sublistView.
No se deduce el row stride a partir del tamaño ni se cortan excedentes arbitrarios.
Un plano corto o con excedente no nulo sigue siendo un error explícito.

Se añadieron pruebas del caso 720x480/541392 bytes y del rechazo de excedentes
no nulos. El diagnóstico de consola registra excepciones y la transición a un
detector operativo, sin fotos ni coordenadas faciales. La primera prueba del
buffer compartido comparaba wrappers ByteBuffer por identidad; se corrigió
para comprobar realmente la memoria compartida modificando un byte del origen.

Al actualizar el teléfono hubo interrupciones ADB: algunos comandos de instalación
terminaron sin confirmación. Se comprobó por SHA256 que el APK de diagnóstico
instalado coincidía con el APK local; no se desinstaló la app ni se borraron datos.

Verificación del arreglo NV21: flutter analyze --no-pub sin problemas; suite completa con 142 pruebas aprobadas. APK compilado e instalado en el Samsung, con SHA256 instalado/local coincidente. Flutter perdió la conexión de depuración tras instalar; se abrió la app con ADB sin desinstalarla. La confirmación visual se registra cuando termine la nueva prueba del simulador.


Resultado nativo comprobado en Samsung: el proceso nuevo registró AR detector operativo: rostro=true, labios=true (11:34:45 y 11:35:14, hora local). La entrada ya supera la conversión y ML Kit devuelve rostro y los cuatro contornos completos. Esto no valida por sí solo la alineación visual, estabilidad ni FPS; esa observación queda pendiente de Mauricio.


## Seguimiento y medición de rendimiento

Mauricio observó retraso visible al mover el rostro en la versión debug. La
presencia de contornos no se considera suficiente para validar el seguimiento.

Se separó el estado de pantalla de las actualizaciones geométricas:

- El ViewModel publica los contornos en un ValueNotifier privado, expuesto como
  ValueListenable. La vista no puede escribirlo.
- ContornoLabiosPainter se suscribe mediante `super(repaint: fotogramas)` y lee
  el último resultado en paint. No necesita reconstruir Scaffold o CameraPreview
  en cada detección.
- notifyListeners de pantalla solo se utiliza cuando cambian carga, error,
  presencia de rostro/labios u orientación.
- Al cerrar se espera la liberación y luego se dispone el notificador, evitando
  escribir sobre un ValueNotifier ya eliminado durante un cierre asíncrono.

Una prueba verifica dos detecciones con geometría diferente y el mismo estado:
se reciben dos actualizaciones de dibujo, sin una segunda notificación de pantalla.
Al perder el rostro, sí se vuelve a notificar el estado.

Se instrumentó una ventana de 3 segundos tras 5 segundos de calentamiento:

- stream_fps: callbacks CameraImage que llegan a Dart por segundo.
- deteccion_fps: llamadas al detector completadas por segundo.
- media_ms y max_ms: duración entre recibir el fotograma seleccionado en Dart y
  recibir el resultado del servicio (conversión, canales y ML Kit incluidos).

Las métricas no son los FPS de la textura de cámara ni la latencia completa desde
el sensor hasta la pantalla. Tampoco incluyen una medición de CPU, batería o GPU.
No se añaden esperas ni se mantiene una cola de imágenes viejas. Los logs no
contienen imágenes ni coordenadas de la persona y se desactivan en release.

Se utiliza modo profile en el Samsung para medir sin la sobrecarga de ejecución
JIT de debug; no se cambia la arquitectura ni las dependencias. La comparación
visual del usuario y la frecuencia sostenida deben comprobarse antes de declarar
satisfecho el objetivo de 20 FPS. No hay una medición numérica de la versión previa,
por lo que no se afirmará un porcentaje de mejora.

Referencias:
https://docs.flutter.dev/perf/ui-performance
https://developers.google.com/ml-kit/vision/face-detection/android

Verificación del cambio de repintado: flutter analyze sin problemas; 143 pruebas
Flutter aprobadas. El resultado de las mediciones físicas se registra después de
abrir el simulador en la versión profile.

### Primera medición profile y segundo ajuste

Mauricio confirmó que la vista de cámara era fluida, pero la guía llegaba tarde.
Con el repintado independiente y el flujo NV21 anterior, el Samsung registró:

| Hora local | Callbacks/s | Detecciones/s | Media del servicio ms | Máximo ms |
|---|---:|---:|---:|---:|
| 11:48:26 | 18.3 | 8.3 | 86.1 | 159.0 |
| 11:48:29 | 16.2 | 7.3 | 104.1 | 271.6 |
| 11:48:32 | 17.8 | 6.6 | 111.9 | 159.6 |
| 11:48:35 | 21.9 | 8.4 | 90.4 | 119.1 |
| 11:48:38 | 10.7 | 5.2 | 169.5 | 282.4 |
| 11:48:41 | 14.9 | 8.6 | 71.2 | 212.9 |
| 11:48:52 | 22.7 | 12.2 | 51.7 | 127.5 |

Modo profile, Samsung SM-A325M. No son FPS de vista previa ni latencia total del
sensor a la pantalla. Son muestras de ventanas de ejecución con movimiento del
usuario, sin controlar luz o temperatura. El objetivo de 20 FPS no se cumplió.
Mauricio observó mejora, pero confirmó retraso todavía visible.

Por eso se hizo un segundo ajuste, sin cambiar dependencias:

- CameraController solicita ImageFormatGroup.yuv420 y fps:30. El plugin instalado
  aplica el rango solicitado al Preview de CameraX; no se garantiza que el hardware
  entregue 30 callbacks de análisis por segundo.
- Se reciben Y, U y V originales, evitando la llamada adicional a la conversión
  nativa getNv21Buffer y su buffer con excedente. El conversor aún admite NV21
  para compatibilidad y mantiene las pruebas del fallo Samsung.
- Las filas Y contiguas se copian con setRange. Se validan tamaños y strides antes
  de recorrer los planos; V y U se intercalan con índices incrementales.
- Se mantiene como máximo un fotograma pendiente. Cada llegada reemplaza al
  pendiente anterior. Cuando ML Kit termina se toma ese último disponible, sin
  esperar a que llegue otro y sin procesar una cola de imágenes antiguas.
- Pausa, cierre y cambio de orientación eliminan el pendiente. El conteo de
  callbacks se hace solo al recibirlos, no al drenar el pendiente.

La prueba nueva comprueba que, de tres fotogramas recibidos durante una detección,
se procesan el primero y el último. La prueba de pausa sigue comprobando que no
se procesa el pendiente al salir. Análisis limpio y 144 pruebas aprobadas.

El teléfono se desconectó antes de instalar este segundo ajuste. No se atribuyen
las cifras anteriores a la versión YUV nueva: falta medirla y confirmar su efecto.

El APK del segundo ajuste compiló correctamente con flutter build apk --profile --no-pub --target-platform android-arm64 (83,2 s). Está listo en build/app/outputs/flutter-apk/app-profile.apk. ADB seguía sin dispositivos: esta versión todavía no fue instalada ni medida en el Samsung.

