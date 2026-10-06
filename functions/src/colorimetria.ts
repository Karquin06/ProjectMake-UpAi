/**
 * Cloud Functions de colorimetría — Jaider.
 * Contratos JSON en functions/README.md.
 */
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { ErrorAnalisis, Estacion, ResultadoColorimetria, analizarPixeles } from "./analisis_color";
import {
  PREFIJO_TEMPORALES,
  REGION,
  errorNegocio,
  exigirSesion,
  leerImagenCruda,
  rutaTemporalValida,
  temporalVencido,
} from "./comun";
import { PALETAS, Paleta } from "./datos/paletas";

/** Lado (px) al que se reduce la selfie antes de medir. */
const ANCHO_ANALISIS = 256;

export const rutaSelfieValida = (ruta: unknown, uid: string): ruta is string =>
  rutaTemporalValida(ruta, uid, "selfies");

export function esEstacion(valor: unknown): valor is Estacion {
  return typeof valor === "string" && Object.prototype.hasOwnProperty.call(PALETAS, valor);
}

/** `paletas/{estacion}` de Firestore o, si no está cargada, la de PALETAS. */
export async function obtenerPaleta(estacion: Estacion): Promise<Paleta> {
  const doc = await getFirestore().collection("paletas").doc(estacion).get();
  const datos = doc.data() as Partial<Paleta> | undefined;
  if (datos?.coloresRecomendados?.length) {
    return {
      estacion,
      coloresRecomendados: datos.coloresRecomendados,
      coloresEvitar: datos.coloresEvitar ?? [],
    };
  }
  return PALETAS[estacion];
}

/**
 * analizarSelfie({ rutaImagen }) → { estacion, subtono, contraste,
 * intensidad, confianza }.
 * Valida la sesión y que la ruta sea de la usuaria. Borra la imagen al
 * terminar, salga bien o mal.
 */
export const analizarSelfie = onCall(
  { region: REGION, timeoutSeconds: 60, memory: "512MiB" },
  async (request): Promise<ResultadoColorimetria> => {
    const uid = exigirSesion(request.auth?.uid);
    const ruta = (request.data as { rutaImagen?: unknown } | undefined)?.rutaImagen;
    if (!rutaSelfieValida(ruta, uid)) {
      throw errorNegocio("ruta-no-permitida", "permission-denied");
    }

    const archivo = getStorage().bucket().file(ruta);
    try {
      const { data, info } = await leerImagenCruda(archivo, ANCHO_ANALISIS);
      const resultado = analizarPixeles(data, info.width, info.height, info.channels);
      logger.info("analizarSelfie", { uid, ...resultado });
      return resultado;
    } catch (e) {
      if (e instanceof ErrorAnalisis) throw errorNegocio(e.codigo);
      if (e instanceof HttpsError) throw e;
      logger.error("analizarSelfie falló", { uid, error: String(e) });
      throw new HttpsError("internal", "No pudimos analizar la selfie.");
    } finally {
      // Consentimiento biométrico: la selfie nunca se conserva.
      await archivo.delete({ ignoreNotFound: true }).catch((e) =>
        logger.error("No se pudo borrar la selfie", { ruta, error: String(e) }),
      );
    }
  },
);

/** generarPaleta({ estacion }) → { estacion, coloresRecomendados, coloresEvitar }. */
export const generarPaleta = onCall({ region: REGION }, async (request): Promise<Paleta> => {
  exigirSesion(request.auth?.uid);
  const estacion = (request.data as { estacion?: unknown } | undefined)?.estacion;
  if (!esEstacion(estacion)) {
    throw new HttpsError("invalid-argument", "Estación no válida.");
  }
  return obtenerPaleta(estacion);
});

/**
 * Cada hora borra los archivos de `temporales/` con más de una hora.
 * Respaldo del consentimiento biométrico por si alguna función o la app no
 * alcanzó a borrar una foto.
 */
export const limpiarImagenesTemporales = onSchedule(
  { schedule: "every 60 minutes", region: REGION, timeZone: "America/Bogota" },
  async () => {
    const [archivos] = await getStorage().bucket().getFiles({ prefix: PREFIJO_TEMPORALES });
    const vencidos = archivos.filter((a) => temporalVencido(a.metadata.timeCreated));
    await Promise.all(vencidos.map((a) => a.delete({ ignoreNotFound: true })));
    logger.info("limpiarImagenesTemporales", {
      revisados: archivos.length,
      borrados: vencidos.length,
    });
  },
);
