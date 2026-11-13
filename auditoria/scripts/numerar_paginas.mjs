// Numera las páginas del PDF del informe.
//   apa      -> número arriba a la derecha en todas las páginas (APA 7)
//   unicesar -> pie como la guía de la tarea: texto a la izquierda y "Página X de Y" a la derecha
// Uso: node numerar_paginas.mjs <carpeta-con-pdf-lib> <archivo.pdf> [apa|unicesar]
import { createRequire } from "node:module";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const [carpeta, archivo, modo = "apa"] = process.argv.slice(2);
const require = createRequire(join(carpeta, "package.json"));
const { PDFDocument, StandardFonts, rgb } = require("pdf-lib");

const pdf = await PDFDocument.load(readFileSync(archivo));
const paginas = pdf.getPages();
const total = paginas.length;

if (modo === "unicesar") {
  const fuente = await pdf.embedFont(StandardFonts.Helvetica);
  const gris = rgb(0x56 / 255, 0x63 / 255, 0x5b / 255); // #56635b, color del pie en la guía
  const tamano = 8.5;
  const margen = 51; // 18 mm
  const izquierda = "Programación Móvil · Seguridad en aplicaciones móviles";
  paginas.forEach((pagina, i) => {
    const { width } = pagina.getSize();
    const derecha = `Página ${i + 1} de ${total}`;
    pagina.drawText(izquierda, { x: margen, y: 30, size: tamano, font: fuente, color: gris });
    pagina.drawText(derecha, {
      x: width - margen - fuente.widthOfTextAtSize(derecha, tamano), y: 30, size: tamano, font: fuente, color: gris,
    });
  });
} else {
  const fuente = await pdf.embedFont(StandardFonts.TimesRoman);
  const tamano = 12;
  const margen = 72; // 2,54 cm
  paginas.forEach((pagina, i) => {
    const texto = String(i + 1);
    const { width, height } = pagina.getSize();
    pagina.drawText(texto, {
      x: width - margen - fuente.widthOfTextAtSize(texto, tamano),
      y: height - margen / 2 - tamano / 2,
      size: tamano, font: fuente, color: rgb(0, 0, 0),
    });
  });
}
writeFileSync(archivo, await pdf.save());
console.log(`Páginas numeradas (${modo}): ${total}`);
