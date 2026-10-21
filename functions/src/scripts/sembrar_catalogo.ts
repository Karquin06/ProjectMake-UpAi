/**
 * Carga (o actualiza) el catálogo de prueba en Firestore — Ana:
 * `prendasRopa/{id}` y `productosMaquillaje/{id}` con PRENDAS y PRODUCTOS.
 *
 *   npm run sembrar:catalogo
 *
 * Usa ids fijos: si se corre otra vez, actualiza los mismos documentos
 * (no duplica). Los ítems quedan sin imagen; se les agrega desde la app
 * (Perfil → Administración → Catálogo → Editar).
 *
 * Credenciales: `gcloud auth application-default login`, o la variable
 * GOOGLE_APPLICATION_CREDENTIALS apuntando a una clave de servicio (nunca
 * la subas al repo). Con FIRESTORE_EMULATOR_HOST escribe en el emulador.
 */
import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { documentoPrenda, documentoProducto } from "./documentos_catalogo";
import { PRENDAS, PRODUCTOS } from "../datos/catalogo";

async function main() {
  initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? "macke-up-ai" });
  const db = getFirestore();
  const lote = db.batch();
  const ahora = FieldValue.serverTimestamp();

  for (const p of PRENDAS) {
    lote.set(db.collection("prendasRopa").doc(p.id), {
      ...documentoPrenda(p),
      fechaActualizacion: ahora,
    });
  }
  for (const p of PRODUCTOS) {
    lote.set(db.collection("productosMaquillaje").doc(p.id), {
      ...documentoProducto(p),
      fechaActualizacion: ahora,
    });
  }
  await lote.commit();
  console.log(
    `Catálogo cargado: ${PRENDAS.length} prendas y ${PRODUCTOS.length} productos.`,
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
