# MAKE UP AI

App móvil de colorimetría y asesoría de imagen construida con **Flutter + Firebase**.
Proyecto de la materia Programación Móvil — Universidad Popular del Cesar.

| Integrante | Rol | Módulo |
|---|---|---|
| Karlos Quintero | DEV 4 | Base de la app: Core, Auth, Home y Perfil |
| Jaider Monrroy | — | Colorimetría, paleta y servicios compartidos |
| Ana Cuellar | — | IA, recomendaciones, asistente y catálogo |
| Mauricio Parra | — | Simulador AR, escáner y armario |

---

## Puesta en marcha

```bash
flutter pub get
flutter run
```

- Flutter 3.44 (canal stable) / Dart 3.12.
- Proyecto Firebase: `make-up--ai` (Android y web configurados en `lib/firebase_options.dart`).
- **Windows:** activa el *Modo de desarrollador* (`start ms-settings:developers`); los plugins de Flutter lo necesitan para compilar.

---

## Reglas del equipo

1. **Un solo dueño por carpeta/archivo.** Nadie edita archivos de otro. Si necesitas un cambio en código ajeno, pídeselo a su dueño.
2. **Una rama por módulo** y pull request hacia `develop`. **Nunca** se hace commit directo a `main` ni a `develop`.
3. **Arquitectura de capas sin saltos** (ver abajo). Las vistas nunca llaman a Firebase.
4. **Todos los textos de UI en español** dentro de `lib/core/constants/app_strings.dart`.
5. **Cada pantalla cubre** los estados de carga (`IndicadorCarga`), vacío (`EstadoVacio`) y error con reintento (`MensajeError`) usando los widgets de `core/widgets`.
6. **Antes de abrir un PR:** `flutter analyze` sin errores.
7. **Si dependes de un módulo que aún no existe**, usa datos mock controlados por banderas en `lib/core/constants/app_constants.dart`.

---

## Flujo de ramas y pull requests

```
main      ← versión estable (solo recibe merges desde develop)
develop   ← integración del equipo (solo recibe PRs)
feature/core, feature/auth, feature/home, feature/perfil   ← Karlos
feature/colorimetria, ...                                  ← Jaider
feature/recomendaciones, feature/asistente, ...            ← Ana
feature/simulador-ar, feature/escaner, feature/armario     ← Mauricio
```

1. Actualiza `develop`: `git checkout develop && git pull`.
2. Crea o actualiza tu rama: `git checkout -b feature/<modulo>` (o `git merge develop` sobre tu rama).
3. Commits pequeños con mensaje claro en español: `feat(auth): agrega verificación de correo`.
   Prefijos: `feat`, `fix`, `refactor`, `docs`, `build`, `chore`, `test`.
4. `flutter analyze` sin errores.
5. Abre un PR hacia `develop` describiendo **qué hiciste y qué sigue**. Otro integrante lo revisa antes del merge.

---

## Arquitectura de capas

```
View  →  ViewModel  →  Provider  →  Repository / Service  →  Firebase
```

| Capa | Responsabilidad | Ejemplo |
|---|---|---|
| **View** | Solo dibuja y reenvía eventos. Nunca importa Firebase. | `LoginView` |
| **ViewModel** | Lógica y estado de **una** pantalla (`ChangeNotifier`). | `AuthViewModel` |
| **Provider** | Estado **compartido** entre pantallas (sesión, usuaria, perfil). | `AuthProvider` |
| **Repository** | Único que habla con Firestore / Firebase Auth. | `UsuariaRepository` |
| **Service** | Envuelve Storage, permisos, Cloud Functions y notificaciones. | `NotificacionesService` |
| **Model** | Datos inmutables con `fromMap` / `toMap` / `copyWith`. | `Usuaria` |

Los providers globales se registran **solo** en `lib/providers/app_providers.dart`.
Cada integrante agrega los suyos en **su propia lista** (`_core`, `_colorimetria`, `_inteligenciaArtificial`, `_realidadAumentada`) para evitar conflictos.

---

## Nomenclatura

- **Archivos:** `snake_case` en español → `editar_perfil_view.dart`.
- **Clases:** `PascalCase` con sufijo del rol → `LoginView`, `AuthViewModel`, `AuthRepository`, `StorageService`, `UsuariaProvider`.
- **Variables y métodos:** `camelCase` en español → `iniciarSesion()`, `cargando`.
- **Rutas:** constantes en `AppRoutes` (`AppRoutes.perfil`); nunca strings sueltos.

---

## Estructura de carpetas y dueños

> Las entradas marcadas *(por confirmar)* se definen en el kickoff.

```
lib/
├── main.dart, app.dart, firebase_options.dart        Karlos
├── core/                                             Karlos
│   ├── constants/   app_strings, app_constants, app_assets
│   ├── errors/      app_exception, firebase_error_mapper
│   ├── extensions/  context, datetime, enum_labels
│   ├── routes/      app_routes, app_router
│   ├── theme/       app_colors, app_gradients, app_text_styles, app_theme
│   ├── utils/       validators, formatters, color_utils, image_utils, snackbar_helper
│   └── widgets/     13 widgets reutilizables (ver "Guía de uso de core")
├── models/
│   ├── usuaria, sesion, credencial                   Karlos
│   ├── perfil_colorimetria, paleta                   Jaider
│   ├── producto_maquillaje, prenda_ropa,
│   │   recomendacion, conversacion                   Ana
│   ├── prenda_analizada, armario_item                Mauricio
│   └── enums, model_utils, models (barril)           (por confirmar)
├── data/
│   ├── repositories/
│   │   ├── auth, usuaria, sesion, credencial         Karlos
│   │   ├── colorimetria                              Jaider
│   │   ├── catalogo                                  Ana
│   │   └── escaner                                   Mauricio
│   └── services/
│       ├── notificaciones_service                    Karlos
│       └── storage, permisos, cloud_functions        Jaider
├── providers/
│   ├── app_providers, auth, usuaria, sesion          Karlos
│   └── (cada integrante agrega los suyos)
└── ui/
    ├── splash, auth, home, perfil                    Karlos
    ├── colorimetria (incluye paleta)                 Jaider
    ├── recomendaciones, asistente                    Ana
    ├── admin                                         Ana (por confirmar)
    └── simulador_ar, escaner, armario                Mauricio
functions/                                            Ana (por confirmar)
```

---

## Banderas de desarrollo (`app_constants.dart`)

| Bandera | Valor inicial | Quién la cambia | Efecto |
|---|---|---|---|
| `usarMockColorimetria` | `true` | Jaider | Home/Perfil usan un perfil de ejemplo hasta que exista `ColorimetriaProvider`. |
| `usarMockRecomendaciones` | `true` | Ana | Home usa recomendaciones de ejemplo hasta que exista `RecomendacionProvider`. |
| `usarMockEliminarCuenta` | `true` | Ana | Simula la Cloud Function `eliminarCuenta` hasta que esté desplegada. |
| `escanerHabilitado` | `false` | Mauricio | Habilita el acceso al Escáner en Home. |
| `armarioHabilitado` | `false` | Mauricio | Habilita el acceso al Armario en Home. |
| `versionConsentimiento` | `'1.0'` | Karlos | Versión del aviso de privacidad aceptado al registrarse. |

---

## Guía de uso de core (no dupliques nada de esto)

Antes de crear un widget, validador o helper, revisa si ya existe aquí.
Si necesitas algo que falta o un cambio en core, pídeselo a Karlos.

### Widgets (`lib/core/widgets/`)

| Widget | Para qué | Ejemplo |
|---|---|---|
| `BotonPrimario` | Acción principal (degradado). `cargando` muestra spinner; `onPressed: null` lo deshabilita. | `BotonPrimario(texto: AppStrings.confirmar, cargando: vm.cargando, onPressed: vm.guardar)` |
| `BotonSecundario` | Acción secundaria blanca con icono. | `BotonSecundario(texto: ..., icono: Icon(Icons.share), onPressed: ...)` |
| `CampoTexto` | Campo con etiqueta, `validator`, `icono`, `onChanged`. | `CampoTexto(etiqueta: AppStrings.correoElectronico, icono: Icons.mail_outline, validator: Validadores.correo)` |
| `CampoContrasena` | Contraseña con mostrar/ocultar. | `CampoContrasena(controller: c, validator: Validadores.contrasena)` |
| `GradienteFondo` | Fondo de pantalla con degradado. | `GradienteFondo(gradient: AppGradients.fondoSuave, child: ...)` |
| `TarjetaBase` | Tarjeta blanca con radio, sombra y `onTap`. | `TarjetaBase(onTap: ..., child: ...)` |
| `AvatarUsuaria` | Foto circular o iniciales. `mostrarEditar` agrega cámara. | `AvatarUsuaria(nombre: s.nombreVisible, fotoUrl: s.fotoUrl, radio: 40)` |
| `DialogoConfirmacion` | Confirmar acciones; `destructiva` pinta en rojo. Devuelve `bool`. | `if (await DialogoConfirmacion.mostrar(context, titulo: ..., mensaje: ..., destructiva: true)) ...` |
| `EstadoVacio` | Lista/pantalla sin datos, con botón opcional. | `EstadoVacio(icono: Icons.checkroom, titulo: ..., textoBoton: ..., onPressed: ...)` |
| `MensajeError` | Error con botón "Reintentar". | `MensajeError(mensaje: vm.error!, onReintentar: vm.cargar)` |
| `IndicadorCarga` | Spinner centrado; `.pantalla()` incluye `Scaffold`. | `IndicadorCarga(mensaje: AppStrings.cargando)` |
| `EtiquetaEstacion` | Chip con color e icono de la estación. | `EtiquetaEstacion(estacion: EstacionColor.invierno, texto: 'Invierno frío')` |
| `PaletaChips` | Círculos de color; seleccionables con `onSeleccionar`. | `PaletaChips(colores: hexes.map(ColorUtils.desdeHex).toList())` |

**Patrón obligatorio de estados en cada pantalla:**

```dart
if (vm.cargando) return const IndicadorCarga();
if (vm.error != null) return MensajeError(mensaje: vm.error!, onReintentar: vm.cargar);
if (vm.items.isEmpty) return const EstadoVacio(titulo: AppStrings.estadoVacioTitulo);
return ListView(...);
```

### Utils (`lib/core/utils/`)

| Archivo | Uso |
|---|---|
| `validators.dart` | `Validadores.correo`, `.contrasena`, `.nombre`, `.obligatorio`, `.confirmarContrasena(() => c.text)` |
| `formatters.dart` | `Formateadores.precio(45900)` → `$ 45.900`, `.iniciales`, `.primerNombre`, `.capitalizar` |
| `color_utils.dart` | `ColorUtils.desdeHex('#E75480')`, `.aHex(color)`, `.colorTextoSobre(fondo)` |
| `image_utils.dart` | `await ImageUtils.prepararParaSubir(bytes)` → JPEG de máx. 1080 px (usar antes de subir a Storage) |
| `snackbar_helper.dart` | `SnackbarHelper.exito(context, msg)`, `.error(...)`, `.info(...)` |

### Extensiones (`lib/core/extensions/`)

- `context_extensions.dart`: `context.irA(AppRoutes.paleta)`, `context.reemplazarCon(...)`, `context.irYLimpiarHistorial(...)`, `context.volver()`, `context.argumentos<String>()`, `context.anchoPantalla`, `context.esPantallaPequena`, `context.ocultarTeclado()`.
- `datetime_extensions.dart`: `fecha.fechaLegible` (`4 de octubre de 2026`), `.fechaCorta`, `.hora`, `.tiempoRelativo` (`Hace 5 min`).
- `enum_labels.dart`: `estacion.etiqueta`, `estacion.color`, `subtono.etiqueta`, `tipo.etiqueta`, `EtiquetasTexto.ocasion(clave)`, `EtiquetasTexto.categoria(clave)`. **Nunca muestres `enum.name` en la UI.** Cada integrante agrega sus extensiones en su sección del archivo.

### Errores (`lib/core/errors/`)

- En el ViewModel: `catch (e) { _error = FirebaseErrorMapper.mensaje(e); }` — traduce errores de Auth, Firestore, Storage, Functions y Google.
- En repositorios/servicios, para errores de negocio: `throw const AppException(AppStrings.miMensaje);`.

### Sesión y usuaria actual (`lib/providers/`)

Lee siempre `SesionProvider` (nunca `FirebaseAuth.instance` desde una vista o ViewModel):

```dart
final sesion = context.watch<SesionProvider>();
sesion.uid;            // uid de la usuaria con sesión
sesion.nombreVisible;  // para saludos
sesion.usuaria;        // documento usuarias/{uid} (modelo Usuaria)
sesion.esAdmin;        // rol admin
```

> ⚠️ `firebase_auth` también exporta una clase llamada `AuthProvider`. Si un archivo
> necesita ambos, importa Firebase con `show` (p. ej. `import 'package:firebase_auth/firebase_auth.dart' show User;`).

### Rutas (`lib/core/routes/`)

- Todas las pantallas ya tienen constante en `AppRoutes` y entrada en `AppRouter`.
- Mientras tu vista no exista, la ruta muestra "En construcción". Para conectarla busca el comentario `CONECTAR (tu nombre)` en `app_router.dart`.
- Las protecciones son automáticas: sin sesión → login; correo sin verificar → verificar correo; rutas `/admin/...` solo con rol `admin`.
- Para pasar datos: `context.irA(AppRoutes.detalleProducto, argumentos: producto.id)` y en la vista `context.argumentos<String>()`.
- Las pestañas **Colorimetría** y **Asistente** de la barra inferior muestran la misma vista que `AppRoutes.colorimetria` / `AppRoutes.asistente`: al conectarla en el router aparece también en la pestaña.

**Argumentos que envía Home** (léelos en tu vista con `context.argumentos<T>()`):

| Ruta | Argumento | Dueño |
|---|---|---|
| `recomendaciones` | `TipoRecomendacion?` (outfit / maquillaje / cabello; `null` = todas) | Ana |
| `detalleProducto` | `String` id del producto | Ana |
| `detallePrenda` | `String` id de la prenda | Ana |
| `paleta`, `colorimetria`, `simuladorAr`, `escaner`, `armario` | ninguno | Jaider / Mauricio |

**Datos de Home:** mientras `usarMockColorimetria` / `usarMockRecomendaciones` estén en `true`, Home usa datos de ejemplo (`ui/home/home_datos_mock.dart`). Para conectar los reales busca `PUNTO DE CAMBIO` en `ui/home/home_view_model.dart`.

### Flujo de autenticación

```
Splash ─┬─ sin sesión ── onboarding (solo la 1.ª vez) ── Login ⇄ Registro
        ├─ correo sin verificar ── Verificar correo ── "Ya verifiqué" ── Home
        └─ sesión verificada ── Home
Registro: datos + casilla de aviso de privacidad (obligatoria) → cuenta en Auth
          + usuarias/{uid} (rol "usuaria", consentimiento con fecha) + correo de verificación
Google (1.ª vez): debe aceptar el aviso; si lo rechaza se elimina la cuenta creada.
```

- "Recordarme" guarda **solo el correo** en almacenamiento seguro; nunca la contraseña.
- El correo de verificación se puede reenviar cada 60 s (`AppConstants.esperaReenvioVerificacion`).

### Pruebas

```bash
flutter test test/core test/auth test/splash
```

---

## Reglas de seguridad propuestas (módulo usuarias) — PENDIENTES DE REVISIÓN

> No están desplegadas. Se revisan en equipo antes de publicarlas.

**Firestore** — cada usuaria solo lee y escribe su propio documento y no puede cambiar su `rol`:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /usuarias/{uid} {
      allow read: if request.auth != null && request.auth.uid == uid;
      allow create: if request.auth != null && request.auth.uid == uid
                    && request.resource.data.rol == 'usuaria'
                    && request.resource.data.consentimientos.avisoPrivacidad.version is string;
      allow update: if request.auth != null && request.auth.uid == uid
                    && request.resource.data.rol == resource.data.rol;
      allow delete: if false; // se elimina vía Cloud Function eliminarCuenta
    }
  }
}
```

**Storage** — foto de perfil en `perfiles/{uid}/foto.jpg`:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /perfiles/{uid}/foto.jpg {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == uid
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```
