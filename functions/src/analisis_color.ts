/**
 * Análisis de colorimetría a partir de los píxeles de una selfie (v1).
 *
 * Heurística sin servicios externos:
 * 1. Brillo medio de la imagen → error `imagen-oscura`.
 * 2. Dentro del óvalo guía (el mismo que dibuja la app) se buscan píxeles
 *    de piel (regla YCbCr). Pocos píxeles de piel → `rostro-no-detectado`.
 * 3. Color medio de la piel en CIELAB:
 *    - ángulo de tono (h = atan2(b*, a*)) → subtono,
 *    - croma (C = √(a*² + b*²)) → intensidad,
 *    - luminosidad L* comparada con los rasgos oscuros (cejas, ojos,
 *      cabello: percentil 10 de L* en un óvalo ampliado) → contraste.
 * 4. Subtono + claridad + intensidad + contraste → estación.
 *
 * Los umbrales son una primera calibración; se ajustan en la Etapa 6
 * probando con distintas selfies.
 */

export type Estacion = "primavera" | "verano" | "otono" | "invierno";
export type Subtono = "calido" | "frio" | "neutro";
export type Contraste = "bajo" | "medio" | "alto";
export type Intensidad = "suave" | "media" | "brillante";

export interface ResultadoColorimetria {
  estacion: Estacion;
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
  tonoFrioMaximo: 52, // grados
  tonoCalidoMinimo: 60,
  tonoCalidoNeutro: 56, // para inclinar a los neutros
  claridadMinima: 62, // L* de piel "clara"
  contrasteAlto: 45, // diferencia de L*
  contrasteMedio: 28,
  cromaBrillante: 26,
  cromaMedia: 18,
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
  let pielTotal = 0;
  let sumaR = 0;
  let sumaG = 0;
  let sumaB = 0;
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
        if (esPiel(r, g, b)) {
          pielTotal++;
          sumaR += r;
          sumaG += g;
          sumaB += b;
        }
      }
    }
  }

  if (sumaLuma / (ancho * alto) < UMBRALES.lumaMinima) {
    throw new ErrorAnalisis("imagen-oscura");
  }
  const proporcionPiel = enOvaloTotal === 0 ? 0 : pielTotal / enOvaloTotal;
  if (proporcionPiel < UMBRALES.proporcionPielMinima) {
    throw new ErrorAnalisis("rostro-no-detectado");
  }

  lumaRegion.sort((p, q) => p - q);
  const oscurosL = lumaRegion[Math.floor(lumaRegion.length * 0.1)] ?? 0;
  return {
    pielLab: rgbALab(sumaR / pielTotal, sumaG / pielTotal, sumaB / pielTotal),
    oscurosL,
    proporcionPiel,
  };
}

export function clasificar(m: Medidas): ResultadoColorimetria {
  const u = UMBRALES;
  const { L, a, b } = m.pielLab;
  const tono = (Math.atan2(b, a) * 180) / Math.PI;
  const croma = Math.sqrt(a * a + b * b);
  const diferencia = L - m.oscurosL;
  const clara = L >= u.claridadMinima;

  const subtono: Subtono =
    tono <= u.tonoFrioMaximo ? "frio" : tono >= u.tonoCalidoMinimo ? "calido" : "neutro";
  const contraste: Contraste =
    diferencia >= u.contrasteAlto ? "alto" : diferencia >= u.contrasteMedio ? "medio" : "bajo";
  const intensidad: Intensidad =
    croma >= u.cromaBrillante ? "brillante" : croma >= u.cromaMedia ? "media" : "suave";

  let estacion: Estacion;
  if (subtono === "calido") {
    estacion = clara && intensidad !== "suave" ? "primavera" : "otono";
  } else if (subtono === "frio") {
    estacion = contraste === "alto" || intensidad === "brillante" ? "invierno" : "verano";
  } else {
    const inclinaCalido = tono >= u.tonoCalidoNeutro;
    if (contraste === "alto") estacion = "invierno";
    else if (clara) estacion = inclinaCalido ? "primavera" : "verano";
    else estacion = inclinaCalido ? "otono" : contraste === "bajo" ? "verano" : "invierno";
  }

  // Confianza: cuánta piel se vio y qué tan lejos está el tono de los
  // límites entre subtonos.
  const margenTono =
    subtono === "neutro"
      ? Math.min(tono - u.tonoFrioMaximo, u.tonoCalidoMinimo - tono)
      : subtono === "frio"
        ? u.tonoFrioMaximo - tono
        : tono - u.tonoCalidoMinimo;
  const factorPiel = Math.min(1, m.proporcionPiel / 0.5);
  const factorTono = Math.min(1, Math.max(0, margenTono) / 8);
  const confianza = Math.min(0.95, Math.max(0.35, 0.35 + 0.6 * (0.5 * factorPiel + 0.5 * factorTono)));

  return {
    estacion,
    subtono,
    contraste,
    intensidad,
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
