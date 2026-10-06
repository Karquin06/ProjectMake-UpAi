/** Utilidades compartidas por las funciones de imagen (Jaider). */
import type { File } from "@google-cloud/storage";
import { HttpsError } from "firebase-functions/v2/https";
import sharp from "sharp";

export const REGION = "us-central1";

/** Carpeta de archivos temporales en Storage. */
export const PREFIJO_TEMPORALES = "temporales/";

/** Vida máxima de un temporal antes de que lo borre la limpieza. */
export const VIDA_TEMPORAL_MS = 60 * 60 * 1000;

export type TipoTemporal = "selfies" | "prendas";

/** `temporales/{tipo}/{uid}/{id}.jpg` y nada más (sin `..` ni subcarpetas). */
export function rutaTemporalValida(
  ruta: unknown,
  uid: string,
  tipo: TipoTemporal,
): ruta is string {
  if (typeof ruta !== "string") return false;
  const prefijo = `${PREFIJO_TEMPORALES}${tipo}/${uid}/`;
  return ruta.startsWith(prefijo) && /^[A-Za-z0-9_-]+\.jpg$/.test(ruta.slice(prefijo.length));
}

/** `true` si el temporal se creó hace más de [VIDA_TEMPORAL_MS]. */
export function temporalVencido(creado: string | Date | undefined, ahora = Date.now()): boolean {
  if (!creado) return false;
  const ms = new Date(creado).getTime();
  return !Number.isNaN(ms) && ahora - ms > VIDA_TEMPORAL_MS;
}

/** Error de negocio con código legible por la app (`details.codigo`). */
export function errorNegocio(
  codigo: string,
  tipo: "failed-precondition" | "permission-denied" = "failed-precondition",
) {
  return new HttpsError(tipo, codigo, { codigo });
}

export function exigirSesion(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "Inicia sesión para continuar.");
  return uid;
}

/** Descarga la imagen y la devuelve en RGB crudo, reducida a [ancho] px. */
export async function leerImagenCruda(archivo: File, ancho: number) {
  const [existe] = await archivo.exists();
  if (!existe) throw new HttpsError("not-found", "La imagen no existe.");
  const [bytes] = await archivo.download();
  return sharp(bytes)
    .rotate()
    .resize({ width: ancho, withoutEnlargement: true })
    .removeAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
}
