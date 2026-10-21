/**
 * eliminarCuenta — Ana.
 */
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { PREFIJO_TEMPORALES, REGION, errorNegocio, exigirSesion } from "./comun";

/** Tiempo máximo desde el último inicio de sesión para eliminar la cuenta. */
export const REAUTENTICACION_MAXIMA_S = 5 * 60;

/** `true` si la usuaria inició sesión (o se reautenticó) hace poco. */
export function reautenticacionReciente(
  authTimeSegundos: number | undefined,
  ahoraMs = Date.now(),
): boolean {
  if (typeof authTimeSegundos !== "number") return false;
  return ahoraMs / 1000 - authTimeSegundos <= REAUTENTICACION_MAXIMA_S;
}

/** Carpetas de Storage con archivos de la usuaria. */
export function prefijosDeUsuaria(uid: string): string[] {
  return [
    `perfiles/${uid}/`,
    `${PREFIJO_TEMPORALES}selfies/${uid}/`,
    `${PREFIJO_TEMPORALES}prendas/${uid}/`,
  ];
}

/**
 * eliminarCuenta() → { eliminada: true }
 *
 * Exige reautenticación reciente (máx. 5 min). Borra `usuarias/{uid}` con
 * todas sus subcolecciones, `perfiles_colorimetria/{uid}`,
 * `limitesChat/{uid}`, sus archivos de Storage y su cuenta de Auth. La usa
 * Karlos en Perfil (EliminadorCuenta).
 */
export const eliminarCuenta = onCall(
  { region: REGION, timeoutSeconds: 120 },
  async (request): Promise<{ eliminada: true }> => {
    const uid = exigirSesion(request.auth?.uid);
    if (!reautenticacionReciente(request.auth?.token.auth_time)) {
      throw errorNegocio("reautenticacion-requerida", "failed-precondition");
    }

    const db = getFirestore();
    try {
      await db.recursiveDelete(db.collection("usuarias").doc(uid));
      await Promise.all([
        db.collection("perfiles_colorimetria").doc(uid).delete(),
        db.collection("limitesChat").doc(uid).delete(),
      ]);
      const bucket = getStorage().bucket();
      await Promise.all(
        prefijosDeUsuaria(uid).map((prefix) => bucket.deleteFiles({ prefix, force: true })),
      );
      await getAuth().deleteUser(uid);
      logger.info("eliminarCuenta", { uid });
      return { eliminada: true };
    } catch (e) {
      logger.error("eliminarCuenta falló", { uid, error: String(e) });
      throw new HttpsError("internal", "No pudimos eliminar la cuenta. Intenta de nuevo.");
    }
  },
);
