/**
 * Paletas de referencia por estación. Fuente única para:
 * - `npm run sembrar:paletas` (carga `paletas/{estacion}` en Firestore),
 * - `generarPaleta` (respaldo si el documento no existe).
 */
import type { Estacion } from "../analisis_color";

export interface ColorPaleta {
  nombre: string;
  hex: string;
}

export interface Paleta {
  estacion: Estacion;
  coloresRecomendados: ColorPaleta[];
  coloresEvitar: ColorPaleta[];
}

const c = (nombre: string, hex: string): ColorPaleta => ({ nombre, hex });

export const PALETAS: Record<Estacion, Paleta> = {
  primavera: {
    estacion: "primavera",
    coloresRecomendados: [
      c("Coral", "#FF7F50"),
      c("Melocotón", "#FFB07C"),
      c("Amarillo mantequilla", "#F8DE7E"),
      c("Verde manzana", "#8DB600"),
      c("Turquesa cálido", "#30D5C8"),
      c("Azul aguamarina", "#5FB3C5"),
      c("Rosa salmón", "#FA8072"),
      c("Camel claro", "#D2A86E"),
      c("Marfil", "#FFF8E7"),
      c("Rojo amapola", "#E35335"),
    ],
    coloresEvitar: [
      c("Negro", "#000000"),
      c("Gris carbón", "#36454F"),
      c("Borgoña", "#800020"),
      c("Azul marino oscuro", "#0B1F3A"),
      c("Blanco óptico", "#F4F4F8"),
      c("Ciruela", "#5E2750"),
    ],
  },
  verano: {
    estacion: "verano",
    coloresRecomendados: [
      c("Rosa empolvado", "#D8A1B0"),
      c("Lavanda", "#B4A7D6"),
      c("Azul cielo", "#87AFC7"),
      c("Azul pizarra", "#6A7FA0"),
      c("Malva", "#B784A7"),
      c("Frambuesa suave", "#C25A7C"),
      c("Verde salvia", "#9CAF88"),
      c("Gris perla", "#C9C9D1"),
      c("Blanco suave", "#F5F3EF"),
      c("Azul marino suave", "#3F4E6E"),
    ],
    coloresEvitar: [
      c("Naranja", "#F28C28"),
      c("Mostaza", "#D4A017"),
      c("Verde oliva", "#708238"),
      c("Marrón dorado", "#996515"),
      c("Negro", "#000000"),
      c("Rojo tomate", "#E5361F"),
    ],
  },
  otono: {
    estacion: "otono",
    coloresRecomendados: [
      c("Terracota", "#C8553D"),
      c("Mostaza", "#D4A017"),
      c("Verde oliva", "#708238"),
      c("Camel", "#C19A6B"),
      c("Óxido", "#B7410E"),
      c("Chocolate", "#5C3A21"),
      c("Verde bosque", "#2E5A3A"),
      c("Petróleo", "#1F5F6B"),
      c("Crema", "#F3E5C0"),
      c("Burdeos cálido", "#7B2D26"),
    ],
    coloresEvitar: [
      c("Fucsia", "#B0005A"),
      c("Azul eléctrico", "#2C75FF"),
      c("Rosa chicle", "#FF77BC"),
      c("Gris frío", "#A9B0BB"),
      c("Blanco óptico", "#F4F4F8"),
      c("Lavanda", "#B4A7D6"),
    ],
  },
  invierno: {
    estacion: "invierno",
    coloresRecomendados: [
      c("Azul clásico", "#0F4C81"),
      c("Fucsia", "#B0005A"),
      c("Esmeralda", "#00796B"),
      c("Vino", "#7F1734"),
      c("Carbón", "#2B2B2B"),
      c("Blanco óptico", "#F4F4F8"),
      c("Rojo frambuesa", "#C2185B"),
      c("Azul marino", "#1A2A4F"),
      c("Negro", "#000000"),
      c("Violeta intenso", "#5B2C83"),
    ],
    coloresEvitar: [
      c("Naranja", "#F28C28"),
      c("Mostaza", "#D4A017"),
      c("Camel", "#C19A6B"),
      c("Verde oliva", "#708238"),
      c("Beige", "#E8D8B8"),
      c("Marrón dorado", "#996515"),
    ],
  },
};
