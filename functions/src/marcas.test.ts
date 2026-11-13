import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  codigoAnonimo,
  deltaEstadisticas,
  expandir,
  filaProducto,
  leGusta,
  leerAsignacion,
  leerEvento,
  leerRegistro,
  REGISTRO_VACIO,
  resumir,
  sigueSiendoAdminDeMarca,
  type RegistroUsuaria,
} from "./marcas";

const reg = (r: Partial<RegistroUsuaria>): RegistroUsuaria => ({ ...REGISTRO_VACIO, ...r });

describe("marcas: le gustó", () => {
  it("cuenta ❤️ o 4-5 estrellas, no 3", () => {
    assert.equal(leGusta(reg({ corazon: true })), true);
    assert.equal(leGusta(reg({ estrellas: 4 })), true);
    assert.equal(leGusta(reg({ estrellas: 3 })), false);
    assert.equal(leGusta(REGISTRO_VACIO), false);
  });

  it("calificar con 5 suma gusta, calificación y su estación", () => {
    const d = deltaEstadisticas(REGISTRO_VACIO, reg({ estrellas: 5, estacion: "otono" }));
    assert.deepEqual(d, {
      gusta: 1,
      calificaciones: 1,
      sumaEstrellas: 5,
      "porEstacion.otono": 1,
    });
  });

  it("❤️ + 5 estrellas cuenta una sola vez en gusta", () => {
    const conCorazon = reg({ corazon: true, estacion: "verano" });
    const d = deltaEstadisticas(conCorazon, { ...conCorazon, estrellas: 5 });
    assert.equal(d.gusta, undefined);
    assert.equal(d["porEstacion.verano"], undefined);
    assert.equal(d.calificaciones, 1);
  });

  it("bajar de 5 a 2 estrellas resta gusta; borrar todo deja en cero", () => {
    const antes = reg({ estrellas: 5, estacion: "invierno" });
    const d = deltaEstadisticas(antes, { ...antes, estrellas: 2 });
    assert.deepEqual(d, { gusta: -1, sumaEstrellas: -3, "porEstacion.invierno": -1 });
    const borrar = deltaEstadisticas(antes, { ...antes, estrellas: null });
    assert.deepEqual(borrar, {
      gusta: -1,
      calificaciones: -1,
      sumaEstrellas: -5,
      "porEstacion.invierno": -1,
    });
  });

  it("si cambió de estación, resta de la vieja y suma a la nueva", () => {
    const d = deltaEstadisticas(
      reg({ corazon: true, estacion: "primavera" }),
      reg({ corazon: true, estacion: "otono" }),
    );
    assert.deepEqual(d, { "porEstacion.primavera": -1, "porEstacion.otono": 1 });
  });

  it("leerRegistro ignora valores raros", () => {
    assert.deepEqual(leerRegistro({ estrellas: 9, corazon: "si", estacion: "x" }), REGISTRO_VACIO);
  });

  it("expandir arma el mapa porEstacion", () => {
    assert.deepEqual(expandir({ gusta: 1, "porEstacion.otono": 2 }), {
      gusta: 1,
      porEstacion: { otono: 2 },
    });
  });
});

describe("marcas: privacidad", () => {
  it("el código anónimo no contiene el uid y siempre es el mismo", () => {
    const c = codigoAnonimo("abc123");
    assert.equal(c, codigoAnonimo("abc123"));
    assert.notEqual(c, codigoAnonimo("abc124"));
    assert.ok(!c.includes("abc123"));
    assert.equal(c.length, 32);
  });
});

describe("marcas: peticiones", () => {
  it("leerEvento valida producto y tipo", () => {
    assert.deepEqual(leerEvento({ productoId: "p1", evento: "vista" }), {
      productoId: "p1",
      evento: "vista",
    });
    assert.throws(() => leerEvento({ productoId: "a/b", evento: "vista" }));
    assert.throws(() => leerEvento({ productoId: "p1", evento: "compra" }));
  });

  it("leerAsignacion normaliza el correo y acepta quitar (null)", () => {
    assert.deepEqual(leerAsignacion({ correo: " Ana@Marca.com ", marcaId: "loreal" }), {
      correo: "ana@marca.com",
      marcaId: "loreal",
    });
    assert.equal(leerAsignacion({ correo: "a@b.co", marcaId: null }).marcaId, null);
    assert.throws(() => leerAsignacion({ correo: "no-es-correo", marcaId: "x" }));
    assert.throws(() => leerAsignacion({ correo: "a@b.co", marcaId: "a/b" }));
  });
});

describe("marcas: resumen del dashboard", () => {
  it("promedios, totales y orden por gusta", () => {
    const e1 = { gusta: 3, corazones: 2, calificaciones: 2, sumaEstrellas: 9, vistas: 10, pruebasAr: 4, porEstacion: { otono: 2, verano: 1 } };
    const e2 = { gusta: 5, calificaciones: 1, sumaEstrellas: 4, vistas: 3, porEstacion: { otono: 5 } };
    const filas = [
      filaProducto("a", { nombre: "Labial A", categoria: "labial" }, e1),
      filaProducto("b", { nombre: "Rubor B", categoria: "rubor", activo: false }, e2),
      filaProducto("c", { nombre: "Sombra C" }, undefined),
    ];
    assert.equal(filas[0].promedio, 4.5);
    assert.equal(filas[1].activo, false);
    assert.equal(filas[2].gusta, 0);
    const r = resumir(filas, [e1, e2, undefined]);
    assert.deepEqual(r.productos.map((p) => p.id), ["b", "a", "c"]);
    assert.equal(r.totales.gusta, 8);
    assert.equal(r.totales.vistas, 13);
    assert.equal(r.totales.promedio, 4.3);
    assert.deepEqual(r.totales.porEstacion, { primavera: 0, verano: 1, otono: 7, invierno: 0 });
  });
});

describe("marcas: admin vigente (H-03)", () => {
  it("solo si el correo sigue en admins", () => {
    assert.equal(sigueSiendoAdminDeMarca(["ana@marca.co"], "ana@marca.co"), true);
    assert.equal(sigueSiendoAdminDeMarca(["ana@marca.co"], "Ana@Marca.co"), true);
    assert.equal(sigueSiendoAdminDeMarca(["otra@marca.co"], "ana@marca.co"), false);
    assert.equal(sigueSiendoAdminDeMarca([], "ana@marca.co"), false);
    assert.equal(sigueSiendoAdminDeMarca(undefined, "ana@marca.co"), false);
    assert.equal(sigueSiendoAdminDeMarca(["ana@marca.co"], undefined), false);
  });
});
