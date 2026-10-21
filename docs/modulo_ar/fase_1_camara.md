# Fase 1: cámara frontal y permisos

Fecha: 21 de octubre de 2026. Rama: feature/ar.

## Alcance implementado

La ruta autenticada `/simulador-ar`, accesible desde Home, muestra la cámara frontal.
Incluye carga, permiso denegado, permiso bloqueado, ausencia de cámara frontal,
error con reintento y pausa. No hay detección facial, labial, captura, guardado ni
subida de imágenes en esta fase. Escáner y Armario quedan fuera del trabajo.

## Archivos y responsabilidades

- `lib/ui/simulador_ar/simulador_ar_view.dart`: pantalla, CameraPreview y observación del ciclo de vida.
- `lib/ui/simulador_ar/simulador_ar_view_model.dart`: estados, permiso, selección frontal, controlador y liberación.
- `lib/core/routes/app_router.dart`: sustituye el destino en construcción por SimuladorArView, conservando la guardia autenticada.
- `lib/core/constants/app_strings.dart`: textos en español propios del módulo.
- `test/simulador_ar/simulador_ar_view_model_test.dart`: pruebas con permisos y cámaras simulados, sin hardware ni Firebase.

No se cambian servicios compartidos ni módulos de colorimetría. El estado pertenece
a una pantalla, por eso su ChangeNotifierProvider se crea en la vista y no en
app_providers.dart. No se necesita repositorio: todavía no se persisten datos.

## Dependencias

Se reutilizan camera 0.12.1, permission_handler 13.0.2 y provider existentes.
No se cambia pubspec.yaml ni se agregan dependencias. Los cambios anteriores de
pubspec.lock y analysis_options.yaml pertenecían al árbol de trabajo previo.
SDK local según su metadata: Flutter 3.47.0 y Dart 3.13.0.

## Flujo de ejecución y MVVM

1. Home navega a AppRoutes.simuladorAr; la guardia existente comprueba acceso.
2. SimuladorArView obtiene PermisosService con context.read y construye su ViewModel.
3. Future.microtask(vm.iniciar) difiere la inicialización para evitar notificar durante el build.
4. iniciar encola la operación; pedirCamara devuelve un EstadoPermiso.
5. Si se concede, availableCameras lista dispositivos. Solo se acepta CameraLensDirection.front.
6. CameraController usa ResolutionPreset.medium y enableAudio: false.
7. initialize termina de forma asíncrona. El estado lista provoca la reconstrucción y CameraPreview muestra la cámara.
8. Al pasar a inactive, hidden, paused o detached se solicita liberar el controlador.
9. Al volver a resumed se reabre si corresponde. Un permiso denegado requiere reintento explícito para evitar otro diálogo automático.
10. Al salir, Provider llama dispose: se marca el modelo como cerrado y se encola la liberación pendiente.

La vista usa context.watch para reconstruirse al recibir notifyListeners.
Los callbacks onPressed son referencias a métodos del ViewModel: se ejecutan al
pulsar, no al construir el widget.

## Asincronía y protección de recursos

Future representa una operación que termina después. async/await permite esperar
al permiso o al hardware sin bloquear el hilo de interfaz. `_cola` encadena estas
operaciones: cerrar no puede adelantarse a una inicialización pendiente.

`_activa` registra si la aplicación está en primer plano. `_cerrado` evita nuevas
operaciones y notificaciones después de dispose. `_liberar` separa primero el
controlador del estado y luego espera su dispose, para no conservar una referencia
a una cámara cerrada. `cerrar()` permite esperar esa limpieza en pruebas; dispose
la solicita mediante unawaited porque el contrato de Flutter es síncrono.

La fábrica crearControlador y listarCamaras se pueden inyectar por constructor.
En producción usan el plugin; en pruebas usan objetos falsos. Esto es inyección
de dependencias y permite probar fallos y carreras sin necesitar cámara física.

Ejemplo del controlador real:

```dart
CameraController(
  descripcion,
  ResolutionPreset.medium,
  enableAudio: false,
);
```

No se establece streaming en esta fase. La resolución es una preferencia que el
plugin negocia con el hardware, no una garantía de FPS.

## Permiso Android

- Nombre: android.permission.CAMERA.
- Declaración: android/app/src/main/AndroidManifest.xml, ya existente y sin cambios.
- Solicitud: al entrar o reintentar, mediante PermisosService.pedirCamara.
- Uso: acceso a los fotogramas de la cámara frontal para la vista previa.
- Rechazo: EstadoVacio con explicación y botón para volver a solicitar.
- Bloqueo permanente: botón para abrir ajustes; al regresar se comprueba de nuevo.
- Es necesario para usar el simulador, pero no para navegar por otras pantallas.
- No se solicita micrófono, galería ni ubicación. enableAudio está desactivado.

No se guardan imágenes ni se envían a Firebase o servicios externos.

## Verificación y limitaciones

Las pruebas cubren rechazo y bloqueo de permiso sin acceder al hardware, ausencia
de cámara frontal, pausa y regreso, cierre durante inicialización, recuperación
tras error de permisos, rechazo durante el diálogo e inicialización fallida.
Las cámaras falsas no prueban la cámara nativa ni la vista previa real.

La primera ejecución de flutter analyze detectó un constructor incorrecto de la
cámara falsa y falta de super.dispose en ese doble de prueba. Se corrigieron
ambos problemas. Se ejecutó una suite inicial de 102 pruebas satisfactoria;
la verificación final tras ampliar casos se registra abajo.

ADB no reportó dispositivos conectados. Pendiente ejecutar en emulador o Android
físico: conceder/rechazar/bloquear permiso, volver de ajustes, entrar y salir,
cambiar de aplicación y orientación y comprobar proporciones de vista previa.
No se midieron FPS ni memoria. El objetivo de 20 FPS todavía no está validado.
No se compiló APK ni se ejecutó flutter run durante esta fase.

Antes de detección facial se debe verificar rotación, espejo, formato de bytes
y correspondencia entre la vista previa y coordenadas. iOS no forma parte de la
validación: la app solo tiene Firebase configurado para Android y web. El simulador
tampoco tiene una validación web realizada.

## Resultado final automatizado

- flutter analyze --no-pub: sin problemas.
- flutter test --no-pub --reporter expanded: 104 pruebas aprobadas, incluidas siete del ViewModel AR.
- git diff --check: sin errores de espacios en los cambios rastreados; continúan los avisos previos LF/CRLF en archivos generados.
- Sin commits, push, cambios de rama ni subida de imágenes.

