# Cloud Functions

Región `us-central1`, Node 22, funciones *callable* (v2).

```bash
npm install
npm test          # compila y corre las pruebas
npm run deploy    # requiere plan Blaze y `firebase login`
```

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

v1 usa una heurística de color (sin servicios externos), descrita en
`src/analisis_color.ts`. Los umbrales se calibran en la Etapa 6.

### Datos: `paletas/{estacion}`

Fuente: `src/datos/paletas.ts`. Para cargarlas en Firestore:

```bash
gcloud auth application-default login   # una vez
npm run sembrar:paletas
```

### Reglas (para combinar con las del resto del equipo)

Firestore:

```
match /perfiles_colorimetria/{uid} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
match /paletas/{estacion} {
  allow read: if request.auth != null;
  allow write: if false; // solo con el script (Admin SDK)
}
```

Storage:

```
match /temporales/{tipo}/{uid}/{archivo} {
  // tipo: selfies | prendas. Las funciones leen con Admin SDK.
  allow create: if request.auth != null && request.auth.uid == uid
    && tipo in ['selfies', 'prendas']
    && request.resource.size < 5 * 1024 * 1024
    && request.resource.contentType == 'image/jpeg';
  allow delete: if request.auth != null && request.auth.uid == uid;
  allow read: if false;
}
```

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

## Escáner — Jaider, la consume Mauricio (`src/escaner.ts`)

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
