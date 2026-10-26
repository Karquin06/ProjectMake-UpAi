<p align="center">
  <img src="assets/images/logo_proyecto.jpeg" alt="Make Up AI" width="260">
</p>

# MAKE UP AI

**Tu imagen, nuestra inteligencia.** Aplicación móvil de colorimetría personal y asesoría de imagen, construida con **Flutter** y **Firebase**. A partir de una selfie, la app calcula la estación de color de la usuaria (primavera, verano, otoño o invierno), su subtono y su paleta de colores, y con ellos le recomienda maquillaje y vestuario.

Proyecto de la materia Programación Móvil, Universidad Popular del Cesar.

---

## Tabla de contenido

1. [El problema](#el-problema)
2. [Qué hace la app](#qué-hace-la-app)
3. [Cómo funciona la colorimetría](#cómo-funciona-la-colorimetría)
4. [Tecnologías](#tecnologías)
5. [Arquitectura](#arquitectura)
6. [Diagramas](#diagramas)
7. [Estructura del proyecto](#estructura-del-proyecto)
8. [Backend en Firebase](#backend-en-firebase)
9. [Privacidad y seguridad](#privacidad-y-seguridad)
10. [Puesta en marcha](#puesta-en-marcha)
11. [Pruebas](#pruebas)
12. [Generar el APK](#generar-el-apk)
13. [Estado del proyecto](#estado-del-proyecto)
14. [Autores](#autores)

---

## El problema

Elegir qué colores de ropa y de maquillaje favorecen a cada persona suele depender de una asesoría de imagen presencial, que es costosa y poco accesible. Sin ese conocimiento, es común comprar prendas y productos que apagan el rostro, no combinan entre sí o no se vuelven a usar.

## Qué hace la app

Make Up AI pone esa asesoría en el teléfono:

- **Analiza la selfie** de la usuaria y determina su estación de color, subtono (cálido, frío o neutro), contraste e intensidad.
- **Muestra su paleta personal**: colores básicos y para destacar en ropa, tonos de labial, rubor, sombra y base, y los colores que conviene evitar.
- **Recomienda** maquillaje y prendas acordes con su paleta, con filtros por tipo y ocasión y detalle de cada ítem.
- **Simula** el maquillaje en tiempo real con la cámara frontal (realidad aumentada).
- **Analiza prendas** del armario: indica si el color de una prenda combina con la paleta.
- **Gestiona un catálogo** de prendas y productos mediante un panel de administración (solo rol admin).

Además incluye registro con verificación de correo, inicio de sesión con correo o Google, recuperación de contraseña, perfil editable con foto, notificaciones y eliminación de cuenta.

## Cómo funciona la colorimetría

```
Selfie ─► Detección de zona de piel ─► Análisis de color ─► Estación + subtono
                                                           + contraste + intensidad
                                                                  │
                                                                  ▼
                                      Paleta de la estación (ropa, maquillaje, evitar)
```

1. La usuaria acepta el **consentimiento biométrico** y toma una selfie guiada por un óvalo en pantalla.
2. La imagen se reduce y se analiza. El análisis puede hacerse **en el teléfono** o con **Cloud Functions**; la fuente se elige en un solo punto del código.
3. El resultado (estación, subtono, contraste, intensidad y nivel de confianza) se guarda en el perfil de la usuaria. **La foto no se conserva**: se borra al terminar el análisis.
4. La paleta correspondiente a la estación se muestra en la pantalla de paleta.

## Tecnologías

| Área | Tecnología |
|---|---|
| App móvil | Flutter 3.44 (canal stable) y Dart 3.12 |
| Estado | `provider` (`ChangeNotifier`, `ProxyProvider`) |
| Autenticación | Firebase Auth (correo y contraseña, Google) |
| Base de datos | Cloud Firestore |
| Archivos | Firebase Storage |
| Lógica en la nube | Cloud Functions (Node 22, TypeScript, funciones *callable* v2) |
| Notificaciones | Firebase Cloud Messaging |
| Cámara y visión | `camera`, `google_mlkit_face_detection`, `image` |
| Permisos y almacenamiento seguro | `permission_handler`, `flutter_secure_storage` |
| Selección de imágenes | `image_picker` |

Plataformas: Android (principal) y web. iOS tiene recursos de ícono y arranque, pero la configuración de Firebase para iOS no está completa.

## Arquitectura

La app usa una arquitectura **por capas, sin saltos**: cada capa solo habla con la siguiente.

```
View  →  ViewModel  →  Provider  →  Repository / Service  →  Firebase
```

| Capa | Responsabilidad | Ejemplo |
|---|---|---|
| **View** | Solo dibuja y reenvía eventos. Nunca importa Firebase. | `LoginView` |
| **ViewModel** | Lógica y estado de **una** pantalla (`ChangeNotifier`). | `AuthViewModel` |
| **Provider** | Estado **compartido** entre pantallas (sesión, usuaria, perfil, paleta). | `SesionProvider` |
| **Repository** | Único que accede a Firestore y a Firebase Auth. | `UsuariaRepository` |
| **Service** | Envuelve Storage, permisos, Cloud Functions, análisis y notificaciones. | `StorageService` |
| **Model** | Datos inmutables con `fromMap`, `toMap` y `copyWith`. | `Usuaria` |

### Decisiones de diseño

- **Un solo registro de providers.** Todos se declaran en `lib/providers/app_providers.dart`, agrupados por módulo.
- **Sesión unificada.** `SesionProvider` combina la sesión de Firebase Auth, el documento de la usuaria y su rol. Las pantallas leen de ahí, nunca de `FirebaseAuth` directamente. Los providers con datos de la usuaria usan el mixin `LimpiezaPorSesion`, de modo que **se vacían solos al cerrar sesión**.
- **Rutas protegidas.** `AppRouter` asigna a cada ruta un nivel de acceso (pública, correo sin verificar, autenticada, admin) y `GuardiaRuta` redirige automáticamente: sin sesión va a login, con correo sin verificar va a verificación, y las rutas de administración exigen rol `admin`.
- **Errores en español.** `FirebaseErrorMapper` traduce los errores de Auth, Firestore, Storage, Functions y Google a mensajes comprensibles; la interfaz nunca muestra códigos técnicos.
- **Textos y estilos centralizados.** Todos los textos están en `core/constants/app_strings.dart`, las rutas de imágenes en `app_assets.dart`, y colores, degradados y tipografías salen del tema (`core/theme`).
- **Estados de pantalla.** Cada pantalla cubre carga, vacío y error con reintento mediante widgets compartidos (`IndicadorCarga`, `EstadoVacio`, `MensajeError`).
- **Datos de ejemplo solo en pruebas.** Los servicios simulados (por ejemplo `ColorimetriaMockService`) viven en `test/`; la app siempre usa los datos reales.

### Arranque y sesión

```
Splash ─┬─ sin sesión ── onboarding (solo la primera vez) ── Login ⇄ Registro
        ├─ correo sin verificar ── Verificar correo ── Home
        └─ sesión verificada ── Home
```

El splash muestra el logo animado y decide el destino con `SplashViewModel`. Si Firebase no responde en 8 segundos, o falla la lectura de la sesión, lleva a login con un aviso claro en lugar de quedarse esperando.

## Diagramas

Los diagramas están en Mermaid: GitHub los dibuja directamente.

### Arquitectura general

Las flechas hacia Firebase salen siempre de repositorios o servicios, nunca de la interfaz. Lo que necesita secretos o confianza (IA, borrar cuentas, notificaciones) corre en Cloud Functions.

```mermaid
flowchart LR
    U(["Usuaria"]) --> UI

    subgraph APP["App Flutter (Android / Web)"]
        UI["Views + ViewModels"] --> PR["Providers"]
        PR --> RE["Repositorios"]
        PR --> SE["Servicios"]
        SE --> ML["ML Kit<br/>(en el teléfono)"]
        RE --> SS["Almacenamiento seguro"]
    end

    subgraph FB["Firebase · macke-up-ai"]
        AU["Authentication"]
        FS[("Cloud Firestore")]
        ST["Cloud Storage"]
        CF["Cloud Functions<br/>(us-central1)"]
        FCM["Cloud Messaging"]
        SM["Secret Manager"]
        SCH["Cloud Scheduler"]
    end

    RE --> AU
    RE --> FS
    SE --> ST
    SE -- "httpsCallable + token" --> CF
    SE --> FCM
    CF --> FS
    CF --> ST
    CF --> AU
    CF --> FCM
    CF --> SM
    CF --> GE["Gemini 2.5 Flash"]
    SCH -- "cada 60 min" --> CF
    FCM -. "push" .-> UI
```

### Capas

```mermaid
flowchart TB
    V["View<br/>solo dibuja y escucha"] --> VM["ViewModel<br/>estado de una pantalla"]
    VM --> P["Provider<br/>estado compartido"]
    P --> R["Repository<br/>una colección cada uno"]
    P --> S["Service<br/>cámara, Storage, funciones"]
    R --> M["Model<br/>fromMap / toMap"]
    S --> M
    R --> F[("Firebase")]
    S --> F
```

### Conexión con Firebase y sesión

`Firebase.initializeApp` usa `firebase_options.dart`. Al iniciar sesión, Firebase Auth entrega un token con el uid que viaja en cada petición; las reglas (`request.auth.uid`) y las funciones (`exigirSesion`) lo verifican.

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuaria
    participant V as LoginView
    participant VM as AuthViewModel
    participant AR as AuthRepository
    participant FA as Firebase Auth
    participant UR as UsuariaRepository
    participant FS as Firestore
    participant SP as SesionProvider

    U->>V: correo y contraseña / Google
    V->>VM: iniciarSesion()
    VM->>AR: signInWithEmailAndPassword()
    AR->>FA: credenciales
    FA-->>AR: usuario + token (uid)
    FA-->>SP: authStateChanges()
    UR->>FS: snapshots() de usuarias/uid
    FS-->>SP: documento y rol
    SP-->>V: uidActiva -> GuardiaRuta abre Home
    Note over SP: Cada provider recibe el uid,<br/>carga sus datos y se limpia al cerrar sesión
```

```mermaid
stateDiagram-v2
    [*] --> Desconocido
    Desconocido --> SinSesion: sin usuario
    Desconocido --> VerificacionPendiente: correo sin verificar
    Desconocido --> Autenticada: usuario verificado
    SinSesion --> VerificacionPendiente: registro con correo
    SinSesion --> Autenticada: login / Google
    VerificacionPendiente --> Autenticada: verificó el correo
    Autenticada --> SinSesion: cerrar sesión / eliminar cuenta
```

### Análisis de colorimetría

La selfie se analiza en el teléfono y nunca sale del dispositivo; solo el resultado se guarda.

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuaria
    participant CV as ColorimetriaView
    participant CP as ColorimetriaProvider
    participant CA as CapturaSelfie
    participant LS as ColorimetriaLocalService
    participant ML as ML Kit
    participant R as PerfilColorimetriaRepository
    participant FS as Firestore

    U->>CV: Iniciar análisis
    CV->>CP: aceptarConsentimiento()
    CP->>R: guardarConsentimiento(uid, versión)
    CV->>CA: abrir cámara frontal
    loop cada cuadro
        CA->>ML: ¿rostro centrado en el óvalo?
    end
    U->>CA: toma la foto (JPEG máx. 1080 px)
    CA->>LS: analizarSelfie(selfie)
    LS->>ML: mejillas, frente y ojos
    LS->>LS: isolate: esclera, CIELAB, reglas
    LS-->>CP: PerfilColorimetria
    CP->>R: guardarPerfil()
    R->>FS: perfiles_colorimetria/uid
    CP-->>CV: notifyListeners()
    Note over CP: Se actualizan solos la paleta, Home,<br/>recomendaciones, simulador AR y asistente
```

```mermaid
flowchart TD
    A["Selfie + zonas de ML Kit"] --> B{"¿Brillo suficiente<br/>y rostro?"}
    B -- no --> X["Error claro: foto oscura<br/>o rostro no detectado"]
    B -- sí --> C["Balance de blancos<br/>con la esclera"]
    C --> D["Piel de mejillas y frente en CIELAB<br/>mediana sin brillos ni sombras"]
    D --> E["Tono h* · ITA · Croma C* · Contraste ΔL*"]
    E --> F{"Subtono"}
    F -- "h* menor que 52°" --> G["Frío: Invierno o Verano"]
    F -- "h* mayor que 58°" --> H["Cálido: Primavera u Otoño"]
    F -- "entre 52° y 58°" --> I["Neutro: deciden contraste,<br/>claridad y 55°"]
    G --> J["Estación + segunda opción + confianza"]
    H --> J
    I --> J
```

### Recomendaciones

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuaria
    participant RP as RecomendacionProvider
    participant FIS as FuncionesIaService
    participant CF as generarRecomendaciones
    participant FS as Firestore
    participant CR as CatalogoRepository

    U->>RP: tipo (maquillaje / outfit) y ocasión
    RP->>FIS: generarRecomendaciones()
    FIS->>CF: httpsCallable con token
    CF->>FS: perfil, catálogo activo y calificaciones
    CF->>CF: puntaje por estación, subtono, ocasión
    CF-->>RP: ids ordenados con motivo
    RP->>CR: une los ids con el catálogo
    RP-->>U: tarjetas con compatibilidad
    U->>RP: califica de 1 a 5
    RP->>FS: usuarias/uid/recomendaciones
    Note over RP: Si la función no está desplegada,<br/>el mismo cálculo corre en el teléfono
```

### Asistente de IA

```mermaid
sequenceDiagram
    autonumber
    participant AP as AsistenteProvider
    participant CF as chatAsistente
    participant FS as Firestore
    participant SM as Secret Manager
    participant G as Gemini

    AP->>CF: mensaje, últimos 10, estación y subtono
    CF->>FS: limitesChat/uid (máx. 8 por minuto)
    CF->>FS: catálogo compatible con su estación
    CF->>SM: GEMINI_API_KEY
    CF->>G: generateContent
    G-->>CF: respuesta
    CF-->>AP: respuesta
    AP->>FS: usuarias/uid/conversaciones
```

### Eliminar cuenta

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuaria
    participant UP as UsuariaProvider
    participant CF as eliminarCuenta
    participant FS as Firestore
    participant ST as Storage
    participant FA as Firebase Auth

    U->>UP: confirma y se reautentica
    UP->>CF: httpsCallable
    CF->>CF: ¿login de menos de 5 minutos?
    CF->>FS: borra usuarias/uid con subcolecciones,<br/>perfil y límite del chat
    CF->>ST: borra perfiles/uid y temporales
    CF->>FA: deleteUser(uid)
    CF-->>UP: eliminada
```

### Publicación de las Cloud Functions

Se publican con `firebase deploy --only functions --project macke-up-ai` (plan Blaze). La clave de Gemini se guarda una sola vez con `firebase functions:secrets:set GEMINI_API_KEY`; lo que no es secreto va en `functions/.env`.

```mermaid
flowchart LR
    DEV["PC de desarrollo<br/>functions/src/*.ts"] -- "firebase deploy" --> B["npm run build<br/>(tsc → lib/)"]
    B --> D["Descubre las 8 funciones<br/>de index.ts"]
    D --> CB["Cloud Build<br/>una imagen por función"]
    CB --> AR["Artifact Registry<br/>(limpieza: 1 día)"]
    AR --> CR["Cloud Run<br/>us-central1 · Node 22"]
    SM["Secret Manager<br/>GEMINI_API_KEY"] -.-> CR
    ENV["functions/.env<br/>GEMINI_MODELO"] -.-> CR
    SCH["Cloud Scheduler<br/>cada 60 min"] --> CR
    APP["App Flutter"] -- "httpsCallable + token" --> CR
```

Si el CLI tarda en cargar las funciones ("Timeout after 10000"), se le da más tiempo con `FUNCTIONS_DISCOVERY_TIMEOUT=30` antes del comando. Para comprobar lo publicado: `firebase functions:list --project macke-up-ai`.

### Modelo de datos (Firestore)

```mermaid
erDiagram
    USUARIAS ||--o{ RECOMENDACIONES : "subcolección"
    USUARIAS ||--o{ CONVERSACIONES : "subcolección"
    USUARIAS ||--o| PERFILES_COLORIMETRIA : "mismo uid"
    USUARIAS ||--o| LIMITES_CHAT : "mismo uid"
    PERFILES_COLORIMETRIA }o--|| PALETAS : "estación"
    RECOMENDACIONES }o--o| PRODUCTOS_MAQUILLAJE : "productoId"
    RECOMENDACIONES }o--o| PRENDAS_ROPA : "prendaId"

    USUARIAS {
        string nombre
        string email
        string rol
        string fotoPerfilUrl
        string tokenNotificaciones
    }
    PERFILES_COLORIMETRIA {
        string estacion
        string estacionAlternativa
        string subtono
        string contraste
        string intensidad
        number confianza
    }
    RECOMENDACIONES {
        string tipo
        string ocasion
        int puntaje
        string motivo
        int calificacion
    }
    CONVERSACIONES {
        array mensajes
        timestamp fechaCreacion
    }
    PRODUCTOS_MAQUILLAJE {
        string categoria
        string colorHex
        array estacionesCompatibles
        bool activo
    }
    PRENDAS_ROPA {
        string tipoPrenda
        string colorHex
        array ocasiones
        bool activo
    }
    PALETAS {
        array coloresRecomendados
        array coloresEvitar
    }
    LIMITES_CHAT {
        number mensajes
    }
```

## Estructura del proyecto

```
lib/
├── main.dart, app.dart, firebase_options.dart
├── core/
│   ├── constants/    app_strings, app_constants, app_assets
│   ├── errors/       app_exception, firebase_error_mapper
│   ├── extensions/   contexto, fechas, etiquetas de enums
│   ├── routes/       app_routes, app_router, guardia_ruta
│   ├── theme/        colores, degradados, estilos de texto, tema
│   ├── utils/        validadores, formateadores, color, imagen, snackbar
│   └── widgets/      botones, campos, tarjeta, avatar, estados, paleta…
├── models/           usuaria, sesion, credencial, perfil de colorimetría,
│                     paleta, producto de maquillaje, prenda, recomendación…
├── data/
│   ├── repositories/ auth, usuaria, sesion, credencial, perfil de colorimetría,
│   │                 paleta, catálogo, recomendaciones, conversaciones
│   ├── services/     storage, permisos, cloud functions, análisis de color y
│   │                 de prendas, notificaciones, eliminación de cuenta
│   └── datos/        paletas por estación y catálogo de ejemplo
├── providers/        app_providers, auth, usuaria, sesión, colorimetría,
│                     paleta, notificaciones
└── ui/
    ├── splash/       logo animado y onboarding
    ├── auth/         login, registro, verificación, recuperación, privacidad
    ├── home/         inicio y navegación inferior
    ├── perfil/       perfil, edición y eliminación de cuenta
    ├── colorimetria/ selfie, análisis, resultado y paleta
    ├── recomendaciones/ recomendaciones, filtros y detalle
    ├── simulador_ar/ simulador con cámara frontal
    └── admin/        catálogo de prendas y productos

functions/            Cloud Functions (TypeScript)
assets/images/        logo del proyecto
assets/icon/          imágenes fuente del ícono y de la pantalla de arranque
test/                 pruebas automatizadas
```

Cada pantalla vive en su carpeta con el par `*_view.dart` y `*_view_model.dart`, y los componentes propios en `widgets/`.

## Backend en Firebase

Proyecto de Firebase: `macke-up-ai`.

**Firestore** (colecciones principales):

| Colección | Contenido |
|---|---|
| `usuarias` | Datos de la usuaria, rol (`usuaria` o `admin`), consentimientos y token de notificaciones |
| `perfiles_colorimetria` | Resultado del análisis de cada usuaria |
| `paletas` | Paleta de colores por estación |
| `prendasRopa` y `productosMaquillaje` | Catálogo de prendas y productos |

**Storage:**

- `perfiles/{uid}/foto.jpg`: foto de perfil.
- `temporales/selfies/{uid}/{id}.jpg`: selfies en análisis; se eliminan al terminar o, como máximo, en una hora.

**Cloud Functions** (región `us-central1`, detalle en [functions/README.md](functions/README.md)):

| Función | Qué hace |
|---|---|
| `analizarSelfie` | Analiza la selfie subida a Storage y la borra al terminar |
| `generarPaleta` | Devuelve la paleta de una estación |
| `limpiarImagenesTemporales` | Tarea programada que elimina imágenes temporales vencidas |
| `analizarPrenda` | Compara el color de una prenda con la paleta de la usuaria |
| `generarRecomendaciones` | Genera recomendaciones de maquillaje y vestuario a partir del perfil y el catálogo |
| `chatAsistente` | Respuestas del asistente de IA |
| `eliminarCuenta` | Elimina la cuenta y los datos de la usuaria |
| `enviarNotificacion` | Envía notificaciones push |

## Privacidad y seguridad

- **Consentimiento explícito.** El registro exige aceptar el aviso de privacidad, y la colorimetría exige un consentimiento biométrico aparte. Ambos guardan la versión aceptada y la fecha.
- **La selfie no se conserva.** Solo se guarda el resultado del análisis.
- **"Recordarme" guarda únicamente el correo**, en almacenamiento seguro del dispositivo. Nunca la contraseña.
- **Roles.** El rol de la usuaria no puede modificarse desde la app; las rutas y funciones de administración exigen rol `admin`.
- **Derecho al olvido.** La usuaria puede eliminar su cuenta desde Perfil, tras reautenticarse (contraseña o Google).
- **Sin secretos en el código.** Las claves que aparecen en `firebase_options.dart` son identificadores públicos de cliente de Firebase; la seguridad real depende de las reglas de Firestore y Storage.

## Puesta en marcha

**Requisitos:** Flutter 3.44 (stable) y Dart 3.12, Android Studio con el SDK de Android, y Node 22 solo si se van a trabajar las Cloud Functions.

```bash
git clone https://github.com/Karquin06/ProjectMake-UpAi.git
cd ProjectMake-UpAi
flutter pub get
flutter run
```

- **Windows:** activa el *Modo de desarrollador* (`start ms-settings:developers`); los plugins de Flutter lo necesitan para compilar.
- **Firebase:** la configuración de cliente está en `lib/firebase_options.dart` y `android/app/google-services.json`. En la consola de Firebase deben estar habilitados Authentication (correo/contraseña y Google), Firestore y Storage.
- **Inicio de sesión con Google en Android:** la app firma en modo debug con `android/app/debug.keystore`, compartido por el equipo, cuya huella SHA ya está registrada en Firebase. Si alguien tenía instalada una versión firmada con otra clave, debe desinstalarla una vez.
- **Cloud Functions:** desde `functions/`, `npm install`, `npm test` y `npm run deploy` (requiere plan Blaze y `firebase login`).

### Banderas de desarrollo (`app_constants.dart`)

| Bandera | Efecto |
|---|---|
| `usarMockEliminarCuenta` | Simula la eliminación completa de la cuenta en el cliente |
| `usarMockStorage` | La foto de perfil no se sube a Storage |
| `armarioHabilitado` | Muestra el acceso al Armario en Home |

## Pruebas

```bash
flutter analyze
flutter test
```

La suite cubre modelos, validadores, widgets, rutas y guardias, autenticación, splash, Home, Perfil, colorimetría, catálogo y el simulador AR. La prueba `test/integracion/flujo_completo_test.dart` arranca la app real con Firebase simulado y recorre registro, verificación de correo, Home, edición de perfil, cierre de sesión, login y eliminación de cuenta.

Las Cloud Functions se prueban con `npm test` dentro de `functions/`.

## Generar el APK

```bash
flutter build apk --release --split-per-abi
```

El archivo recomendado queda en `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (sirve para casi todos los teléfonos Android actuales). La compilación necesita varios GB libres en disco. El APK de release usa la clave de depuración, por lo que sirve para pruebas y entregas, no para publicar en Play Store.

## Estado del proyecto

| Módulo | Estado |
|---|---|
| Autenticación (registro, verificación, login, recuperación, privacidad) | Disponible |
| Splash con logo animado, onboarding, ícono y pantalla de arranque | Disponible |
| Home y navegación | Disponible (la estación usa datos de ejemplo hasta activar el perfil real de colorimetría) |
| Perfil (edición, foto, cierre de sesión, eliminación de cuenta) | Disponible (foto y eliminación completa con modo simulado hasta desplegar la función) |
| Colorimetría y paleta | Disponible |
| Catálogo de administración (prendas y productos) | Disponible |
| Simulador AR | En desarrollo (cámara frontal y permisos listos) |
| Recomendaciones personalizadas (lista, filtros y detalle de prendas y productos) | Disponible |
| Asistente de IA | En desarrollo (función en la nube y repositorio listos; pantalla pendiente) |
| Armario y escáner de prendas | En desarrollo (análisis de prendas disponible; pantalla pendiente) |

**Limitaciones conocidas:**

- Las reglas de seguridad de Firestore y Storage deben revisarse y publicarse en el proyecto `macke-up-ai`.
- La configuración de Firebase para iOS no está completa.

## Autores

Proyecto desarrollado por un equipo de cuatro integrantes:

- **Karlos Quintero**: base de la app (core, autenticación, home, perfil y splash).
- **Jaider Monrroy**: colorimetría, paleta y servicios compartidos.
- **Ana Cuellar**: recomendaciones, asistente de IA y catálogo.
- **Mauricio Parra**: simulador AR, escáner y armario.
