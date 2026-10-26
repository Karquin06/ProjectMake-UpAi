/**
 * Análisis de colorimetría a partir de los píxeles de una selfie (v2).
 *
 * Heurística sin servicios externos:
 * 1. Brillo medio de la imagen → error `imagen-oscura`.
 * 2. Dentro del óvalo guía (el mismo que dibuja la app) se buscan píxeles
 *    de piel (regla YCbCr). Pocos píxeles de piel → `rostro-no-detectado`.
 *    Se quitan brillos y sombras (10 % más claro y más oscuro) y se usa la
 *    mediana.
 * 3. Color de la piel en CIELAB:
 *    - ángulo de tono (h = atan2(b*, a*)) → subtono (límite rojo/amarillo
 *      en 55°, franja neutra de ±3°),
 *    - ángulo ITA = atan((L* − 50) / b*) → piel clara (≥ 41°, Chardon),
 *    - croma (C = √(a*² + b*²)) → intensidad,
 *    - luminosidad L* comparada con los rasgos oscuros (cejas, ojos,
 *      cabello: percentil 10 de L* en un óvalo ampliado) → contraste.
 * 4. Subtono + claridad + intensidad + contraste → estación, y la segunda
 *    más probable: la que sale al cruzar el límite más cercano.
 *
 * Misma lógica que `lib/data/services/analisis/analisis_color.dart`, salvo
 * el balance de blancos con la esclera: aquí no se detectan los ojos.
 * Umbrales y fuentes: "Estudio para calibrar el análisis de colorimetría"
 * (25/10/2026).
 */

export type Estacion = "primavera" | "verano" | "otono" | "invierno";
export type Subtono = "calido" | "frio" | "neutro";
export type Contraste = "bajo" | "medio" | "alto";
export type Intensidad = "suave" | "media" | "brillante";

export interface ResultadoColorimetria {
  estacion: Estacion;
  /** Segunda estación más probable. */
  estacionAlternativa: Estacion;
  subtono: Subtono;
  contraste: Contraste;
  intensidad: Intensidad;
  /** 0 a 1. */
  confianza: number;
}

export type CodigoErrorAnalisis = "rostro-no-detectado" | "imagen-oscura";

export class ErrorAnalisis extends Error {
  constructor(readonly codigo: CodigoErrorAnalisis) {
    super(codigo);
    this.name = "ErrorAnalisis";
  }
}

/** Óvalo guía, en fracciones del ancho y alto (igual que GuiaCapturaSelfie). */
export const OVALO = { cx: 0.5, cy: 0.45, rx: 0.32, ry: 0.38 };

export const UMBRALES = {
  lumaMinima: 60, // brillo medio 0-255
  proporcionPielMinima: 0.2,
  tonoFrioMaximo: 52, // grados; frío por debajo
  tonoCalidoMinimo: 58, // cálido por encima
  tonoRojoAmarillo: 55, // inclina a los neutros
  itaClara: 41, // grados; "muy clara" y "clara"
  contrasteAlto: 45, // diferencia de L*
  contrasteMedio: 28,
  cromaBrillante: 20,
  cromaMedia: 14,
  recortePiel: 0.1, // brillos y sombras, por cada extremo
};

export interface Lab {
  L: number;
  a: number;
  b: number;
}

/** sRGB (0-255) → CIELAB (D65). */
export function rgbALab(r: number, g: number, b: number): Lab {
  const lineal = (c: number) => {
    const v = c / 255;
    return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
  };
  const R = lineal(r);
  const G = lineal(g);
  const B = lineal(b);
  const x = (R * 0.4124 + G * 0.3576 + B * 0.1805) / 0.95047;
  const y = R * 0.2126 + G * 0.7152 + B * 0.0722;
  const z = (R * 0.0193 + G * 0.1192 + B * 0.9505) / 1.08883;
  const f = (t: number) => (t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116);
  const fx = f(x);
  const fy = f(y);
  const fz = f(z);
  return { L: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz) };
}

/** Regla clásica de piel en YCbCr (válida para tonos claros y oscuros). */
export function esPiel(r: number, g: number, b: number): boolean {
  const cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
  const cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;
  const y = 0.299 * r + 0.587 * g + 0.114 * b;
  return y > 40 && cb >= 77 && cb <= 127 && cr >= 133 && cr <= 173;
}

function enOvalo(x: number, y: number, ancho: number, alto: number, escala = 1) {
  const dx = (x / ancho - OVALO.cx) / (OVALO.rx * escala);
  const dy = (y / alto - OVALO.cy) / (OVALO.ry * escala);
  return dx * dx + dy * dy <= 1;
}

export interface Medidas {
  pielLab: Lab;
  /** L* de los rasgos oscuros (percentil 10 del óvalo ampliado). */
  oscurosL: number;
  proporcionPiel: number;
}

function mediana(valores: number[]): number {
  const orden = [...valores].sort((p, q) => p - q);
  const m = Math.floor(orden.length / 2);
  return orden.length % 2 === 1 ? orden[m] : (orden[m - 1] + orden[m]) / 2;
}

/** Quita brillos y sombras y devuelve la mediana de L*, a* y b*. */
function medianaSinExtremos(piel: Lab[]): Lab {
  const porL = [...piel].sort((p, q) => p.L - q.L);
  const corte = Math.floor(porL.length * UMBRALES.recortePiel);
  const centro = porL.slice(corte, porL.length - corte);
  const usar = centro.length > 0 ? centro : porL;
  return {
    L: mediana(usar.map((c) => c.L)),
    a: mediana(usar.map((c) => c.a)),
    b: mediana(usar.map((c) => c.b)),
  };
}

/**
 * Mide la imagen en formato crudo (RGB o RGBA, fila por fila).
 * Lanza [ErrorAnalisis] si está oscura o no hay rostro.
 */
export function medir(
  pixeles: Uint8Array,
  ancho: number,
  alto: number,
  canales: number,
): Medidas {
  let sumaLuma = 0;
  let enOvaloTotal = 0;
  const piel: Lab[] = [];
  const lumaRegion: number[] = [];

  for (let y = 0; y < alto; y++) {
    for (let x = 0; x < ancho; x++) {
      const i = (y * ancho + x) * canales;
      const r = pixeles[i];
      const g = pixeles[i + 1];
      const b = pixeles[i + 2];
      sumaLuma += 0.299 * r + 0.587 * g + 0.114 * b;

      if (enOvalo(x, y, ancho, alto, 1.2)) {
        lumaRegion.push(rgbALab(r, g, b).L);
      }
      if (enOvalo(x, y, ancho, alto)) {
        enOvaloTotal++;
        if (esPiel(r, g, b)) piel.push(rgbALab(r, g, b));
      }
    }
  }

  if (sumaLuma / (ancho * alto) < UMBRALES.lumaMinima) {
    throw new ErrorAnalisis("imagen-oscura");
  }
  const proporcionPiel = enOvaloTotal === 0 ? 0 : piel.length / enOvaloTotal;
  if (proporcionPiel < UMBRALES.proporcionPielMinima) {
    throw new ErrorAnalisis("rostro-no-detectado");
  }

  lumaRegion.sort((p, q) => p - q);
  const oscurosL = lumaRegion[Math.floor(lumaRegion.length * 0.1)] ?? 0;
  return { pielLab: medianaSinExtremos(piel), oscurosL, proporcionPiel };
}

/** Valores de la piel que deciden la estación. */
interface Rasgos {
  tono: number;
  ita: number;
  croma: number;
  diferencia: number;
}

function subtonoDe(r: Rasgos): Subtono {
  const u = UMBRALES;
  return r.tono < u.tonoFrioMaximo ? "frio" : r.tono > u.tonoCalidoMinimo ? "calido" : "neutro";
}

function contrasteDe(r: Rasgos): Contraste {
  const u = UMBRALES;
  return r.diferencia >= u.contrasteAlto
    ? "alto"
    : r.diferencia >= u.contrasteMedio
      ? "medio"
      : "bajo";
}

function intensidadDe(r: Rasgos): Intensidad {
  const u = UMBRALES;
  return r.croma >= u.cromaBrillante ? "brillante" : r.croma >= u.cromaMedia ? "media" : "suave";
}

function estacionDe(r: Rasgos): Estacion {
  const clara = r.ita >= UMBRALES.itaClara;
  const contraste = contrasteDe(r);
  const intensidad = intensidadDe(r);
  switch (subtonoDe(r)) {
    case "calido":
      return clara && intensidad !== "suave" ? "primavera" : "otono";
    case "frio":
      return contraste === "alto" || intensidad === "brillante" ? "invierno" : "verano";
    case "neutro": {
      const inclinaCalido = r.tono >= UMBRALES.tonoRojoAmarillo;
      if (contraste === "alto") return "invierno";
      if (clara) return inclinaCalido ? "primavera" : "verano";
      return inclinaCalido ? "otono" : contraste === "bajo" ? "verano" : "invierno";
    }
  }
}

/** Cortes de cada dimensión y cuánto vale "un paso" de incertidumbre. */
const LIMITES: { campo: keyof Rasgos; cortes: number[]; escala: number }[] = [
  {
    campo: "tono",
    cortes: [UMBRALES.tonoFrioMaximo, UMBRALES.tonoRojoAmarillo, UMBRALES.tonoCalidoMinimo],
    escala: 3,
  },
  { campo: "ita", cortes: [UMBRALES.itaClara], escala: 5 },
  { campo: "croma", cortes: [UMBRALES.cromaMedia, UMBRALES.cromaBrillante], escala: 3 },
  { campo: "diferencia", cortes: [UMBRALES.contrasteMedio, UMBRALES.contrasteAlto], escala: 6 },
];

const PAREJA: Record<Estacion, Estacion> = {
  primavera: "otono",
  otono: "primavera",
  verano: "invierno",
  invierno: "verano",
};

/** Estación al otro lado del límite más cercano que la cambia y su distancia. */
function alternativa(r: Rasgos): [Estacion, number] {
  const actual = estacionDe(r);
  let mejor: [Estacion, number] = [PAREJA[actual], 2];
  for (const { campo, cortes, escala } of LIMITES) {
    const v = r[campo];
    for (const corte of cortes) {
      const otra = estacionDe({ ...r, [campo]: v < corte ? corte + 0.01 : corte - 0.01 });
      const distancia = Math.abs(v - corte) / escala;
      if (otra !== actual && distancia < mejor[1]) mejor = [otra, distancia];
    }
  }
  return mejor;
}

export function clasificar(m: Medidas): ResultadoColorimetria {
  const { L, a, b } = m.pielLab;
  const rasgos: Rasgos = {
    tono: (Math.atan2(b, a) * 180) / Math.PI,
    ita: (Math.atan2(L - 50, b) * 180) / Math.PI,
    croma: Math.sqrt(a * a + b * b),
    diferencia: L - m.oscurosL,
  };
  const [estacionAlternativa, distancia] = alternativa(rasgos);

  // Confianza: cuánta piel se vio y qué tan lejos está el límite que
  // cambiaría la estación. Sin balance con la esclera se resta 0,05.
  const factorPiel = Math.min(1, m.proporcionPiel / 0.5);
  const factorLimite = Math.min(1, distancia / 2);
  const confianza = Math.min(
    0.95,
    Math.max(0.35, 0.35 + 0.6 * (0.3 * factorPiel + 0.7 * factorLimite) - 0.05),
  );

  return {
    estacion: estacionDe(rasgos),
    estacionAlternativa,
    subtono: subtonoDe(rasgos),
    contraste: contrasteDe(rasgos),
    intensidad: intensidadDe(rasgos),
    confianza: Math.round(confianza * 100) / 100,
  };
}

export function analizarPixeles(
  pixeles: Uint8Array,
  ancho: number,
  alto: number,
  canales: number,
): ResultadoColorimetria {
  return clasificar(medir(pixeles, ancho, alto, canales));
}
