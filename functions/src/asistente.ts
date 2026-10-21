/**
 * chatAsistente — Ana.
 *
 * chatAsistente({ mensaje, historial?, contexto? }) → { respuesta }
 *
 * - mensaje: texto de la usuaria (1 a 500 caracteres).
 * - historial: últimos mensajes [{ rol: "user" | "assistant", contenido }]
 *   (se usan los 10 más recientes).
 * - contexto: { estacion, subtono } de su colorimetría (opcional).
 *
 * Llama al modelo de IA (Gemini) con la clave guardada en Secret Manager
 * (GEMINI_API_KEY, nunca en la app). Rol: asesora de imagen en español,
 * que solo recomienda productos del catálogo y no da consejos médicos.
 * Limita los mensajes por minuto de cada usuaria.
 *
 * Configurar la clave (una vez, con el plan Blaze):
 *   firebase functions:secrets:set GEMINI_API_KEY
 */
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { defineSecret, defineString } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { REGION, errorNegocio, exigirSesion } from "./comun";

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const GEMINI_MODELO = defineString("GEMINI_MODELO", { default: "gemini-2.5-flash" });

export const LARGO_MAXIMO = 500;
export const HISTORIAL_MAXIMO = 10;
export const MENSAJES_POR_MINUTO = 8;
const VENTANA_MS = 60 * 1000;

export interface MensajeChat {
  rol: "user" | "assistant";
  contenido: string;
}

export interface Contexto {
  estacion?: string;
  subtono?: string;
}

export interface PeticionChat {
  mensaje: string;
  historial: MensajeChat[];
  contexto: Contexto;
}

const ESTACIONES = ["primavera", "verano", "otono", "invierno"];
const SUBTONOS = ["calido", "frio", "neutro"];

/** Valida y normaliza la petición. Lanza `invalid-argument` si no sirve. */
export function leerPeticionChat(datos: unknown): PeticionChat {
  const d = (datos ?? {}) as Record<string, unknown>;
  const mensaje = typeof d.mensaje === "string" ? d.mensaje.trim() : "";
  if (!mensaje) throw new HttpsError("invalid-argument", "El mensaje está vacío.");
  if (mensaje.length > LARGO_MAXIMO) throw errorNegocio("mensaje-largo", "failed-precondition");

  const historial: MensajeChat[] = (Array.isArray(d.historial) ? d.historial : [])
    .map((m) => m as Record<string, unknown>)
    .filter(
      (m) =>
        (m?.rol === "user" || m?.rol === "assistant") &&
        typeof m.contenido === "string" &&
        m.contenido.trim().length > 0,
    )
    .map((m) => ({
      rol: m.rol as MensajeChat["rol"],
      contenido: (m.contenido as string).slice(0, LARGO_MAXIMO * 4),
    }))
    .slice(-HISTORIAL_MAXIMO);

  const c = (d.contexto ?? {}) as Record<string, unknown>;
  const contexto: Contexto = {
    estacion: ESTACIONES.includes(c.estacion as string) ? (c.estacion as string) : undefined,
    subtono: SUBTONOS.includes(c.subtono as string) ? (c.subtono as string) : undefined,
  };
  return { mensaje, historial, contexto };
}

/**
 * Límite de mensajes por minuto (ventana fija). Devuelve el nuevo estado y
 * si se permite el mensaje. Lógica pura para poder probarla.
 */
export function aplicarLimite(
  estado: { inicio: number; conteo: number } | undefined,
  ahora: number,
  maximo = MENSAJES_POR_MINUTO,
): { permitido: boolean; estado: { inicio: number; conteo: number } } {
  if (!estado || ahora - estado.inicio >= VENTANA_MS) {
    return { permitido: true, estado: { inicio: ahora, conteo: 1 } };
  }
  if (estado.conteo >= maximo) return { permitido: false, estado };
  return { permitido: true, estado: { inicio: estado.inicio, conteo: estado.conteo + 1 } };
}

const NOMBRE_ESTACION: Record<string, string> = {
  primavera: "Primavera",
  verano: "Verano",
  otono: "Otoño",
  invierno: "Invierno",
};
const NOMBRE_SUBTONO: Record<string, string> = { calido: "cálido", frio: "frío", neutro: "neutro" };

export interface ItemCatalogoChat {
  tipo: "prenda" | "producto";
  nombre: string;
  marca: string;
  categoria: string;
  estaciones: string[];
}

/** Instrucciones del sistema para el modelo (rol, límites y catálogo). */
export function construirInstrucciones(contexto: Contexto, catalogo: ItemCatalogoChat[]): string {
  const perfil = contexto.estacion
    ? `La usuaria es de la estación ${NOMBRE_ESTACION[contexto.estacion]}` +
      (contexto.subtono ? ` con subtono ${NOMBRE_SUBTONO[contexto.subtono]}.` : ".")
    : "La usuaria todavía no ha hecho su análisis de colorimetría; si pregunta por colores, " +
      "invítala a hacerlo en la sección Colorimetría de la app.";

  const lineas = catalogo.map(
    (i) =>
      `- ${i.nombre} (${i.marca}, ${i.categoria}; estaciones: ${i.estaciones
        .map((e) => NOMBRE_ESTACION[e] ?? e)
        .join(", ")})`,
  );

  return [
    "Eres la asesora de imagen de MAKE UP AI, una app de colorimetría personal.",
    "Responde SIEMPRE en español, con tono cercano y profesional, en máximo 120 palabras.",
    perfil,
    "Basa tus consejos de colores en su estación y subtono.",
    "Cuando recomiendes productos o prendas concretos, usa SOLO los del catálogo de abajo y " +
      "nómbralos tal cual. No inventes productos, marcas ni precios. Si nada del catálogo " +
      "sirve, da consejos generales de color sin nombrar productos.",
    "No des consejos médicos ni dermatológicos (alergias, irritaciones, enfermedades de la " +
      "piel, medicamentos): en esos casos sugiere consultar a un profesional de la salud.",
    "Si te preguntan algo que no tiene que ver con imagen, maquillaje, ropa o colorimetría, " +
      "responde amablemente que solo puedes ayudar con esos temas.",
    "",
    lineas.length ? "Catálogo disponible:" : "El catálogo está vacío por ahora.",
    ...lineas,
  ].join("\n");
}

/** Cuerpo de la petición a la API de Gemini (generateContent). */
export function cuerpoGemini(instrucciones: string, peticion: PeticionChat) {
  return {
    systemInstruction: { parts: [{ text: instrucciones }] },
    contents: [
      ...peticion.historial.map((m) => ({
        role: m.rol === "assistant" ? "model" : "user",
        parts: [{ text: m.contenido }],
      })),
      { role: "user", parts: [{ text: peticion.mensaje }] },
    ],
    generationConfig: { temperature: 0.7, maxOutputTokens: 600 },
  };
}

/** Saca el texto de la respuesta de Gemini; `null` si no trae texto. */
export function textoDeRespuesta(respuesta: unknown): string | null {
  const r = respuesta as {
    candidates?: { content?: { parts?: { text?: string }[] } }[];
  };
  const partes = r?.candidates?.[0]?.content?.parts ?? [];
  const texto = partes
    .map((p) => p.text ?? "")
    .join("")
    .trim();
  return texto || null;
}

/** Catálogo activo resumido (ordenado: primero lo de su estación). */
async function catalogoParaChat(estacion: string | undefined): Promise<ItemCatalogoChat[]> {
  const db = getFirestore();
  const [prendas, productos] = await Promise.all([
    db.collection("prendasRopa").where("activo", "==", true).limit(60).get(),
    db.collection("productosMaquillaje").where("activo", "==", true).limit(60).get(),
  ]);
  const lista = (v: unknown) => (Array.isArray(v) ? v.map(String) : []);
  const items: ItemCatalogoChat[] = [
    ...prendas.docs.map((d) => ({
      tipo: "prenda" as const,
      nombre: String(d.get("nombre") || d.get("marca") || ""),
      marca: String(d.get("marca") ?? ""),
      categoria: String(d.get("tipoPrenda") ?? ""),
      estaciones: lista(d.get("estacionesCompatibles")),
    })),
    ...productos.docs.map((d) => ({
      tipo: "producto" as const,
      nombre: String(d.get("nombre") || d.get("marca") || ""),
      marca: String(d.get("marca") ?? ""),
      categoria: String(d.get("categoria") ?? ""),
      estaciones: lista(d.get("estacionesCompatibles")),
    })),
  ].filter((i) => i.nombre);
  if (estacion) {
    items.sort(
      (a, b) => Number(b.estaciones.includes(estacion)) - Number(a.estaciones.includes(estacion)),
    );
  }
  return items.slice(0, 40);
}

/** Cuenta el mensaje en `limitesChat/{uid}` (solo accesible con Admin SDK). */
async function verificarLimite(uid: string): Promise<void> {
  const db = getFirestore();
  const ref = db.collection("limitesChat").doc(uid);
  const permitido = await db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    const inicio = doc.get("inicio") as Timestamp | undefined;
    const previo = inicio
      ? { inicio: inicio.toMillis(), conteo: Number(doc.get("conteo") ?? 0) }
      : undefined;
    const { permitido, estado } = aplicarLimite(previo, Date.now());
    if (permitido) {
      tx.set(ref, {
        inicio: Timestamp.fromMillis(estado.inicio),
        conteo: estado.conteo,
        actualizado: FieldValue.serverTimestamp(),
      });
    }
    return permitido;
  });
  if (!permitido) throw errorNegocio("limite-mensajes", "failed-precondition");
}

export const chatAsistente = onCall(
  { region: REGION, timeoutSeconds: 60, secrets: [GEMINI_API_KEY] },
  async (request): Promise<{ respuesta: string }> => {
    const uid = exigirSesion(request.auth?.uid);
    const peticion = leerPeticionChat(request.data);
    await verificarLimite(uid);

    const instrucciones = construirInstrucciones(
      peticion.contexto,
      await catalogoParaChat(peticion.contexto.estacion),
    );

    let respuesta: Response;
    try {
      respuesta = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODELO.value()}:generateContent`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": GEMINI_API_KEY.value(),
          },
          body: JSON.stringify(cuerpoGemini(instrucciones, peticion)),
          signal: AbortSignal.timeout(45000),
        },
      );
    } catch (e) {
      logger.error("chatAsistente: no se pudo llamar a la IA", { uid, error: String(e) });
      throw errorNegocio("ia-no-disponible", "failed-precondition");
    }

    if (!respuesta.ok) {
      logger.error("chatAsistente: la IA respondió con error", {
        uid,
        status: respuesta.status,
        cuerpo: (await respuesta.text()).slice(0, 500),
      });
      throw errorNegocio("ia-no-disponible", "failed-precondition");
    }

    const texto = textoDeRespuesta(await respuesta.json());
    if (!texto) throw errorNegocio("ia-no-disponible", "failed-precondition");
    logger.info("chatAsistente", { uid, largo: texto.length });
    return { respuesta: texto };
  },
);
