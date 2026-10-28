# Simulador inteligente AR — diagnóstico y plan

Fecha: 28 de octubre de 2026. Entrega: 29 de octubre. Rama: feature/ar, base 6889f08.

## Estado inicial verificado

Existe una sola sesión de cámara frontal, permiso, control de ciclo de vida, conversión YUV420/NV21 probada en Samsung, rotación y espejo. ML Kit Face Detection devuelve únicamente cuatro curvas de labios al modelo AR. Un CustomPainter pinta un único labial semitransparente. El repintado utiliza ValueNotifier y solo se conserva el último fotograma pendiente. Web permite vista previa sin reconocimiento.

MaquillajeArViewModel mantiene un producto y una intensidad global; ProductoProvider filtra por estación y la vista solo ofrece labiales. No hay estado de looks ni mezcla de categorías. RecomendacionProvider ya une recomendaciones con productos activos de Firestore y calcula un respaldo local con datos reales del catálogo cuando la función no está desplegada. ColorimetriaProvider conserva el perfil real. Se reutilizarán esos contratos; no se generarán productos de ejemplo en producción.

El catálogo declara cuatro categorías (labial, rubor, sombra, base), colorHex, tono y acabado. No contiene texturas, rugosidad, cobertura, pigmentación medida ni máscaras por producto. Hay captura PNG privada por cuenta, pero no compartir ni una descripción de todas las capas en la captura. Los últimos FPS físicos documentados en la conversación eran inferiores a 20; no hay medición del prototipo nuevo. ADB no detecta el Samsung al iniciar esta tarea.

Hay una modificación previa en test/asistente/asistente_test.dart (import del helper). Se respaldó y se conservará. Sin commits, push, stash ni cambios de rama automáticos.

## Evaluación técnica

| Tecnología | Ventajas para este proyecto | Coste / limitación | Decisión |
|---|---|---|---|
| ML Kit Face Detection | Ya integrado, contornos 2D y conversión comprobada; alternativa sin migrar cámara | Geometría escasa; la versión anterior tuvo retraso; no habilitar tracking ID junto con contornos | Conservar como alternativa funcional |
| ML Kit Face Mesh | 468 puntos 3D, misma entrada InputImage, SDK Android 23+, modelo empaquetado; adecuado para efectos de selfie | Beta, sin soporte web; rendimiento Samsung no medido; adaptador Flutter comunitario | Principal Android del prototipo, con alternativa ante fallo del SDK |
| MediaPipe Face Landmarker | 478 puntos, seguimiento temporal, suavizado con un rostro, matrices y blendshapes; mejor base futura para expresiones y otras plataformas | Otro modelo y canal nativo/GPU que habría que integrar y validar antes de mañana | Interfaz de detector sustituible; migración posterior, sin prometer integración completada |

Las cifras de latencia publicadas por Google corresponden a sus dispositivos y no equivalen a FPS del Samsung. La aceptación de >=20 FPS queda sujeta a medición física en profile.

Fuentes primarias consultadas:
- https://developers.google.com/ml-kit/vision/face-detection/android
- https://developers.google.com/ml-kit/vision/face-mesh-detection
- https://developers.google.com/ml-kit/vision/face-mesh-detection/android
- https://developers.google.com/edge/mediapipe/solutions/vision/face_landmarker/android
- https://pub.dev/packages/google_mlkit_face_mesh_detection (adaptador, no mantenido por Google)
- https://pub.dev/packages/share_plus

## Arquitectura propuesta

~~~mermaid
flowchart LR
  PERFIL[ColorimetriaProvider] --> REC[RecomendacionProvider existente]
  CAT[ProductoProvider / catálogo real] --> VM[MaquillajeArViewModel]
  REC --> LOOKS[Compositor de looks]
  LOOKS --> VM
  VM --> CAPAS[Mapa de capas por categoría]
  CAM[Una CameraController] --> DET[Detector sustituible Mesh / Detection]
  DET --> GEO[Regiones faciales y coordenadas]
  GEO --> RENDER[Pintor común de capas]
  CAPAS --> RENDER
  RENDER --> CAPTURA[Captura privada y compartir voluntario]
~~~

Reconocimiento, geometría, composición de looks, selección y renderizado son piezas separadas. El cambio entre recomendado y libre no crea otra cámara. La lista de capas y sus ajustes son inmutables; cambiar o quitar una categoría conserva las otras. El orden de renderizado no depende del orden de selección.

Los looks son combinaciones deterministas de las recomendaciones reales por categoría, filtradas por compatibilidad de estación/subtono. Se muestran como Combinación 1, 2, etc., sin inventar recomendaciones semánticas de fiesta o noche. Si faltan categorías, se indica que el look es parcial; si no hay datos, se muestra vacío y reintento. El modo libre usa todos los productos activos con color válido, incluidos los no recomendados, y conserva ambos modos sobre el mismo motor.

## Plan priorizado

1. Estado por capas y compositor: catálogo real, modo recomendado/libre, cambios y borrado individual, limpieza total, invalidación al cambiar sesión/perfil. Pruebas con Firestore falso y datos exclusivamente de prueba.
2. Geometría: adaptador Face Mesh y alternativa Detection ampliada a ojos, cejas, mejillas y óvalo; conservar NV21 y transformaciones comprobadas. Pérdida del rostro y resultados antiguos no deben dejar maquillaje pegado a una posición.
3. Renderizado: labial + rubor + sombra simultáneos, máscaras por región, exclusión de ojos/boca, bordes difuminados, mezcla y límites de opacidad. Brillo/cejas y base solo como aproximaciones declaradas si se habilitan; delineador, pestañina, corrector, iluminador y contorno quedan en el registro extensible sin fingir realismo ni aplicar efectos no implementados.
4. UI: looks, selector por categoría, lista de capas con nombre/producto/tono, intensidad y acabado visual cuando exista, quitar capa, limpiar y comparar original. Captura y compartir con todas las capas.
5. Verificación: pruebas de no invención de datos, composición y edición, sesión/perfil, espejo/rotación/escala, máscaras fuera de regiones, exclusión de ojos/boca, expiración, métricas. flutter analyze, flutter test y APK profile arm64. Medición Samsung de >=30 s tras calentamiento: FPS de procesamiento válidos, p50/p95 y tiempo de pintado; reportar el resultado real, aunque sea inferior a 20.

## Evolución compatible del catálogo

No se modifican documentos ni reglas de Firestore automáticamente. Propuesta: campo opcional visualAr={version:1, motor, opacidadInicial, cobertura, suavizadoRelativo, acabadosDisponibles, rugosidad, texturaUrl}. La ausencia de parámetros usa límites conservadores del prototipo y se informa como aproximación. Texturas y parámetros de delineador/pestañas requieren activos y validación; el actual colorHex no basta para afirmar fidelidad del producto. Nuevas categorías necesitarán coordinación con administración, validadores y reglas; el registro AR ya puede reservarlas sin reconstruir la pantalla.

## Criterio de salida

Una cuenta con análisis y recomendaciones multiclase puede aplicar un look de productos reales, observar las categorías soportadas a la vez y sustituir una sin alterar las demás. En libre puede elegir un producto de otra estación. Si no existe esa información real, se presenta su ausencia. Las capturas se hacen solo por acción del usuario; compartir abre el diálogo del sistema y nunca envía automáticamente a terceros. La calidad visual, la captura de la textura de cámara y los FPS requieren confirmación en el Samsung.
