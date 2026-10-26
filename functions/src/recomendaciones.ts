/**
 * generarRecomendaciones — Ana.
 *
 * generarRecomendaciones({ tipo, ocasion?, limite? }) →
 *   { recomendaciones: [{ id, tipo, puntaje, motivo }] } ordenadas de mayor
 *   a menor puntaje.
 *
 * - tipo: "outfit" (ropa) o "maquillaje". También acepta "ropa".
 * - ocasion: clave opcional (trabajo, casual, fiesta, entrevista, cita,
 *   deporte). Solo aplica a ropa.
 * - limite: 1 a 50 (por defecto 20).
 *
 * Lee el perfil de colorimetría (`perfiles_colorimetria/{uid}`), el catálogo
 * activo y las calificaciones previas de la usuaria
 * (`usuarias/{uid}/recomendaciones`) para mejorar el orden.
 */
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { REGION, errorNegocio, exigirSesion } from "./comun";
import { esEstacion } from "./colorimetria";
import { PerfilPuntaje, Subtono, puntuar } from "./puntaje";

export type TipoRecomendacion = "outfit" | "maquillaje";

export interface ItemRecomendado {
  id: string;
  tipo: TipoRecomendacion;
  puntaje: number;
  motivo: string;
}

export const OCASIONES = ["trabajo", "casual", "fiesta", "entrevista", "cita", "deporte"];
const SUBTONOS: Subtono[] = ["calido", "frio", "neutro"];
export const LIMITE_POR_DEFECTO = 20;
export const LIMITE_MAXIMO = 50;

export interface PeticionRecomendaciones {
  tipo: TipoRecomendacion;
  ocasion: string | null;
  limite: number;
}

/** Valida y normaliza la petición. Lanza `invalid-argument` si no sirve. */
export function leerPeticion(datos: unknown): PeticionRecomendaciones {
  const d = (datos ?? {}) as Record<string, unknown>;
  const tipoTexto = d.tipo === "ropa" ? "outfit" : d.tipo;
  if (tipoTexto !== "outfit" && tipoTexto !== "maquillaje") {
    throw new HttpsError("invalid-argument", "tipo debe ser 'outfit' o 'maquillaje'.");
  }
  let ocasion: string | null = null;
  if (d.ocasion !== undefined && d.ocasion !== null && d.ocasion !== "") {
    if (typeof d.ocasion !== "string" || !OCASIONES.includes(d.ocasion)) {
      throw new HttpsError("invalid-argument", "ocasion no válida.");
    }
    ocasion = d.ocasion;
  }
  let limite = LIMITE_POR_DEFECTO;
  if (d.limite !== undefined && d.limite !== null) {
    if (typeof d.limite !== "number" || !Number.isFinite(d.limite)) {
      throw new HttpsError("invalid-argument", "limite debe ser un número.");
    }
    limite = Math.max(1, Math.min(LIMITE_MAXIMO, Math.round(d.limite)));
  }
  return { tipo: tipoTexto, ocasion, limite };
}

/** Puntúa y ordena una lista de documentos del catálogo (lógica pura). */
export function ordenarRecomendaciones(
  docs: { id: string; datos: Record<string, unknown> }[],
  tipo: TipoRecomendacion,
  perfil: PerfilPuntaje,
  ocasion: string | null,
  calificaciones: Map<string, number>,
  limite: number,
): ItemRecomendado[] {
  const lista = (v: unknown) => (Array.isArray(v) ? v.map(String) : []);
  const conOcasion = tipo === "outfit" && ocasion !== null;
  return docs
    .filter((d) => d.datos.activo !== false)
    // Con una ocasión elegida solo van las prendas pensadas para ella
    // (en "deporte" no sale un blazer).
    .filter((d) => !conOcasion || lista(d.datos.ocasiones).includes(ocasion))
    .map((d) => {
      const { puntaje, motivo } = puntuar(
        {
          estacionesCompatibles: lista(d.datos.estacionesCompatibles),
          // Prendas: subtonosCompatibles · Productos: subtonoCompatible.
          subtonos: lista(
            tipo === "outfit" ? d.datos.subtonosCompatibles : d.datos.subtonoCompatible,
          ),
          ocasiones: tipo === "outfit" ? lista(d.datos.ocasiones) : [],
        },
        perfil,
        tipo === "outfit" ? ocasion : null,
        calificaciones.get(d.id),
      );
      return { id: d.id, tipo, puntaje, motivo };
    })
    .sort((a, b) => b.puntaje - a.puntaje || a.id.localeCompare(b.id))
    .slice(0, limite);
}

export const generarRecomendaciones = onCall(
  { region: REGION, timeoutSeconds: 30 },
  async (request): Promise<{ recomendaciones: ItemRecomendado[] }> => {
    const uid = exigirSesion(request.auth?.uid);
    const { tipo, ocasion, limite } = leerPeticion(request.data);
    const db = getFirestore();

    const perfilDoc = await db.collection("perfiles_colorimetria").doc(uid).get();
    const perfil = perfilDoc.data();
    if (!perfil || !esEstacion(perfil.estacion)) throw errorNegocio("sin-perfil");
    const subtono = SUBTONOS.includes(perfil.subtono) ? (perfil.subtono as Subtono) : "neutro";

    try {
      const coleccion = tipo === "outfit" ? "prendasRopa" : "productosMaquillaje";
      const [catalogo, previas] = await Promise.all([
        db.collection(coleccion).where("activo", "==", true).get(),
        db.collection("usuarias").doc(uid).collection("recomendaciones").get(),
      ]);

      const calificaciones = new Map<string, number>();
      for (const doc of previas.docs) {
        const c = doc.get("calificacion");
        if (typeof c === "number") calificaciones.set(doc.id, c);
      }

      const recomendaciones = ordenarRecomendaciones(
        catalogo.docs.map((d) => ({ id: d.id, datos: d.data() })),
        tipo,
        { estacion: perfil.estacion, subtono },
        ocasion,
        calificaciones,
        limite,
      );
      logger.info("generarRecomendaciones", { uid, tipo, ocasion, total: recomendaciones.length });
      return { recomendaciones };
    } catch (e) {
      logger.error("generarRecomendaciones falló", { uid, error: String(e) });
      throw new HttpsError("internal", "No pudimos generar tus recomendaciones.");
    }
  },
);
