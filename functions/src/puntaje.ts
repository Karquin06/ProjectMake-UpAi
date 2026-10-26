/**
 * Puntaje de compatibilidad de un ítem del catálogo con la colorimetría de
 * la usuaria — Ana. Lógica pura (sin Firebase) para poder probarla.
 *
 * La app tiene una copia idéntica en
 * `lib/data/services/puntaje_compatibilidad.dart` (se usa mientras la
 * función no esté desplegada). Si cambias una, cambia la otra.
 *
 * Pesos (plan de trabajo: "estación con peso alto, subtono y ocasión"):
 * - Estación:  60 si el ítem es de la estación de la usuaria.
 * - Subtono:   25 si coincide; 12 si el ítem es "neutro" (le sirve a todas).
 * - Ocasión:   15 si se pidió una ocasión y el ítem la tiene. Si no se pidió
 *              ocasión (o es maquillaje, que no tiene), se dan los 15.
 * - Calificación previa de la usuaria (1 a 5): (calificacion - 3) × 5.
 * Resultado entre 0 y 100.
 */
import type { Estacion } from "./analisis_color";

export type Subtono = "calido" | "frio" | "neutro";

export interface ItemPuntuable {
  estacionesCompatibles: string[];
  subtonos: string[];
  ocasiones?: string[];
}

export interface PerfilPuntaje {
  estacion: Estacion;
  subtono: Subtono;
}

export interface Puntaje {
  puntaje: number;
  motivo: string;
}

const NOMBRE_ESTACION: Record<string, string> = {
  primavera: "Primavera",
  verano: "Verano",
  otono: "Otoño",
  invierno: "Invierno",
};

const NOMBRE_SUBTONO: Record<string, string> = {
  calido: "cálido",
  frio: "frío",
  neutro: "neutro",
};

const NOMBRE_OCASION: Record<string, string> = {
  trabajo: "el trabajo",
  casual: "un día casual",
  fiesta: "una fiesta",
  entrevista: "una entrevista",
  cita: "una cita",
  deporte: "hacer deporte",
};

export function puntuar(
  item: ItemPuntuable,
  perfil: PerfilPuntaje,
  ocasion?: string | null,
  calificacion?: number | null,
): Puntaje {
  let puntaje = 0;
  const razones: string[] = [];

  const deSuEstacion = item.estacionesCompatibles.includes(perfil.estacion);
  if (deSuEstacion) {
    puntaje += 60;
    razones.push(`Su color es de tu paleta ${NOMBRE_ESTACION[perfil.estacion]}`);
  }

  if (item.subtonos.includes(perfil.subtono)) {
    puntaje += 25;
    razones.push(`va con tu subtono ${NOMBRE_SUBTONO[perfil.subtono]}`);
  } else if (item.subtonos.includes("neutro")) {
    puntaje += 12;
    razones.push("es un tono neutro que favorece a casi todas las pieles");
  }

  const ocasiones = item.ocasiones ?? [];
  if (!ocasion || ocasiones.length === 0) {
    puntaje += 15;
  } else if (ocasiones.includes(ocasion)) {
    puntaje += 15;
    razones.push(`es ideal para ${NOMBRE_OCASION[ocasion] ?? ocasion}`);
  }

  if (calificacion && calificacion >= 1 && calificacion <= 5) {
    puntaje += (Math.round(calificacion) - 3) * 5;
  }
  puntaje = Math.max(0, Math.min(100, puntaje));

  let motivo: string;
  if (razones.length === 0) {
    motivo = "No es de tu paleta: úsalo lejos del rostro o combínalo con tus colores.";
  } else {
    const texto = razones.join(", ").replace(/, ([^,]*)$/, " y $1");
    motivo = texto.charAt(0).toUpperCase() + texto.slice(1) + ".";
  }
  if (!deSuEstacion && razones.length > 0) {
    motivo += " No es de tu estación, así que úsalo con moderación.";
  }
  return { puntaje, motivo };
}
