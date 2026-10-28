# Prototipo AR por capas — verificación y demostración

28 de octubre de 2026. Proyecto: C:\proyectos\ProjectMake-UpAi. Rama: feature/ar. No se hicieron commits ni push.

## Resultado implementado

| Función | Estado del prototipo |
|---|---|
| Looks personales | Se consume RecomendacionProvider y se une con el catálogo activo actual. Se filtra la estación y el subtono cuando está especificado. Las combinaciones son deterministas y solo contienen productos que realmente existen. |
| Datos insuficientes | Look parcial o vacío. No se inyectan mocks ni se completan categorías con productos inventados. Un fallo de carga permite reintentar o cambiar a libre. |
| Prueba libre | Todos los productos activos con tono válido; permite elegir productos de otras estaciones. Las categorías sin renderizador se muestran como no implementadas. |
| Aplicación simultánea | Mapa de capas por categoría, con orden fijo. Un look se aplica de forma atómica; sustituir, quitar o ajustar una capa conserva el resto. |
| Labial, rubor y sombra | Máscaras dinámicas con bordes suaves y transparencia. Se protege la abertura de la boca y el interior de los ojos. El rubor y la sombra se recortan al óvalo facial. |
| Base, cejas y brillo | Representaciones aproximadas, disponibles únicamente si el catálogo contiene esos productos. Base es un velo de color, no cobertura ni reconstrucción real de piel. Cejas es un tinte y brillo una variación visual sencilla. |
| Delineador, pestañina, corrector, iluminador, contorno | Reservados en el registro extensible; no se aplican ni se presentan como realistas. Requieren parámetros/activos y renderizadores específicos. |
| Reconocimiento | Face Mesh principal en Android; Face Detection alternativo solo ante fallo del SDK. Ambos producen el mismo modelo de regiones. La pérdida de rostro no cambia artificialmente de motor. |
| Transformaciones | Rotación de la entrada del detector y proyección orientada sobre el mismo CameraPreview; espejo frontal una sola vez y escala al lienzo sin recorte independiente. |
| Cámara | Una sola CameraController para los dos modos y todas las capas. No se abre otra al cambiar look, categoría o intensidad. |
| Capturas | PNG privado por cuenta con descripción de productos y metadatos de todas las capas (id, categoría, tono, HEX, intensidad, acabado y original). Compatibilidad con capturas antiguas conservada. |
| Compartir | Acción explícita tras capturar o desde Mis pruebas de maquillaje. Abre el diálogo del sistema mediante share_plus; no envía nada automáticamente. |
| Web | Conserva vista previa de webcam, selección, looks y Armario. La detección, maquillaje sobre vídeo y captura AR de este motor siguen siendo Android. |

Los colores se componen con srcOver para mezclar transparencia de forma predecible sobre CameraPreview. No se afirma que multiply o color modifiquen los píxeles de la cámara desde una capa transparente separada. Los degradados y el difuminado son recursos visuales aproximados, no una medición física del acabado de cada producto.

## Archivos principales

- lib/models/maquillaje_ar.dart: capas, looks, registro de categorías y candidatos inmutables.
- lib/data/services/compositor_looks_ar.dart: composición sin acceso a Firebase ni dependencia de providers.
- lib/ui/simulador_ar/maquillaje_ar_view_model.dart: catálogo, perfil/recomendaciones, modos y edición individual.
- lib/data/services/malla_facial_ar_service.dart: adaptador de Face Mesh y alternativa de detección.
- lib/models/deteccion_facial_ar.dart: regiones faciales comunes, malla y transformaciones.
- lib/ui/simulador_ar/motor/geometria_maquillaje_ar.dart: construcción y recorte de máscaras.
- lib/ui/simulador_ar/widgets/pintor_maquillaje_ar.dart: renderizado común de todas las capas.
- lib/ui/simulador_ar/simulador_ar_view_model.dart: cámara, último fotograma pendiente, caducidad y métricas.
- lib/data/services/compartir_ar_service.dart: diálogo de compartir.

Para añadir otro producto que utilice una región existente basta registrar su categoría y definición. Para una región nueva se añade su generador de máscara y estilo; no hay que reconstruir la cámara, los modos ni el selector. Las categorías globales de administración y sus reglas deben evolucionar con el equipo: el registro de AR no cambia automáticamente el esquema del catálogo.

## Parámetros faltantes en el catálogo

Actualmente se usan colorHex y acabado, junto con opacidad conservadora por categoría. El campo visualAr descrito en el diagnóstico es una **propuesta de evolución**, no un campo ya implementado ni leído por este prototipo. Para incorporarlo habría que extender fromMap, toMap, copyWith, formularios y validadores sin perder compatibilidad. No se modificaron documentos ni reglas de Firestore.

## Verificación automática

- Primera etapa: pruebas de composición sin inventar datos y edición independiente de tres capas.
- Segunda etapa: pruebas de exclusión de ojos/boca, movimiento, escala, espejo y pintura conjunta comprobada por píxeles.
- Contrato del adaptador: conversión de formato, rotación, regiones y profundidad desde el canal simulado de Face Mesh; alternativa ante fallo del SDK y ausencia de cambio de motor cuando no hay rostro. Estas pruebas no sustituyen ejecutar el SDK en un teléfono.
- Interfaz a 360 px: elegir un look de tres productos, quitar una sombra y cambiar el labial por uno no recomendado sin quitar el rubor.
- Captura y sesión: registra todas las capas, compartir exige otra acción y una cuenta distinta no conserva la última captura de la anterior.
- Integridad: un perfil nuevo durante una carga descarta la respuesta vieja y recarga candidatos compatibles; productos desaparecidos del catálogo no se fabrican.
- Seguimiento: resultados de más de 200 ms desde la llegada al proceso Dart se descartan; si no llega otro resultado útil, las coordenadas caducan tras 250 ms.
- Suite completa final: **214 pruebas aprobadas**.
- flutter analyze: sin problemas en la última comprobación.
- Compilación Android ARM64 profile: aprobada. APK: build/app/outputs/flutter-apk/app-profile.apk (104,6 MB).
- Compilación web release: aprobada, salida build/web. Mantiene vista previa sin maquillaje AR.
- Ambas compilaciones finalizaron con código 0; no equivalen a una prueba visual en el Samsung.

La modificación previa de test/asistente/asistente_test.dart se conservó, sin incluirla en un commit automático.

## Recorrido de demostración

1. Inicia sesión con una cuenta que tenga análisis de colorimetría y productos activos en el catálogo. Un análisis guardado debe pertenecer al uid de la cuenta actual.
2. Abre Simulador AR. En Looks para mí selecciona Combinación 1. Para demostrar tres productos, las recomendaciones reales deben contener al menos labial, rubor y sombra compatibles; si falta algo, se indicará que es parcial.
3. Comprueba las capas aplicadas y sus nombres/tonos. Toca la capa Rubor y ajusta su intensidad. El labial y la sombra deben conservarse.
4. Borra la sombra desde su capa. Cambia a Prueba libre, elige Labial y selecciona otro tono, incluso de otra estación. El rubor debe permanecer.
5. Compara Ver original / Ver maquillaje. Quitar todo debe retirar todas las capas.
6. Con el rostro detectado y maquillaje aplicado, captura. Consulta el resultado desde Armario → Mis pruebas de maquillaje. Compartir debe abrir el diálogo del sistema; solo se comparte si el usuario elige un destino.
7. Cambia la orientación, sal y regresa a la app. Comprueba alineación, ausencia de cámara duplicada y recuperación. Oculta el rostro para verificar que los efectos desaparecen.

## Medición pendiente en Samsung

ADB no detectó el teléfono y Mauricio indicó que lo conectaría después. **No hay una medición de FPS nueva ni una validación visual física de este prototipo.** La calidad de ajuste, oclusiones, captura de la textura de cámara y compartir requieren esa prueba.

1. Conecta el Samsung SM-A325M, desbloquéalo y comprueba flutter devices.
2. Ejecuta flutter run --profile -d RF8TA14F6BW desde la carpeta del proyecto. No evalúes velocidad con debug.
3. Aplica labial + rubor + sombra. Espera al menos 8 segundos para completar calentamiento y primera ventana.
4. Abre el icono de velocímetro. Durante 30 segundos mantén el rostro visible y haz movimientos suaves, después giros y gestos habituales. Repite con buena luz y una escena más exigente.
5. Registra motor, entrada de fotogramas, detecciones procesadas/s, detecciones válidas/s, p50/p95 de procesamiento y coste CPU del pintor. La meta es >=20 detecciones válidas/s de forma sostenida, junto con una superposición visual estable; que la cámara solicite 30 fps no demuestra esa meta.
6. Comprueba la calidad observando el vídeo y una captura. El tiempo CPU de pintura no es tiempo GPU ni latencia total de sensor a pantalla. La edad medida parte de la llegada a Dart: no existe timestamp del sensor expuesto por este flujo.
7. Registra los valores reales, aunque estén por debajo de la meta. Si no se alcanza: medir primero el coste de la serialización de malla (el adaptador transfiere triángulos que este renderizador no utiliza), conversión y detector antes de introducir otro motor o reducir resolución por debajo de las recomendaciones del SDK.

| Escenario | Detecciones válidas/s | p50 | p95 | Pintura CPU | Calidad visual |
|---|---|---|---|---|---|
| Labial + rubor + sombra | Sin medir | Sin medir | Sin medir | Sin medir | Pendiente en Samsung |
| Movimiento y giro | Sin medir | Sin medir | Sin medir | Sin medir | Pendiente en Samsung |

## Límites de entrega

Este es un prototipo 2D guiado por regiones de una malla facial, no un motor de maquillaje físicamente realista equivalente a TikTok o Instagram. No utiliza texturas específicas de cada producto ni segmentación de cabello/manos. El motor solo muestra una cara prominente. Face Mesh y su adaptador Flutter requieren Android y el SDK sigue en beta. La interfaz conserva estados vacíos, errores y reintento; no presenta datos de prueba como recomendaciones personales.
