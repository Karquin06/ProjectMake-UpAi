import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { colorDominante, evaluarPrenda, hexDe, nombreDeColor, rgbDeHex } from "./analisis_prenda";
import { esEstacion } from "./colorimetria";
import { VIDA_TEMPORAL_MS, rutaTemporalValida, temporalVencido } from "./comun";
import { PALETAS } from "./datos/paletas";

type Rgb = [number, number, number];

/** Fondo [fondo] con un rectángulo central de [prenda] (60 % × 60 %). */
function foto(prenda: Rgb, fondo: Rgb, ancho = 100, alto = 100) {
  const datos = new Uint8Array(ancho * alto * 3);
  for (let y = 0; y < alto; y++) {
    for (let x = 0; x < ancho; x++) {
      const centro = x >= 20 && x < 80 && y >= 20 && y < 80;
      datos.set(centro ? prenda : fondo, (y * ancho + x) * 3);
    }
  }
  return datos;
}

describe("analizarPrenda (lógica)", () => {
  it("el color dominante es el de la prenda, no el fondo", () => {
    const color = colorDominante(foto([15, 76, 129], [240, 240, 240]), 100, 100, 3);
    assert.equal(hexDe(color), "#0F4C81");
    assert.equal(nombreDeColor(color), "Azul clásico");
  });

  it("azul clásico coincide con la paleta de invierno", () => {
    const r = evaluarPrenda(rgbDeHex("#0F4C81"), PALETAS.invierno);
    assert.equal(r.coincideConPaleta, true);
    assert.ok(r.compatibilidad >= 90, `compatibilidad ${r.compatibilidad}`);
    assert.match(r.motivo, /Invierno/);
  });

  it("mostaza no coincide con invierno y tiene baja compatibilidad", () => {
    const r = evaluarPrenda(rgbDeHex("#D4A017"), PALETAS.invierno);
    assert.equal(r.coincideConPaleta, false);
    assert.ok(r.compatibilidad <= 45, `compatibilidad ${r.compatibilidad}`);
    assert.match(r.motivo, /evitar/);
  });

  it("la compatibilidad siempre está entre 0 y 100", () => {
    for (const paleta of Object.values(PALETAS)) {
      for (const hex of ["#000000", "#FFFFFF", "#FF00FF", "#00FF00"]) {
        const { compatibilidad } = evaluarPrenda(rgbDeHex(hex), paleta);
        assert.ok(compatibilidad >= 0 && compatibilidad <= 100);
        assert.ok(Number.isInteger(compatibilidad));
      }
    }
  });
});

describe("paletas", () => {
  it("las cuatro estaciones tienen colores válidos", () => {
    for (const [estacion, paleta] of Object.entries(PALETAS)) {
      assert.equal(paleta.estacion, estacion);
      assert.ok(paleta.coloresRecomendados.length >= 8);
      assert.ok(paleta.coloresEvitar.length >= 4);
      for (const c of [...paleta.coloresRecomendados, ...paleta.coloresEvitar]) {
        assert.match(c.hex, /^#[0-9A-F]{6}$/);
        assert.ok(c.nombre.length > 0);
      }
    }
  });

  it("esEstacion valida la entrada de generarPaleta", () => {
    assert.ok(esEstacion("otono"));
    assert.ok(!esEstacion("otoño"));
    assert.ok(!esEstacion("toString"));
    assert.ok(!esEstacion(3));
  });
});

describe("temporales", () => {
  it("rutas de prendas solo de la propia usuaria", () => {
    assert.ok(rutaTemporalValida("temporales/prendas/u1/a.jpg", "u1", "prendas"));
    assert.ok(!rutaTemporalValida("temporales/selfies/u1/a.jpg", "u1", "prendas"));
  });

  it("vence después de una hora", () => {
    const ahora = Date.now();
    assert.ok(temporalVencido(new Date(ahora - VIDA_TEMPORAL_MS - 1000), ahora));
    assert.ok(!temporalVencido(new Date(ahora - 1000), ahora));
    assert.ok(!temporalVencido(undefined, ahora));
  });
});
