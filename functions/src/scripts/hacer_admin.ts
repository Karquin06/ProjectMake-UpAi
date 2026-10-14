/**
 * Marca (o desmarca) una cuenta como administradora del catálogo:
 * - custom claim `admin: true` en Firebase Auth (lo exigen las reglas de
 *   productosMaquillaje y prendasRopa),
 * - `rol: "admin"` en usuarias/{uid} (lo usa la app para abrir el catálogo).
 *
 *   npm run hacer:admin -- mackeupai@gmail.com   (única cuenta admin)
 *   npm run hacer:admin -- correo@ejemplo.com --quitar
 *
 * Credenciales: GOOGLE_APPLICATION_CREDENTIALS con la ruta de una clave de
 * cuenta de servicio (Consola → Configuración del proyecto → Cuentas de
 * servicio → Generar nueva clave privada). Guárdala FUERA del repositorio.
 *
 * La cuenta debe existir (registrarse antes en la app). Después del cambio,
 * la usuaria debe cerrar sesión y volver a entrar para que su token tenga
 * el claim.
 */
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

/** Única cuenta administradora del proyecto (decisión del equipo). */
const CORREO_ADMIN = "mackeupai@gmail.com";

async function main() {
  const [correo, opcion] = process.argv.slice(2);
  if (!correo || !correo.includes("@")) {
    console.error("Uso: npm run hacer:admin -- correo@ejemplo.com [--quitar]");
    process.exit(1);
  }
  const quitar = opcion === "--quitar";
  if (!quitar && correo.trim().toLowerCase() !== CORREO_ADMIN) {
    console.error(`Solo ${CORREO_ADMIN} puede ser admin.`);
    process.exit(1);
  }

  initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? "macke-up-ai" });
  const auth = getAuth();
  const usuaria = await auth.getUserByEmail(correo);

  const claims = { ...(usuaria.customClaims ?? {}) };
  if (quitar) delete claims.admin;
  else claims.admin = true;
  await auth.setCustomUserClaims(usuaria.uid, claims);

  await getFirestore()
    .collection("usuarias")
    .doc(usuaria.uid)
    .set({ rol: quitar ? "usuaria" : "admin" }, { merge: true });

  console.log(
    `${correo} (${usuaria.uid}) ${quitar ? "ya no es" : "ahora es"} admin. ` +
      "Debe cerrar sesión y volver a entrar.",
  );
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});
