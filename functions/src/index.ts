/**
 * Punto de entrada de Cloud Functions. Se edita por pull request entre
 * Jaider y Ana: cada quien exporta solo desde su sección.
 */
import { initializeApp } from "firebase-admin/app";

initializeApp();

// Colorimetría y análisis de imagen — Jaider
export { analizarSelfie, generarPaleta, limpiarImagenesTemporales } from "./colorimetria";
export { analizarPrenda } from "./escaner";

// IA, recomendaciones y cuenta — Ana
