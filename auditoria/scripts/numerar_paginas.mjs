// APA 7: número de página arriba a la derecha en todas las páginas (incluida la portada).
// Uso: node numerar_paginas.mjs <carpeta-con-pdf-lib> <archivo.pdf>
import { createRequire } from "node:module";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const [carpeta, archivo] = process.argv.slice(2);
const require = createRequire(join(carpeta, "package.json"));
const { PDFDocument, StandardFonts, rgb } = require("pdf-lib");

const pdf = await PDFDocument.load(readFileSync(archivo));
const fuente = await pdf.embedFont(StandardFonts.TimesRoman);
const tamano = 12;
const margen = 72; // 2,54 cm
pdf.getPages().forEach((pagina, i) => {
  const texto = String(i + 1);
  const { width, height } = pagina.getSize();
  pagina.drawText(texto, {
    x: width - margen - fuente.widthOfTextAtSize(texto, tamano),
    y: height - margen / 2 - tamano / 2,
    size: tamano, font: fuente, color: rgb(0, 0, 0),
  });
});
writeFileSync(archivo, await pdf.save());
console.log(`Páginas numeradas: ${pdf.getPageCount()}`);
