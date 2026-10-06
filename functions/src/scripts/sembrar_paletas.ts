/**
 * Carga (o actualiza) `paletas/{estacion}` en Firestore con PALETAS.
 *
 *   npm run sembrar:paletas
 *
 * Credenciales: `gcloud auth application-default login`, o la variable
 * GOOGLE_APPLICATION_CREDENTIALS apuntando a una clave de servicio (nunca
 * la subas al repo). Con FIRESTORE_EMULATOR_HOST escribe en el emulador.
 */
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { PALETAS } from "../datos/paletas";

async function main() {
  initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? "make-up--ai" });
  const db = getFirestore();
  const lote = db.batch();
  for (const paleta of Object.values(PALETAS)) {
    lote.set(db.collection("paletas").doc(paleta.estacion), paleta);
  }
  await lote.commit();
  console.log(`Paletas cargadas: ${Object.keys(PALETAS).join(", ")}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
