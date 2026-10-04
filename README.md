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
│   └── widgets/     13 widgets reutilizables (ver guía en la FASE 2)
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
                    && request.resource.data.rol == 'usuaria';
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
