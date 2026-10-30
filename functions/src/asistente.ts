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
 * Limita los mensajes por minuto de cada usuaria. Si Gemini falla (sin
 * créditos, modelo retirado, tiempo agotado), responde un asesor de respaldo
 * con su paleta y el catálogo: la usuaria siempre recibe respuesta.
 *
 * Configurar la clave (una vez, con el plan Blaze):
 *   firebase functions:secrets:set GEMINI_API_KEY
 */
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { defineSecret, defineString } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import type { Estacion } from "./analisis_color";
import { REGION, errorNegocio, exigirSesion } from "./comun";
import { PALETAS } from "./datos/paletas";

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const GEMINI_MODELO = defineString("GEMINI_MODELO", { default: "gemini-3.8-flash" });

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
    "Escribe en texto plano, sin Markdown (nada de asteriscos ni almohadillas); para listas usa guiones.",
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
    generationConfig: {
      temperature: 0.7,
      // Los modelos Flash "piensan" antes de responder y esos tokens se
      // descuentan de este límite: se deja margen para que siempre quede
      // espacio para la respuesta (las instrucciones la limitan a 120
      // palabras).
      maxOutputTokens: 2048,
    },
  };
}

/** Saca el texto de la respuesta de Gemini; `null` si no trae texto. */
export function textoDeRespuesta(respuesta: unknown): string | null {
  const r = respuesta as {
    candidates?: { content?: { parts?: { text?: string; thought?: boolean }[] } }[];
  };
  const partes = r?.candidates?.[0]?.content?.parts ?? [];
  const texto = partes
    // Las partes de "pensamiento" del modelo no son la respuesta.
    .filter((p) => p.thought !== true)
    .map((p) => p.text ?? "")
    .join("")
    .trim();
  return texto || null;
}

/** Minúsculas y sin tildes, para reconocer palabras clave. */
function normalizar(texto: string): string {
  return texto.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
}

const TEMAS: { tema: string; palabras: string[]; categorias: string[] }[] = [
  { tema: "labios", palabras: ["labial", "labio", "boca", "gloss"], categorias: ["labial"] },
  { tema: "ojos", palabras: ["sombra", "ojo", "delineador", "pestan"], categorias: ["sombra", "delineador"] },
  { tema: "mejillas", palabras: ["rubor", "mejilla", "blush", "colorete"], categorias: ["rubor"] },
  { tema: "base", palabras: ["base", "corrector", "polvo"], categorias: ["base", "corrector", "polvo"] },
  {
    tema: "ropa",
    palabras: ["ropa", "outfit", "vestir", "prenda", "blusa", "camisa", "pantalon", "vestido", "falda", "chaqueta", "look"],
    categorias: [],
  },
];

/**
 * Respuesta sin IA para cuando Gemini no está disponible (sin créditos,
 * modelo retirado, tiempo agotado o respuesta vacía). Usa la estación, su
 * paleta y el catálogo, así la usuaria siempre recibe una respuesta útil.
 */
export function respuestaDeRespaldo(peticion: PeticionChat, catalogo: ItemCatalogoChat[]): string {
  const texto = normalizar(peticion.mensaje);
  const tiene = (...palabras: string[]) => palabras.some((p) => texto.includes(p));

  if (tiene("medic", "alergi", "irritac", "dermat", "acne", "enfermedad", "medicamento")) {
    return "Para temas de salud de la piel, como alergias o irritaciones, lo mejor es consultar " +
      "a un profesional de la salud. Con gusto te ayudo con colores, maquillaje y ropa.";
  }
  if (tiene("gracias")) return "¡Con gusto! Si quieres, pregúntame por labiales, ropa o los colores de tu paleta.";

  const { estacion, subtono } = peticion.contexto;
  if (!estacion) {
    return "Para recomendarte colores necesito conocer tu estación. Haz tu análisis en la " +
      "sección Colorimetría con una selfie y luego pregúntame por labiales, ropa o tu paleta.";
  }

  const paleta = PALETAS[estacion as Estacion];
  const perfil = `Como eres ${NOMBRE_ESTACION[estacion]}` + (subtono ? ` de subtono ${NOMBRE_SUBTONO[subtono]}` : "");
  const lista = (colores: { nombre: string }[], n: number) =>
    colores.slice(0, n).map((c) => c.nombre.toLowerCase()).join(", ");

  if (tiene("hola", "buenas", "buenos")) {
    return `¡Hola! ${perfil}, te favorecen tonos como ${lista(paleta.coloresRecomendados, 3)}. ` +
      "Pregúntame por labiales, sombras, rubor o ropa y te recomiendo opciones del catálogo.";
  }
  if (tiene("evitar", "no usar", "no me queda", "no me favorece")) {
    return `${perfil}, conviene evitar ${lista(paleta.coloresEvitar, 4)}: suelen apagar tu rostro. ` +
      `Mejor elige ${lista(paleta.coloresRecomendados, 3)}.`;
  }

  const tema = TEMAS.find((t) => t.palabras.some((p) => texto.includes(p)));
  const compatibles = catalogo.filter((i) => i.estaciones.includes(estacion));
  const elegidos = compatibles
    .filter((i) =>
      !tema
        ? true
        : tema.tema === "ropa"
          ? i.tipo === "prenda"
          : i.tipo === "producto" && tema.categorias.some((c) => normalizar(i.categoria).includes(c)),
    )
    .slice(0, 3);

  const colores = `${perfil}, te favorecen ${lista(paleta.coloresRecomendados, 4)}.`;
  const sugerencias = elegidos.length
    ? ` Del catálogo te pueden servir: ${elegidos.map((i) => `${i.nombre} (${i.marca})`).join("; ")}.`
    : " Revisa la sección Recomendaciones para ver productos de tu estación.";
  return colores + sugerencias;
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

    let catalogo: ItemCatalogoChat[] = [];
    try {
      catalogo = await catalogoParaChat(peticion.contexto.estacion);
    } catch (e) {
      logger.warn("chatAsistente: no se pudo leer el catálogo", { uid, error: String(e) });
    }

    const texto = await preguntarAGemini(uid, construirInstrucciones(peticion.contexto, catalogo), peticion);
    if (texto) {
      logger.info("chatAsistente", { uid, largo: texto.length });
      return { respuesta: texto };
    }
    // Sin IA (sin créditos, modelo retirado, tiempo agotado...): responde el
    // asesor de respaldo para que la usuaria nunca se quede sin respuesta.
    logger.warn("chatAsistente: respuesta de respaldo", { uid });
    return { respuesta: respuestaDeRespaldo(peticion, catalogo) };
  },
);

/** Texto de Gemini, o `null` si falla por cualquier motivo (queda en el log). */
async function preguntarAGemini(
  uid: string,
  instrucciones: string,
  peticion: PeticionChat,
): Promise<string | null> {
  try {
    const respuesta = await fetch(
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
    if (!respuesta.ok) {
      logger.error("chatAsistente: la IA respondió con error", {
        uid,
        status: respuesta.status,
        cuerpo: (await respuesta.text()).slice(0, 500),
      });
      return null;
    }
    const cuerpo = await respuesta.json();
    const texto = textoDeRespuesta(cuerpo);
    if (!texto) {
      logger.error("chatAsistente: la IA respondió sin texto", {
        uid,
        finishReason: (cuerpo as { candidates?: { finishReason?: string }[] })
          ?.candidates?.[0]?.finishReason,
        bloqueo: (cuerpo as { promptFeedback?: { blockReason?: string } })
          ?.promptFeedback?.blockReason,
      });
    }
    return texto;
  } catch (e) {
    logger.error("chatAsistente: no se pudo llamar a la IA", { uid, error: String(e) });
    return null;
  }
}
