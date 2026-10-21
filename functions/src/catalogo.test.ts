import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  CATEGORIAS_PRENDA,
  CATEGORIAS_PRODUCTO,
  OCASIONES,
  PRENDAS,
  PRODUCTOS,
} from "./datos/catalogo";
import { PALETAS } from "./datos/paletas";
import { documentoPrenda, documentoProducto } from "./scripts/documentos_catalogo";

const HEX = /^#[0-9A-F]{6}$/;
const ESTACIONES = ["primavera", "verano", "otono", "invierno"];
const CALIDAS = ["primavera", "otono"];

describe("catálogo de prueba", () => {
  const todos = [...PRENDAS, ...PRODUCTOS];

  it("tiene suficientes ítems y de todas las estaciones", () => {
    assert.ok(PRENDAS.length >= 10);
    assert.ok(PRODUCTOS.length >= 10);
    for (const e of ESTACIONES) {
      assert.ok(PRENDAS.some((p) => p.estacionesCompatibles.includes(e as never)), `prendas de ${e}`);
      assert.ok(PRODUCTOS.some((p) => p.estacionesCompatibles.includes(e as never)), `productos de ${e}`);
    }
    for (const c of CATEGORIAS_PRENDA) {
      assert.ok(PRENDAS.some((p) => p.tipoPrenda === c), `prenda ${c}`);
    }
    for (const c of CATEGORIAS_PRODUCTO) {
      assert.ok(PRODUCTOS.some((p) => p.categoria === c), `producto ${c}`);
    }
  });

  it("ids únicos y datos válidos", () => {
    assert.equal(new Set(todos.map((i) => i.id)).size, todos.length);
    // Cada ítem tiene su propia foto real.
    assert.equal(new Set(todos.map((i) => i.foto)).size, todos.length);
    for (const i of todos) {
      assert.match(i.colorHex, HEX, i.id);
      assert.ok(i.nombre.trim().length > 0, i.id);
      assert.ok(i.marca.trim().length > 0, i.id);
      assert.ok(i.precio > 0, i.id);
      assert.ok(i.estacionesCompatibles.length > 0, i.id);
      for (const e of i.estacionesCompatibles) assert.ok(ESTACIONES.includes(e), i.id);
    }
    for (const p of PRENDAS) {
      assert.ok(CATEGORIAS_PRENDA.includes(p.tipoPrenda), p.id);
      assert.ok(p.ocasiones.length > 0, p.id);
      for (const o of p.ocasiones) assert.ok(OCASIONES.includes(o), p.id);
      assert.ok(p.subtonosCompatibles.length > 0, p.id);
    }
    for (const p of PRODUCTOS) {
      assert.ok(CATEGORIAS_PRODUCTO.includes(p.categoria), p.id);
      assert.ok(p.subtonoCompatible.length > 0, p.id);
    }
  });

  it("los colores de las prendas están en la paleta de su estación", () => {
    for (const p of PRENDAS) {
      for (const e of p.estacionesCompatibles) {
        const recomendados = PALETAS[e].coloresRecomendados.map((c) => c.hex);
        assert.ok(recomendados.includes(p.colorHex), `${p.id} no está en ${e}`);
      }
    }
  });

  it("ningún ítem usa un color a evitar de su estación", () => {
    for (const i of todos) {
      for (const e of i.estacionesCompatibles) {
        const evitar = PALETAS[e].coloresEvitar.map((c) => c.hex);
        assert.ok(!evitar.includes(i.colorHex), `${i.id} es a evitar en ${e}`);
      }
    }
  });

  it("subtonos coherentes: estaciones cálidas → cálido, frías → frío", () => {
    for (const i of todos) {
      const subtonos =
        "subtonosCompatibles" in i ? i.subtonosCompatibles : i.subtonoCompatible;
      if (i.estacionesCompatibles.length === ESTACIONES.length) continue; // bases neutras
      const calida = i.estacionesCompatibles.every((e) => CALIDAS.includes(e));
      assert.ok(
        subtonos.includes(calida ? "calido" : "frio"),
        `${i.id}: subtonos ${subtonos.join(",")}`,
      );
    }
  });

  it("los documentos tienen los campos de los modelos y ningún null", () => {
    const camposPrenda = [
      "nombre", "nombreMinusculas", "descripcion", "marca", "tipoPrenda",
      "colorPrincipal", "colorHex", "talla", "material", "estilo", "formalidad",
      "ocasiones", "estacionesCompatibles", "subtonosCompatibles", "precio",
      "imagenURL", "activo",
    ];
    const camposProducto = [
      "nombre", "nombreMinusculas", "descripcion", "marca", "categoria", "tono",
      "colorHex", "subtonoCompatible", "acabado", "estacionesCompatibles",
      "precio", "imagenURL", "activo",
    ];
    for (const p of PRENDAS) {
      const doc = documentoPrenda(p);
      assert.deepEqual(Object.keys(doc).sort(), [...camposPrenda].sort(), p.id);
      assert.ok(Object.values(doc).every((v) => v !== null && v !== undefined));
      assert.equal(typeof doc.precio, "number");
      assert.match(String(doc.imagenURL), /^https:\/\/images\.pexels\.com\/photos\/\d+\//);
    }
    for (const p of PRODUCTOS) {
      const doc = documentoProducto(p);
      assert.deepEqual(Object.keys(doc).sort(), [...camposProducto].sort(), p.id);
      assert.ok(Object.values(doc).every((v) => v !== null && v !== undefined));
      assert.ok(Array.isArray(doc.subtonoCompatible));
    }
  });
});
