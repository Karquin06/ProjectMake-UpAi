/**
 * Cloud Function del escáner de prendas — Jaider (la consume Mauricio).
 * Contrato JSON en functions/README.md.
 */
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { ResultadoPrenda, colorDominante, evaluarPrenda } from "./analisis_prenda";
import { esEstacion, obtenerPaleta } from "./colorimetria";
import { REGION, errorNegocio, exigirSesion, leerImagenCruda, rutaTemporalValida } from "./comun";

const ANCHO_ANALISIS = 200;

/**
 * analizarPrenda({ rutaImagen }) → { colorHex, nombreColor,
 * compatibilidad, motivo, coincideConPaleta }.
 * Necesita el perfil de colorimetría de la usuaria (si no: `sin-perfil`).
 * Borra la foto al terminar.
 */
export const analizarPrenda = onCall(
  { region: REGION, timeoutSeconds: 60, memory: "512MiB" },
  async (request): Promise<ResultadoPrenda> => {
    const uid = exigirSesion(request.auth?.uid);
    const ruta = (request.data as { rutaImagen?: unknown } | undefined)?.rutaImagen;
    if (!rutaTemporalValida(ruta, uid, "prendas")) {
      throw errorNegocio("ruta-no-permitida", "permission-denied");
    }

    const archivo = getStorage().bucket().file(ruta);
    try {
      const perfil = await getFirestore().collection("perfiles_colorimetria").doc(uid).get();
      const estacion = perfil.get("estacion");
      if (!esEstacion(estacion)) throw errorNegocio("sin-perfil");

      const [paleta, imagen] = await Promise.all([
        obtenerPaleta(estacion),
        leerImagenCruda(archivo, ANCHO_ANALISIS),
      ]);
      const { data, info } = imagen;
      const resultado = evaluarPrenda(
        colorDominante(data, info.width, info.height, info.channels),
        paleta,
      );
      logger.info("analizarPrenda", { uid, estacion, ...resultado });
      return resultado;
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      logger.error("analizarPrenda falló", { uid, error: String(e) });
      throw new HttpsError("internal", "No pudimos analizar la prenda.");
    } finally {
      await archivo.delete({ ignoreNotFound: true }).catch((e) =>
        logger.error("No se pudo borrar la foto de la prenda", { ruta, error: String(e) }),
      );
    }
  },
);
