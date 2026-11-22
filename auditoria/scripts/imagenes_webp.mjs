// Convierte a WebP las imágenes que van dentro del APK, para que pese menos:
//   - assets/images/*.png|jpg       (las que carga Flutter)
//   - android/app/src/main/res/**   (ícono y pantalla de arranque nativa)
// Solo reemplaza un archivo si el WebP pesa menos, y conserva la transparencia.
// Las imágenes ".9.png" (nine-patch) no se tocan.
//
// Uso (desde la raíz del repo; usa sharp de functions/node_modules):
//   node auditoria/scripts/imagenes_webp.mjs
// Correrlo de nuevo después de regenerar el ícono o el arranque con
// flutter_launcher_icons / flutter_native_splash, que vuelven a generar PNG.
import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";

const raiz = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")), "..", "..");
const require = createRequire(path.join(raiz, "functions", "package.json"));
const sharp = require("sharp");

const listar = (dir, filtro) => {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = path.join(dir, e.name);
    return e.isDirectory() ? listar(p, filtro) : filtro(p) ? [p] : [];
  });
};
const esImagen = (p) => /\.(png|jpe?g)$/i.test(p) && !/\.9\.png$/i.test(p);
const archivos = [
  ...listar(path.join(raiz, "assets", "images"), esImagen),
  ...listar(path.join(raiz, "android", "app", "src", "main", "res"), esImagen),
];

let antes = 0, despues = 0;
const cambios = [];
for (const archivo of archivos) {
  const original = fs.statSync(archivo).size;
  const esFoto = /\.jpe?g$/i.test(archivo);
  const datos = await sharp(archivo)
    .webp(esFoto ? { quality: 82, effort: 6 } : { quality: 90, alphaQuality: 100, effort: 6 })
    .toBuffer();
  antes += original;
  if (datos.length >= original) { despues += original; continue; }
  const destino = archivo.replace(/\.(png|jpe?g)$/i, ".webp");
  fs.writeFileSync(destino, datos);
  fs.unlinkSync(archivo);
  despues += datos.length;
  cambios.push([path.relative(raiz, archivo).split(path.sep).join("/"), original, datos.length]);
}
for (const [f, a, d] of cambios) {
  console.log(`${f.padEnd(70)} ${(a / 1024).toFixed(1).padStart(7)} KB -> ${(d / 1024).toFixed(1).padStart(6)} KB`);
}
console.log(`\n${cambios.length} imágenes convertidas: ${(antes / 1024).toFixed(0)} KB -> ${(despues / 1024).toFixed(0)} KB (${Math.round(100 - (despues / antes) * 100)} % menos)`);
