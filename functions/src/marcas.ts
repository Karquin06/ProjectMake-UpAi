/**
 * Marcas de maquillaje — Ana.
 *
 * - asignarAdminMarca: la admin general le da (o le quita) a una cuenta el
 *   permiso de administrar una marca (custom claim `marcaId`).
 * - alCalificarProducto / alMarcarMeGusta: cada vez que una usuaria califica
 *   o le da ❤️ a un producto, se actualizan sus estadísticas.
 * - registrarEvento: cuenta vistas del detalle y pruebas en AR (una por
 *   usuaria y producto).
 * - resumenMarca / resumenAdmin: los datos de los dashboards.
 *
 * Privacidad (habeas data): las marcas solo ven TOTALES. Las estadísticas
 * guardan a cada usuaria con un código (hash) y nunca su uid, correo o
 * nombre; cuando ella borra su calificación, su ❤️ o su cuenta, su aporte se
 * resta y su registro se borra.
 */
import { createHash } from "node:crypto";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore, type Query } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { REGION, errorNegocio, exigirSesion } from "./comun";

export const ESTACIONES = ["primavera", "verano", "otono", "invierno"] as const;
export type EstacionMarca = (typeof ESTACIONES)[number];

/** Única cuenta administradora general (la misma de hacer_admin). */
export const CORREO_ADMIN = "mackeupai@gmail.com";

export const COLECCION_MARCAS = "marcas";
export const COLECCION_ESTADISTICAS = "estadisticasProductos";

/** Estrellas desde las que se cuenta que a la usuaria "le gustó". */
export const ESTRELLAS_GUSTA = 4;

// ─────────────────────────── Lógica pura ───────────────────────────

/** Lo que cada usuaria aporta a las estadísticas de un producto. */
export interface RegistroUsuaria {
  estrellas: number | null;
  corazon: boolean;
  estacion: EstacionMarca | null;
}

export const REGISTRO_VACIO: RegistroUsuaria = { estrellas: null, corazon: false, estacion: null };

export function esEstacionMarca(v: unknown): v is EstacionMarca {
  return typeof v === "string" && (ESTACIONES as readonly string[]).includes(v);
}

/** "Le gustó" = le dio ❤️ o lo calificó con 4 o 5 estrellas. */
export function leGusta(r: RegistroUsuaria): boolean {
  return r.corazon || (r.estrellas !== null && r.estrellas >= ESTRELLAS_GUSTA);
}

export function registroVacio(r: RegistroUsuaria): boolean {
  return r.estrellas === null && !r.corazon;
}

/** Normaliza un registro leído de Firestore. */
export function leerRegistro(d: Record<string, unknown> | undefined): RegistroUsuaria {
  if (!d) return { ...REGISTRO_VACIO };
  const e = d.estrellas;
  return {
    estrellas: typeof e === "number" && e >= 1 && e <= 5 ? Math.round(e) : null,
    corazon: d.corazon === true,
    estacion: esEstacionMarca(d.estacion) ? d.estacion : null,
  };
}

/**
 * Cuánto cambian los contadores de un producto cuando el registro de una
 * usuaria pasa de [antes] a [despues]. Solo devuelve los campos que cambian.
 */
export function deltaEstadisticas(
  antes: RegistroUsuaria,
  despues: RegistroUsuaria,
): Record<string, number> {
  const d: Record<string, number> = {};
  const sumar = (campo: string, n: number) => {
    if (n !== 0) d[campo] = (d[campo] ?? 0) + n;
  };
  const gustaAntes = leGusta(antes) ? 1 : 0;
  const gustaDespues = leGusta(despues) ? 1 : 0;
  sumar("gusta", gustaDespues - gustaAntes);
  sumar("corazones", (despues.corazon ? 1 : 0) - (antes.corazon ? 1 : 0));
  sumar("calificaciones", (despues.estrellas !== null ? 1 : 0) - (antes.estrellas !== null ? 1 : 0));
  sumar("sumaEstrellas", (despues.estrellas ?? 0) - (antes.estrellas ?? 0));
  if (gustaAntes && antes.estacion) sumar(`porEstacion.${antes.estacion}`, -1);
  if (gustaDespues && despues.estacion) sumar(`porEstacion.${despues.estacion}`, 1);
  for (const campo of Object.keys(d)) if (d[campo] === 0) delete d[campo];
  return d;
}

/** Código anónimo de la usuaria dentro de las estadísticas (no se puede revertir al uid). */
export function codigoAnonimo(uid: string): string {
  return createHash("sha256").update(`makeupai:${uid}`).digest("hex").slice(0, 32);
}

export type EventoProducto = "vista" | "pruebaAr";
const CAMPO_EVENTO: Record<EventoProducto, string> = { vista: "vistas", pruebaAr: "pruebasAr" };

export function leerEvento(data: unknown): { productoId: string; evento: EventoProducto } {
  const d = (data ?? {}) as Record<string, unknown>;
  const productoId = typeof d.productoId === "string" ? d.productoId.trim() : "";
  if (!productoId || productoId.includes("/") || productoId.length > 200) {
    throw new HttpsError("invalid-argument", "Producto no válido.");
  }
  if (d.evento !== "vista" && d.evento !== "pruebaAr") {
    throw new HttpsError("invalid-argument", "Evento no válido.");
  }
  return { productoId, evento: d.evento };
}

export function leerAsignacion(data: unknown): { correo: string; marcaId: string | null } {
  const d = (data ?? {}) as Record<string, unknown>;
  const correo = typeof d.correo === "string" ? d.correo.trim().toLowerCase() : "";
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(correo)) {
    throw new HttpsError("invalid-argument", "Escribe un correo válido.");
  }
  const marcaId =
    d.marcaId === null || d.marcaId === undefined
      ? null
      : typeof d.marcaId === "string" && d.marcaId.trim() && !d.marcaId.includes("/")
        ? d.marcaId.trim()
        : undefined;
  if (marcaId === undefined) throw new HttpsError("invalid-argument", "Marca no válida.");
  return { correo, marcaId };
}

/** Estadísticas de un producto tal como las muestra el dashboard. */
export interface FilaProducto {
  id: string;
  nombre: string;
  categoria: string;
  colorHex: string;
  imagenURL: string;
  activo: boolean;
  gusta: number;
  corazones: number;
  calificaciones: number;
  promedio: number;
  vistas: number;
  pruebasAr: number;
}

export interface Totales {
  productos: number;
  gusta: number;
  corazones: number;
  calificaciones: number;
  promedio: number;
  vistas: number;
  pruebasAr: number;
  porEstacion: Record<EstacionMarca, number>;
}

const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : 0);
const redondear = (n: number) => Math.round(n * 10) / 10;

export function porEstacionVacio(): Record<EstacionMarca, number> {
  return { primavera: 0, verano: 0, otono: 0, invierno: 0 };
}

/** Une un producto con sus estadísticas. */
export function filaProducto(
  id: string,
  producto: Record<string, unknown>,
  estadistica: Record<string, unknown> | undefined,
): FilaProducto {
  const e = estadistica ?? {};
  const calificaciones = num(e.calificaciones);
  return {
    id,
    nombre: String(producto.nombre || producto.marca || id),
    categoria: String(producto.categoria ?? ""),
    colorHex: String(producto.colorHex ?? ""),
    imagenURL: String(producto.imagenURL ?? ""),
    activo: producto.activo !== false,
    gusta: num(e.gusta),
    corazones: num(e.corazones),
    calificaciones,
    promedio: calificaciones > 0 ? redondear(num(e.sumaEstrellas) / calificaciones) : 0,
    vistas: num(e.vistas),
    pruebasAr: num(e.pruebasAr),
  };
}

/** Suma las filas y ordena de más a menos "le gustó". */
export function resumir(
  filas: FilaProducto[],
  estadisticas: (Record<string, unknown> | undefined)[],
): { totales: Totales; productos: FilaProducto[] } {
  const porEstacion = porEstacionVacio();
  let sumaEstrellas = 0;
  for (const e of estadisticas) {
    sumaEstrellas += num(e?.sumaEstrellas);
    const pe = (e?.porEstacion ?? {}) as Record<string, unknown>;
    for (const est of ESTACIONES) porEstacion[est] += num(pe[est]);
  }
  const calificaciones = filas.reduce((s, f) => s + f.calificaciones, 0);
  const productos = [...filas].sort(
    (a, b) => b.gusta - a.gusta || b.promedio - a.promedio || a.nombre.localeCompare(b.nombre),
  );
  return {
    totales: {
      productos: filas.length,
      gusta: filas.reduce((s, f) => s + f.gusta, 0),
      corazones: filas.reduce((s, f) => s + f.corazones, 0),
      calificaciones,
      promedio: calificaciones > 0 ? redondear(sumaEstrellas / calificaciones) : 0,
      vistas: filas.reduce((s, f) => s + f.vistas, 0),
      pruebasAr: filas.reduce((s, f) => s + f.pruebasAr, 0),
      porEstacion,
    },
    productos,
  };
}

// ─────────────────────────── Firestore ───────────────────────────

async function estacionDe(uid: string): Promise<EstacionMarca | null> {
  const perfil = await getFirestore().collection("perfiles_colorimetria").doc(uid).get();
  const e = perfil.get("estacion");
  return esEstacionMarca(e) ? e : null;
}

/**
 * Aplica un cambio al registro de la usuaria en un producto y ajusta los
 * contadores del producto en la misma transacción.
 */
async function actualizarRegistro(
  uid: string,
  productoId: string,
  cambio: Partial<Pick<RegistroUsuaria, "estrellas" | "corazon">>,
): Promise<void> {
  const db = getFirestore();
  const estadRef = db.collection(COLECCION_ESTADISTICAS).doc(productoId);
  const regRef = estadRef.collection("usuarias").doc(codigoAnonimo(uid));
  const estacionActual = await estacionDe(uid);

  await db.runTransaction(async (tx) => {
    const [regSnap, productoSnap] = await Promise.all([
      tx.get(regRef),
      tx.get(db.collection("productosMaquillaje").doc(productoId)),
    ]);
    const antes = leerRegistro(regSnap.data());
    const despues: RegistroUsuaria = {
      ...antes,
      ...cambio,
      // Si la cuenta ya no tiene perfil (p. ej. la está borrando), se conserva
      // la estación con la que contó, para restarla bien.
      estacion: estacionActual ?? antes.estacion,
    };
    const delta = deltaEstadisticas(antes, despues);
    if (Object.keys(delta).length > 0 || !regSnap.exists) {
      const datos: Record<string, unknown> = {
        actualizado: FieldValue.serverTimestamp(),
        marcaId: productoSnap.get("marcaId") ?? null,
      };
      for (const [campo, n] of Object.entries(delta)) datos[campo] = FieldValue.increment(n);
      tx.set(estadRef, expandir(datos), { merge: true });
    }
    if (registroVacio(despues)) tx.delete(regRef);
    else tx.set(regRef, { ...despues, actualizado: FieldValue.serverTimestamp() });
  });
}

/** `{"porEstacion.otono": x}` → `{porEstacion: {otono: x}}` para set con merge. */
export function expandir(datos: Record<string, unknown>): Record<string, unknown> {
  const salida: Record<string, unknown> = {};
  for (const [clave, valor] of Object.entries(datos)) {
    const [a, b] = clave.split(".");
    if (b === undefined) salida[a] = valor;
    else salida[a] = { ...((salida[a] as Record<string, unknown>) ?? {}), [b]: valor };
  }
  return salida;
}

/** Calificaciones de productos (usuarias/{uid}/recomendaciones/{id}). */
export const alCalificarProducto = onDocumentWritten(
  { document: "usuarias/{uid}/recomendaciones/{id}", region: REGION },
  async (evento) => {
    const antes = evento.data?.before.data();
    const despues = evento.data?.after.data();
    const productoId = (despues?.productoId ?? antes?.productoId) as string | undefined;
    if (typeof productoId !== "string" || !productoId) return;
    const c = despues?.calificacion;
    const estrellas = typeof c === "number" && c >= 1 && c <= 5 ? Math.round(c) : null;
    const previa = antes?.calificacion ?? null;
    if (despues && estrellas === previa) return; // no cambió la calificación
    await actualizarRegistro(evento.params.uid, productoId, { estrellas });
  },
);

/** ❤️ de productos (usuarias/{uid}/meGusta/{itemId}). */
export const alMarcarMeGusta = onDocumentWritten(
  { document: "usuarias/{uid}/meGusta/{itemId}", region: REGION },
  async (evento) => {
    const despues = evento.data?.after.data();
    const antes = evento.data?.before.data();
    const tipo = despues?.tipo ?? antes?.tipo;
    if (tipo !== "producto") return; // las prendas no tienen marca
    await actualizarRegistro(evento.params.uid, evento.params.itemId, { corazon: !!despues });
  },
);

/** registrarEvento({productoId, evento: "vista" | "pruebaAr"}) — una vez por usuaria. */
export const registrarEvento = onCall(
  { region: REGION, timeoutSeconds: 15 },
  async (request): Promise<{ contado: boolean }> => {
    const uid = exigirSesion(request.auth?.uid);
    const { productoId, evento } = leerEvento(request.data);
    const db = getFirestore();
    const producto = await db.collection("productosMaquillaje").doc(productoId).get();
    if (!producto.exists) return { contado: false };
    const estadRef = db.collection(COLECCION_ESTADISTICAS).doc(productoId);
    const marca = estadRef.collection("eventos").doc(`${evento}_${codigoAnonimo(uid)}`);
    return db.runTransaction(async (tx) => {
      if ((await tx.get(marca)).exists) return { contado: false };
      tx.create(marca, { creado: FieldValue.serverTimestamp() });
      tx.set(
        estadRef,
        {
          [CAMPO_EVENTO[evento]]: FieldValue.increment(1),
          marcaId: producto.get("marcaId") ?? null,
          actualizado: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return { contado: true };
    });
  },
);

function exigirAdmin(token: Record<string, unknown> | undefined) {
  if (token?.admin !== true) throw errorNegocio("solo-admin", "permission-denied");
}

/** asignarAdminMarca({correo, marcaId}) — marcaId null le quita el permiso. */
export const asignarAdminMarca = onCall(
  { region: REGION, timeoutSeconds: 30 },
  async (request): Promise<{ uid: string; correo: string; marcaId: string | null }> => {
    exigirSesion(request.auth?.uid);
    exigirAdmin(request.auth?.token);
    const { correo, marcaId } = leerAsignacion(request.data);
    if (correo === CORREO_ADMIN) throw errorNegocio("es-admin-general");

    const db = getFirestore();
    const auth = getAuth();
    let usuaria;
    try {
      usuaria = await auth.getUserByEmail(correo);
    } catch {
      throw errorNegocio("cuenta-no-existe");
    }
    if (marcaId) {
      const marca = await db.collection(COLECCION_MARCAS).doc(marcaId).get();
      if (!marca.exists) throw errorNegocio("marca-no-existe");
    }

    const anterior = usuaria.customClaims?.marcaId as string | undefined;
    const claims = { ...(usuaria.customClaims ?? {}) };
    if (marcaId) claims.marcaId = marcaId;
    else delete claims.marcaId;
    await auth.setCustomUserClaims(usuaria.uid, claims);

    const lote = db.batch();
    lote.set(
      db.collection("usuarias").doc(usuaria.uid),
      { rol: marcaId ? "marca" : "usuaria", marcaId: marcaId ?? FieldValue.delete() },
      { merge: true },
    );
    if (anterior && anterior !== marcaId) {
      lote.set(
        db.collection(COLECCION_MARCAS).doc(anterior),
        { admins: FieldValue.arrayRemove(correo) },
        { merge: true },
      );
    }
    if (marcaId) {
      lote.set(
        db.collection(COLECCION_MARCAS).doc(marcaId),
        { admins: FieldValue.arrayUnion(correo) },
        { merge: true },
      );
    }
    await lote.commit();
    logger.info("asignarAdminMarca", { uid: usuaria.uid, marcaId });
    return { uid: usuaria.uid, correo, marcaId };
  },
);

async function resumenDeMarca(marcaId: string, esAdminGeneral: boolean) {
  const db = getFirestore();
  const [marca, productos] = await Promise.all([
    db.collection(COLECCION_MARCAS).doc(marcaId).get(),
    db.collection("productosMaquillaje").where("marcaId", "==", marcaId).get(),
  ]);
  if (!marca.exists) throw errorNegocio("marca-no-existe");
  // Una marca desactivada por la admin deja de ver su panel.
  if (!esAdminGeneral && marca.get("activa") === false) throw errorNegocio("marca-inactiva", "permission-denied");
  const refs = productos.docs.map((p) => db.collection(COLECCION_ESTADISTICAS).doc(p.id));
  const estadisticas = refs.length ? await db.getAll(...refs) : [];
  const datos = estadisticas.map((e) => e.data());
  const filas = productos.docs.map((p, i) => filaProducto(p.id, p.data(), datos[i]));
  return {
    marca: {
      id: marca.id,
      nombre: String(marca.get("nombre") ?? ""),
      logoURL: String(marca.get("logoURL") ?? ""),
      colorHex: String(marca.get("colorHex") ?? ""),
    },
    ...resumir(filas, datos),
  };
}

/** resumenMarca({marcaId?}) — la admin de la marca (o la admin general). */
export const resumenMarca = onCall({ region: REGION, timeoutSeconds: 30 }, async (request) => {
  exigirSesion(request.auth?.uid);
  const token = request.auth?.token as Record<string, unknown> | undefined;
  const pedida = (request.data as { marcaId?: unknown } | undefined)?.marcaId;
  const marcaId = token?.admin === true && typeof pedida === "string" ? pedida : token?.marcaId;
  if (typeof marcaId !== "string" || !marcaId) throw errorNegocio("sin-marca", "permission-denied");
  return resumenDeMarca(marcaId, token?.admin === true);
});

/** resumenAdmin() — dashboard general (solo la admin). */
export const resumenAdmin = onCall({ region: REGION, timeoutSeconds: 60 }, async (request) => {
  exigirSesion(request.auth?.uid);
  exigirAdmin(request.auth?.token as Record<string, unknown> | undefined);
  const db = getFirestore();
  const contar = async (q: Query) => (await q.count().get()).data().count;
  const perfiles = db.collection("perfiles_colorimetria");

  const [usuarias, conAnalisis, productos, prendas, marcasSnap, ...porEstacionLista] =
    await Promise.all([
      contar(db.collection("usuarias")),
      contar(perfiles),
      contar(db.collection("productosMaquillaje")),
      contar(db.collection("prendasRopa")),
      db.collection(COLECCION_MARCAS).get(),
      ...ESTACIONES.map((e) => contar(perfiles.where("estacion", "==", e))),
    ]);
  const usuariasPorEstacion = porEstacionVacio();
  ESTACIONES.forEach((e, i) => (usuariasPorEstacion[e] = porEstacionLista[i]));

  // Top productos y ranking de marcas a partir de las estadísticas.
  // Sin orderBy: un orderBy("gusta") deja por fuera los documentos que
  // solo tienen vistas o pruebas en AR (aún sin "gusta").
  const estadisticas = await db.collection(COLECCION_ESTADISTICAS).limit(2000).get();
  const ordenadas = [...estadisticas.docs].sort(
    (a, b) => num(b.get("gusta")) - num(a.get("gusta")) || num(b.get("vistas")) - num(a.get("vistas")),
  );
  const idsTop = ordenadas.slice(0, 5).map((d) => d.id);
  const productosTop = idsTop.length
    ? await db.getAll(...idsTop.map((id) => db.collection("productosMaquillaje").doc(id)))
    : [];
  const topProductos = productosTop
    .filter((p) => p.exists)
    .map((p) => filaProducto(p.id, p.data() ?? {}, estadisticas.docs.find((d) => d.id === p.id)?.data()));

  const porMarca = new Map<string, { gusta: number; vistas: number; pruebasAr: number }>();
  for (const d of estadisticas.docs) {
    const m = d.get("marcaId");
    if (typeof m !== "string") continue;
    const acc = porMarca.get(m) ?? { gusta: 0, vistas: 0, pruebasAr: 0 };
    acc.gusta += num(d.get("gusta"));
    acc.vistas += num(d.get("vistas"));
    acc.pruebasAr += num(d.get("pruebasAr"));
    porMarca.set(m, acc);
  }
  const marcas = marcasSnap.docs
    .map((m) => ({
      id: m.id,
      nombre: String(m.get("nombre") ?? m.id),
      logoURL: String(m.get("logoURL") ?? ""),
      colorHex: String(m.get("colorHex") ?? ""),
      activa: m.get("activa") !== false,
      admins: Array.isArray(m.get("admins")) ? (m.get("admins") as string[]).length : 0,
      ...(porMarca.get(m.id) ?? { gusta: 0, vistas: 0, pruebasAr: 0 }),
    }))
    .sort((a, b) => b.gusta - a.gusta || a.nombre.localeCompare(b.nombre));

  return {
    totales: { usuarias, conAnalisis, productos, prendas, marcas: marcasSnap.size },
    usuariasPorEstacion,
    topProductos,
    marcas,
  };
});
