/**
 * Carga (o actualiza) el catálogo de prueba en Firestore — Ana:
 * `prendasRopa/{id}` y `productosMaquillaje/{id}` con PRENDAS y PRODUCTOS.
 *
 *   npm run sembrar:catalogo
 *
 * - Descarga la foto de cada ítem (Pexels, licencia libre) y la GUARDA en
 *   Firebase Storage (`catalogo/{prendas|productos}/{id}/ejemplo.jpg`), así
 *   la app no depende de Pexels.
 * - Ids fijos: si se corre otra vez, actualiza los mismos documentos y
 *   sobrescribe las mismas fotos (no duplica).
 * - Respeta las fotos que la admin haya subido con "Editar" en la app.
 *
 * Credenciales: `gcloud auth application-default login`, o la variable
 * GOOGLE_APPLICATION_CREDENTIALS apuntando a una clave de servicio (nunca
 * la subas al repo). Con FIRESTORE_EMULATOR_HOST escribe en el emulador.
 */
import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getDownloadURL, getStorage } from "firebase-admin/storage";
import {
  conservarFotoPropia,
  documentoPrenda,
  documentoProducto,
  rutaFotoEjemplo,
} from "./documentos_catalogo";
import { PRENDAS, PRODUCTOS, urlFoto } from "../datos/catalogo";

const PROYECTO = process.env.GCLOUD_PROJECT ?? "macke-up-ai";

async function main() {
  initializeApp({
    projectId: PROYECTO,
    storageBucket: process.env.STORAGE_BUCKET ?? `${PROYECTO}.firebasestorage.app`,
  });
  const db = getFirestore();
  const bucket = getStorage().bucket();
  const ahora = FieldValue.serverTimestamp();

  /** Descarga la foto de Pexels y la guarda en Storage. Devuelve su URL. */
  async function guardarFoto(carpeta: "prendas" | "productos", id: string, foto: number) {
    const respuesta = await fetch(urlFoto(foto));
    if (!respuesta.ok) throw new Error(`Pexels respondió ${respuesta.status} (foto ${foto})`);
    const bytes = Buffer.from(await respuesta.arrayBuffer());
    const ruta = rutaFotoEjemplo(carpeta, id);
    const archivo = bucket.file(ruta);
    await archivo.save(bytes, {
      contentType: "image/jpeg",
      metadata: { cacheControl: "public, max-age=604800" },
    });
    return { imagenURL: await getDownloadURL(archivo), imagenRuta: ruta };
  }

  const items = [
    ...PRENDAS.map((p) => ({
      coleccion: "prendasRopa",
      carpeta: "prendas" as const,
      id: p.id,
      foto: p.foto,
      datos: documentoPrenda(p),
    })),
    ...PRODUCTOS.map((p) => ({
      coleccion: "productosMaquillaje",
      carpeta: "productos" as const,
      id: p.id,
      foto: p.foto,
      datos: documentoProducto(p),
    })),
  ];

  let fotosGuardadas = 0;
  let fotosPropias = 0;
  const fallidas: string[] = [];
  const lote = db.batch();

  for (const item of items) {
    const ref = db.collection(item.coleccion).doc(item.id);
    const actual = (await ref.get()).data();
    let imagen: Record<string, unknown>;

    if (conservarFotoPropia(actual)) {
      imagen = { imagenURL: actual!.imagenURL, imagenRuta: actual!.imagenRuta };
      fotosPropias++;
    } else {
      try {
        imagen = await guardarFoto(item.carpeta, item.id, item.foto);
        fotosGuardadas++;
      } catch (e) {
        // Si una descarga falla, el ítem queda con el enlace de Pexels.
        fallidas.push(`${item.id}: ${String(e)}`);
        imagen = {};
      }
    }

    lote.set(ref, { ...item.datos, ...imagen, fechaActualizacion: ahora });
    console.log(`✓ ${item.id}`);
  }

  await lote.commit();
  console.log(
    `\nCatálogo cargado: ${PRENDAS.length} prendas y ${PRODUCTOS.length} productos.` +
      `\nFotos guardadas en Storage: ${fotosGuardadas}` +
      (fotosPropias ? `\nFotos subidas por la admin (se respetaron): ${fotosPropias}` : ""),
  );
  if (fallidas.length) {
    console.warn(`\nNo se pudieron guardar ${fallidas.length} fotos (quedan con el enlace de Pexels):`);
    for (const f of fallidas) console.warn(`  - ${f}`);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
