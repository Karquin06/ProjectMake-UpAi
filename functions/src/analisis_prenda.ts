/**
 * Color dominante de una prenda y compatibilidad con la paleta de la
 * usuaria (v1, sin servicios externos).
 *
 * - Color dominante: en el centro de la foto (50 % del ancho y alto, donde
 *   suele estar la prenda) se agrupan los píxeles en 8×8×8 cubos de color y
 *   se promedia el cubo más poblado.
 * - Compatibilidad: distancia ΔE (CIE76, en CIELAB) al color recomendado
 *   más cercano y al color a evitar más cercano.
 */
import { Estacion, rgbALab } from "./analisis_color";
import { ColorPaleta, PALETAS, Paleta } from "./datos/paletas";

export type Rgb = [number, number, number];

export interface ResultadoPrenda {
  colorHex: string;
  nombreColor: string;
  /** 0 a 100. */
  compatibilidad: number;
  motivo: string;
  coincideConPaleta: boolean;
}

/** ΔE por debajo del cual un color "coincide" con uno de la paleta. */
export const DELTA_COINCIDE = 20;

export const ETIQUETAS_ESTACION: Record<Estacion, string> = {
  primavera: "Primavera",
  verano: "Verano",
  otono: "Otoño",
  invierno: "Invierno",
};

export function colorDominante(
  pixeles: Uint8Array,
  ancho: number,
  alto: number,
  canales: number,
): Rgb {
  const cubos = new Map<number, { n: number; r: number; g: number; b: number }>();
  const x0 = Math.floor(ancho * 0.25);
  const x1 = Math.ceil(ancho * 0.75);
  const y0 = Math.floor(alto * 0.25);
  const y1 = Math.ceil(alto * 0.75);
  for (let y = y0; y < y1; y++) {
    for (let x = x0; x < x1; x++) {
      const i = (y * ancho + x) * canales;
      const r = pixeles[i];
      const g = pixeles[i + 1];
      const b = pixeles[i + 2];
      const clave = ((r >> 5) << 6) | ((g >> 5) << 3) | (b >> 5);
      const cubo = cubos.get(clave) ?? { n: 0, r: 0, g: 0, b: 0 };
      cubo.n++;
      cubo.r += r;
      cubo.g += g;
      cubo.b += b;
      cubos.set(clave, cubo);
    }
  }
  let mayor = { n: 0, r: 0, g: 0, b: 0 };
  for (const cubo of cubos.values()) if (cubo.n > mayor.n) mayor = cubo;
  if (mayor.n === 0) return [0, 0, 0];
  return [mayor.r / mayor.n, mayor.g / mayor.n, mayor.b / mayor.n].map(Math.round) as Rgb;
}

export function hexDe([r, g, b]: Rgb): string {
  return "#" + [r, g, b].map((c) => c.toString(16).padStart(2, "0")).join("").toUpperCase();
}

export function rgbDeHex(hex: string): Rgb {
  const limpio = hex.replace("#", "");
  return [0, 2, 4].map((i) => parseInt(limpio.slice(i, i + 2), 16)) as Rgb;
}

export function deltaE(a: Rgb, b: Rgb): number {
  const la = rgbALab(...a);
  const lb = rgbALab(...b);
  return Math.hypot(la.L - lb.L, la.a - lb.a, la.b - lb.b);
}

function masCercano(color: Rgb, lista: ColorPaleta[]) {
  let mejor: { color: ColorPaleta; distancia: number } | null = null;
  for (const c of lista) {
    const distancia = deltaE(color, rgbDeHex(c.hex));
    if (!mejor || distancia < mejor.distancia) mejor = { color: c, distancia };
  }
  return mejor;
}

/** Colores con nombre para describir cualquier prenda. */
const COLORES_BASICOS: ColorPaleta[] = [
  { nombre: "Blanco", hex: "#FFFFFF" },
  { nombre: "Negro", hex: "#111111" },
  { nombre: "Gris", hex: "#808080" },
  { nombre: "Gris claro", hex: "#C8C8C8" },
  { nombre: "Rojo", hex: "#D32F2F" },
  { nombre: "Rosa", hex: "#F48FB1" },
  { nombre: "Naranja", hex: "#F57C00" },
  { nombre: "Amarillo", hex: "#FBC02D" },
  { nombre: "Verde", hex: "#388E3C" },
  { nombre: "Azul", hex: "#1976D2" },
  { nombre: "Azul claro", hex: "#90CAF9" },
  { nombre: "Morado", hex: "#7B1FA2" },
  { nombre: "Marrón", hex: "#6D4C41" },
  { nombre: "Beige", hex: "#E8D8B8" },
  { nombre: "Denim", hex: "#3B5B84" },
];

const CATALOGO_NOMBRES: ColorPaleta[] = [
  ...COLORES_BASICOS,
  ...Object.values(PALETAS).flatMap((p) => [...p.coloresRecomendados, ...p.coloresEvitar]),
];

export function nombreDeColor(color: Rgb): string {
  return masCercano(color, CATALOGO_NOMBRES)?.color.nombre ?? "";
}

export function evaluarPrenda(color: Rgb, paleta: Paleta): ResultadoPrenda {
  const estacion = ETIQUETAS_ESTACION[paleta.estacion];
  const recomendado = masCercano(color, paleta.coloresRecomendados);
  const evitar = masCercano(color, paleta.coloresEvitar);
  const dRec = recomendado?.distancia ?? Infinity;
  const dEv = evitar?.distancia ?? Infinity;

  let compatibilidad = 100 - dRec * 2;
  if (dEv < dRec) compatibilidad = Math.min(compatibilidad, 45) - (dRec - dEv);
  compatibilidad = Math.round(Math.min(100, Math.max(0, compatibilidad)));

  const coincideConPaleta = dRec <= DELTA_COINCIDE && dRec <= dEv;
  let motivo: string;
  if (coincideConPaleta) {
    motivo = `Se parece a ${recomendado!.color.nombre}, de tu paleta de ${estacion}.`;
  } else if (evitar && dEv < dRec) {
    motivo = `Se acerca a ${evitar.color.nombre}, un color que conviene evitar en ${estacion}.`;
  } else if (recomendado) {
    motivo =
      `No está en tu paleta de ${estacion}; el color más cercano que te ` +
      `favorece es ${recomendado.color.nombre}.`;
  } else {
    motivo = `Tu paleta de ${estacion} no tiene colores para comparar.`;
  }

  return {
    colorHex: hexDe(color),
    nombreColor: nombreDeColor(color),
    compatibilidad,
    motivo,
    coincideConPaleta,
  };
}
