# Cloud Functions

Proyecto `macke-up-ai` (plan Blaze), región `us-central1`, Node 22, funciones
*callable* (v2).

## Estado del despliegue (25/10/2026)

Las 8 funciones están desplegadas y activas:

| Función | Tipo | Dueño | Archivo |
|---|---|---|---|
| `analizarSelfie` | callable | Jaider | `src/colorimetria.ts` |
| `generarPaleta` | callable | Jaider | `src/colorimetria.ts` |
| `limpiarImagenesTemporales` | programada (cada hora) | Jaider | `src/colorimetria.ts` |
| `analizarPrenda` | callable | Jaider | `src/escaner.ts` |
| `generarRecomendaciones` | callable | Ana | `src/recomendaciones.ts` |
| `chatAsistente` | callable | Ana | `src/asistente.ts` |
| `eliminarCuenta` | callable | Ana | `src/cuenta.ts` |
| `enviarNotificacion` | callable | Ana | `src/notificaciones.ts` |

La app **analiza la selfie en el teléfono** por defecto (ML Kit + análisis de
color, sin subir la foto). `analizarSelfie` queda como alternativa: se activa
cambiando `ColorimetriaService.fuente` a `FuenteColorimetria.funciones` en
`lib/data/services/colorimetria_service.dart`.

Para ver lo desplegado y sus registros:

```bash
firebase functions:list --project macke-up-ai
firebase functions:log --only chatAsistente --project macke-up-ai
```

## Desarrollo y despliegue

```bash
npm install
npm test          # compila y corre las pruebas (35)
```

Desplegar una o varias funciones (desde la raíz del proyecto):

```bash
firebase deploy --only functions:analizarSelfie,functions:generarPaleta --project macke-up-ai
```

- **Error "User code failed to load ... Timeout after 10000"**: en Windows la
  carga del código puede pasar de 10 s. Dar más margen:
  - Git Bash: `FUNCTIONS_DISCOVERY_TIMEOUT=30 firebase deploy --only functions:<nombre> --project macke-up-ai`
  - PowerShell: `$env:FUNCTIONS_DISCOVERY_TIMEOUT="30"; firebase deploy --only functions:<nombre> --project macke-up-ai`
- **Firebase revisa todo el código** antes de desplegar cualquier función: si
  falta el secreto de `chatAsistente` no deja desplegar ninguna.
- La primera vez agregar `--force` para que configure la limpieza automática
  de imágenes viejas en Artifact Registry (se borran después de 1 día).

### Configuración

| Qué | Dónde | Cómo |
|---|---|---|
| `GEMINI_API_KEY` (secreto de `chatAsistente`) | Secret Manager | `firebase functions:secrets:set GEMINI_API_KEY --project macke-up-ai` y volver a desplegar `chatAsistente`. **Nunca** en el código ni en un chat |
| `GEMINI_MODELO` (no secreto) | `functions/.env` | Valor actual: `gemini-2.5-flash` |

### Scripts con Admin SDK

Necesitan una clave de cuenta de servicio (Consola → Configuración del
proyecto → Cuentas de servicio → Generar nueva clave privada) guardada
**fuera del repositorio**. El `.gitignore` ignora `*firebase-adminsdk*.json`.

```bash
# PowerShell, desde functions/
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\ruta\fuera\del\repo\clave.json"
npm run hacer:admin -- mackeupai@gmail.com   # única cuenta admin del proyecto
npm run sembrar:catalogo                     # catálogo de prueba (ver abajo)
npm run sembrar:paletas                      # opcional: la app ya trae las paletas
```

`hacer:admin` pone el custom claim `admin: true` (lo exigen las reglas del
catálogo) y `rol: "admin"` en `usuarias/{uid}` (lo usa la app para mostrar el
catálogo en Perfil). Solo acepta `mackeupai@gmail.com`; `--quitar` lo revoca.

## Errores

Errores de negocio: `HttpsError(<tipo>, <codigo>, { codigo })`. En Flutter,
`CloudFunctionsBase` los convierte en `AppException` con `codigo` y mensaje en
español (`AppStrings`).

## Colorimetría — Jaider (`src/colorimetria.ts`)

### `analizarSelfie`

Analiza una selfie subida a Storage y **la borra al terminar** (con éxito o
error). Requiere sesión. Timeout 60 s.

Petición:

```json
{ "rutaImagen": "temporales/selfies/{uid}/{id}.jpg" }
```

Respuesta:

```json
{
  "estacion": "invierno",      // primavera | verano | otono | invierno
  "subtono": "frio",           // calido | frio | neutro
  "contraste": "alto",         // bajo | medio | alto
  "intensidad": "brillante",   // suave | media | brillante
  "confianza": 0.87            // 0 a 1
}
```

Errores:

| Tipo                  | codigo                | Cuándo                                        |
|-----------------------|-----------------------|-----------------------------------------------|
| `unauthenticated`     | —                     | Sin sesión                                    |
| `permission-denied`   | `ruta-no-permitida`   | La ruta no es `temporales/selfies/{suUid}/…`  |
| `not-found`           | —                     | La imagen no existe                           |
| `failed-precondition` | `imagen-oscura`       | Brillo medio insuficiente                     |
| `failed-precondition` | `rostro-no-detectado` | Poca piel dentro del óvalo guía               |
| `internal`            | —                     | Error inesperado                              |

Usa una heurística de color (sin servicios externos), descrita en
`src/analisis_color.ts`; la app tiene la misma lógica en Dart
(`lib/data/services/analisis/analisis_color.dart`). Los umbrales siguen con la
primera calibración: falta ajustarlos con selfies reales.

### Datos: `paletas/{estacion}`

Fuente: `src/datos/paletas.ts`. La app trae las mismas paletas en
`lib/data/datos/paletas_por_estacion.dart`, así que cargarlas en Firestore
(`npm run sembrar:paletas`) es opcional.

### Reglas

- **Storage**: `storage.rules` en la raíz del repositorio, registradas en
  `firebase.json` y publicadas con `firebase deploy --only storage --project macke-up-ai`.
  Cubren `perfiles/{uid}/` (foto de perfil), `catalogo/{prendas|productos}/{id}/`
  (solo admin sube) y `temporales/{selfies|prendas}/{uid}/` (la dueña sube JPEG,
  solo las funciones leen).
- **Firestore**: publicadas desde la consola (Firestore → Reglas). Incluyen
  `perfiles_colorimetria/{uid}` (solo la dueña) y `paletas/{estacion}`
  (lectura con sesión, escritura solo con Admin SDK).

### `generarPaleta`

Requiere sesión. Lee `paletas/{estacion}`; si no está cargada usa
`src/datos/paletas.ts`.

Petición: `{ "estacion": "invierno" }`

Respuesta:

```json
{
  "estacion": "invierno",
  "coloresRecomendados": [{ "nombre": "Azul clásico", "hex": "#0F4C81" }],
  "coloresEvitar": [{ "nombre": "Mostaza", "hex": "#D4A017" }]
}
```

Errores: `unauthenticated`, `invalid-argument` (estación desconocida).

### `limpiarImagenesTemporales`

Programada cada hora (zona `America/Bogota`). Borra de Storage todo lo que
esté en `temporales/` con más de una hora. Es el respaldo del consentimiento
biométrico.

## Análisis de prendas — Jaider (`src/escaner.ts`)

El Escáner se quitó de la app por decisión del equipo; la función queda
disponible para el Armario de Mauricio. En la app también existe la versión
local, sin subir la foto: `AnalisisPrendaService` (`lib/data/services/analisis_prenda_service.dart`).

### `analizarPrenda`

Detecta el color dominante en el centro de la foto y lo compara con la
paleta de la usuaria. **Borra la foto al terminar.** Requiere sesión y
perfil de colorimetría. Timeout 60 s.

Petición:

```json
{ "rutaImagen": "temporales/prendas/{uid}/{id}.jpg" }
```

Respuesta:

```json
{
  "colorHex": "#0F4C81",
  "nombreColor": "Azul clásico",
  "compatibilidad": 96,               // 0 a 100
  "motivo": "Se parece a Azul clásico, de tu paleta de Invierno.",
  "coincideConPaleta": true
}
```

Errores:

| Tipo                  | codigo              | Cuándo                                        |
|-----------------------|---------------------|-----------------------------------------------|
| `unauthenticated`     | —                   | Sin sesión                                    |
| `permission-denied`   | `ruta-no-permitida` | La ruta no es `temporales/prendas/{suUid}/…`  |
| `failed-precondition` | `sin-perfil`        | La usuaria aún no hizo su análisis            |
| `not-found`           | —                   | La imagen no existe                           |
| `internal`            | —                   | Error inesperado                              |

En Flutter: `CloudFunctionsService().analizarPrenda(ruta)` →
`ResultadoAnalisisPrenda`. Subir la foto con
`StorageService.subirArchivo(RutasStorage.prendaTemporal(uid, id), jpeg)`.

## Catálogo de prueba — Ana (`src/datos/catalogo.ts`)

30 prendas (Zara, Mango, Studio F, Koaj, H&M, ELA) y 38 productos de
maquillaje (L'Oréal Paris, MAC, Maybelline, Bloomshell, NYX, Revlon, Vogue,
Samy, Esika) para que el equipo pueda probar el catálogo, las
recomendaciones y el simulador. Nombres descriptivos y precios (COP)
aproximados: son datos de prueba. Los colores salen de las
paletas de cada estación (`src/datos/paletas.ts`) y los subtonos siguen la
regla primavera/otoño → cálido, verano/invierno → frío. Los campos son los
mismos que escriben `PrendaRopa.toMap` y `ProductoMaquillaje.toMap`.

```bash
npm run sembrar:catalogo   # con GOOGLE_APPLICATION_CREDENTIALS (ver "Scripts con Admin SDK")
```

- Ids fijos (`prenda-…`, `producto-…`): si se corre otra vez, actualiza los
  mismos documentos, no duplica.
- Cada ítem tiene una foto real de Pexels (licencia libre). El script la
  descarga y la **guarda en Storage** (`catalogo/{prendas|productos}/{id}/ejemplo.jpg`),
  así la app no depende de Pexels. Respeta las fotos subidas con "Editar".
- `npm test` valida los datos (colores de la paleta, subtonos, campos).
- La app tiene una copia generada en `lib/data/datos/catalogo_ejemplo.dart`
  y el catálogo admin la carga con el botón "Cargar catálogo de ejemplo"
  (solo en modo depuración), sin necesitar credenciales.
