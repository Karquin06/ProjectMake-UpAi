import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ErrorAnalisis, OVALO, analizarPixeles } from "./analisis_color";
import { rutaSelfieValida } from "./colorimetria";

type Rgb = [number, number, number];

/** Imagen RGB: [piel] dentro del óvalo guía y [fondo] fuera (cabello). */
function imagen(piel: Rgb, fondo: Rgb, ancho = 120, alto = 160) {
  const datos = new Uint8Array(ancho * alto * 3);
  for (let y = 0; y < alto; y++) {
    for (let x = 0; x < ancho; x++) {
      const dx = (x / ancho - OVALO.cx) / OVALO.rx;
      const dy = (y / alto - OVALO.cy) / OVALO.ry;
      const color = dx * dx + dy * dy <= 1 ? piel : fondo;
      datos.set(color, (y * ancho + x) * 3);
    }
  }
  return { datos, ancho, alto };
}

function analizar(piel: Rgb, fondo: Rgb) {
  const { datos, ancho, alto } = imagen(piel, fondo);
  return analizarPixeles(datos, ancho, alto, 3);
}

function codigoDe(fn: () => unknown) {
  try {
    fn();
  } catch (e) {
    return e instanceof ErrorAnalisis ? e.codigo : String(e);
  }
  return null;
}

describe("analizarPixeles", () => {
  it("piel clara rosada con cabello negro → invierno frío, contraste alto", () => {
    const r = analizar([235, 200, 195], [20, 20, 20]);
    assert.equal(r.subtono, "frio");
    assert.equal(r.contraste, "alto");
    assert.equal(r.estacion, "invierno");
    assert.ok(r.confianza >= 0.35 && r.confianza <= 0.95);
  });

  it("piel dorada clara con cabello castaño claro → primavera cálida", () => {
    const r = analizar([225, 180, 140], [150, 110, 80]);
    assert.equal(r.subtono, "calido");
    assert.equal(r.estacion, "primavera");
  });

  it("imagen oscura → imagen-oscura", () => {
    assert.equal(codigoDe(() => analizar([40, 30, 28], [5, 5, 5])), "imagen-oscura");
  });

  it("sin piel en el óvalo → rostro-no-detectado", () => {
    assert.equal(
      codigoDe(() => analizar([60, 160, 220], [200, 200, 200])),
      "rostro-no-detectado",
    );
  });
});

describe("rutaSelfieValida", () => {
  it("acepta solo selfies de la propia usuaria", () => {
    assert.ok(rutaSelfieValida("temporales/selfies/u1/123.jpg", "u1"));
    assert.ok(!rutaSelfieValida("temporales/selfies/u2/123.jpg", "u1"));
    assert.ok(!rutaSelfieValida("temporales/selfies/u1/../u2/1.jpg", "u1"));
    assert.ok(!rutaSelfieValida("temporales/prendas/u1/1.jpg", "u1"));
    assert.ok(!rutaSelfieValida(42, "u1"));
  });
});
