// H-03 / H-08 — Prueba las reglas de Firestore y Storage contra el emulador local.
// Lo ejecuta probar_reglas.ps1 dentro de `firebase emulators:exec` con el proyecto
// "demo-auditoria" (los proyectos demo- nunca tocan Firebase real).
// Imprime una línea por caso: ESPERADO / OBTENIDO y un resumen final.

const PROYECTO = "demo-auditoria";
const FS = `http://127.0.0.1:8085/v1/projects/${PROYECTO}/databases/(default)/documents`;
const BUCKET = `${PROYECTO}.appspot.com`;
const ST = `http://127.0.0.1:9199/v0/b/${BUCKET}/o`;

// Token sin firma: el emulador lo acepta (no sirve contra Firebase real).
function token(uid, claims = {}) {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const ahora = Math.floor(Date.now() / 1000);
  return `${b64({ alg: "none", typ: "JWT" })}.${b64({
    iss: `https://securetoken.google.com/${PROYECTO}`, aud: PROYECTO, sub: uid, user_id: uid,
    iat: ahora, exp: ahora + 3600, auth_time: ahora, firebase: { sign_in_provider: "password" }, ...claims,
  })}.`;
}

const valor = (v) =>
  Array.isArray(v) ? { arrayValue: { values: v.map(valor) } }
  : typeof v === "boolean" ? { booleanValue: v }
  : typeof v === "number" ? { doubleValue: v }
  : { stringValue: String(v) };
const campos = (o) => ({ fields: Object.fromEntries(Object.entries(o).map(([k, v]) => [k, valor(v)])) });

async function sembrar(ruta, datos) {
  const r = await fetch(`${FS}/${ruta}`, {
    method: "PATCH", headers: { Authorization: "Bearer owner", "Content-Type": "application/json" },
    body: JSON.stringify(campos(datos)),
  });
  if (!r.ok) throw new Error(`No se pudo sembrar ${ruta}: ${r.status} ${await r.text()}`);
}

const producto = (marcaId) => ({
  marca: "Marca", categoria: "labial", precio: 10, marcaId,
  subtonoCompatible: ["calido"], estacionesCompatibles: ["otono"],
});

let fallos = 0;
function caso(nombre, esperado, status) {
  const obtenido = status >= 200 && status < 300 ? "PERMITIDO" : "DENEGADO";
  const ok = obtenido === esperado;
  if (!ok) fallos++;
  console.log(`${ok ? "OK   " : "FALLA"} | ${nombre.padEnd(62)} | esperado ${esperado.padEnd(9)} | obtenido ${obtenido} (${status})`);
}

async function crearProducto(id, tk, marcaId) {
  const r = await fetch(`${FS}/productosMaquillaje?documentId=${id}`, {
    method: "POST", headers: { Authorization: `Bearer ${tk}`, "Content-Type": "application/json" },
    body: JSON.stringify(campos(producto(marcaId))),
  });
  return r.status;
}

async function subir(ruta, tk) {
  const r = await fetch(`${ST}?name=${encodeURIComponent(ruta)}`, {
    method: "POST", headers: { Authorization: `Firebase ${tk}`, "Content-Type": "image/jpeg" },
    body: Buffer.from([0xff, 0xd8, 0xff, 0xd9]),
  });
  return r.status;
}

async function leer(ruta, tk) {
  const r = await fetch(`${ST}/${encodeURIComponent(ruta)}?alt=media`, {
    headers: { Authorization: `Firebase ${tk}` },
  });
  return r.status;
}

// ---------- Datos ----------
await sembrar("marcas/activa", { nombre: "Activa", activa: true, admins: ["ana@marca.co"] });
await sembrar("marcas/inactiva", { nombre: "Inactiva", activa: false, admins: ["luz@marca.co"] });

const ana = token("ana", { email: "ana@marca.co", marcaId: "activa" });          // admin vigente
const exAdmin = token("eva", { email: "eva@marca.co", marcaId: "activa" });     // claim viejo, ya no está en admins
const luz = token("luz", { email: "luz@marca.co", marcaId: "inactiva" });       // admin de marca desactivada
const u1 = token("u1", { email: "u1@correo.co" });
const u2 = token("u2", { email: "u2@correo.co" });

console.log("== H-03: catálogo de marcas (Firestore y Storage) ==");
caso("Admin vigente crea producto de su marca", "PERMITIDO", await crearProducto("p1", ana, "activa"));
caso("Ex-admin (claim viejo, fuera de admins) crea producto", "DENEGADO", await crearProducto("p2", exAdmin, "activa"));
caso("Admin de marca DESACTIVADA crea producto", "DENEGADO", await crearProducto("p3", luz, "inactiva"));
caso("Admin vigente sube imagen de su marca", "PERMITIDO", await subir("catalogo/marcas/activa/p1/foto.jpg", ana));
caso("Admin de marca DESACTIVADA sube imagen", "DENEGADO", await subir("catalogo/marcas/inactiva/p3/foto.jpg", luz));

console.log("== H-08: fotos de perfil (Storage) ==");
caso("Usuaria sube su propia foto de perfil", "PERMITIDO", await subir("perfiles/u1/foto.jpg", u1));
caso("Usuaria lee su propia foto de perfil", "PERMITIDO", await leer("perfiles/u1/foto.jpg", u1));
caso("OTRA usuaria lee esa foto de perfil", "DENEGADO", await leer("perfiles/u1/foto.jpg", u2));

console.log(`\nResultado: ${fallos === 0 ? "todas las reglas se comportan como se espera" : `${fallos} caso(s) no cumplen`}`);
process.exit(fallos === 0 ? 0 : 1);
