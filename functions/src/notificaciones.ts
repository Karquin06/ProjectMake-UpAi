/**
 * enviarNotificacion — Ana. Coordinado con NotificacionesService (Karlos),
 * que guarda el token FCM en `usuarias/{uid}.tokenNotificaciones`.
 */
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { REGION, exigirSesion } from "./comun";

export interface PeticionNotificacion {
  uid: string;
  titulo: string;
  mensaje: string;
}

/** Valida la petición de notificación. Lanza `invalid-argument` si no sirve. */
export function leerPeticionNotificacion(datos: unknown, uidLlamante: string): PeticionNotificacion {
  const d = (datos ?? {}) as Record<string, unknown>;
  const uid = typeof d.uid === "string" && d.uid ? d.uid : uidLlamante;
  const titulo = typeof d.titulo === "string" ? d.titulo.trim() : "";
  const mensaje = typeof d.mensaje === "string" ? d.mensaje.trim() : "";
  if (!titulo || titulo.length > 80) {
    throw new HttpsError("invalid-argument", "El título es obligatorio (máx. 80 caracteres).");
  }
  if (!mensaje || mensaje.length > 300) {
    throw new HttpsError("invalid-argument", "El mensaje es obligatorio (máx. 300 caracteres).");
  }
  return { uid, titulo, mensaje };
}

/** Errores de FCM que indican que el token ya no sirve. */
export const ERRORES_TOKEN_INVALIDO = [
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
];

/**
 * enviarNotificacion({ uid?, titulo, mensaje }) → { enviada }
 *
 * Envía una notificación push al token guardado en
 * `usuarias/{uid}.tokenNotificaciones` (lo guarda NotificacionesService de
 * Karlos). Cada usuaria solo puede enviarse a sí misma; la cuenta admin
 * puede enviar a cualquiera. Si el token ya no sirve, lo borra.
 */
export const enviarNotificacion = onCall(
  { region: REGION, timeoutSeconds: 30 },
  async (request): Promise<{ enviada: boolean }> => {
    const llamante = exigirSesion(request.auth?.uid);
    const { uid, titulo, mensaje } = leerPeticionNotificacion(request.data, llamante);
    const esAdmin = request.auth?.token.admin === true;
    if (uid !== llamante && !esAdmin) {
      throw new HttpsError("permission-denied", "Solo puedes enviarte notificaciones a ti misma.");
    }

    const ref = getFirestore().collection("usuarias").doc(uid);
    const token = (await ref.get()).get("tokenNotificaciones");
    if (typeof token !== "string" || !token) return { enviada: false };

    try {
      await getMessaging().send({
        token,
        notification: { title: titulo, body: mensaje },
        android: { priority: "high" },
      });
      return { enviada: true };
    } catch (e) {
      const codigo = (e as { code?: string }).code ?? "";
      if (ERRORES_TOKEN_INVALIDO.includes(codigo)) {
        await ref.update({ tokenNotificaciones: null }).catch(() => undefined);
        return { enviada: false };
      }
      logger.error("enviarNotificacion falló", { uid, error: String(e) });
      throw new HttpsError("internal", "No pudimos enviar la notificación.");
    }
  },
);
