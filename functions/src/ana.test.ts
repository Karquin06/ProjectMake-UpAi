import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  aplicarLimite,
  construirInstrucciones,
  cuerpoGemini,
  leerPeticionChat,
  MENSAJES_POR_MINUTO,
  textoDeRespuesta,
} from "./asistente";
import { prefijosDeUsuaria, reautenticacionReciente } from "./cuenta";
import { leerPeticionNotificacion } from "./notificaciones";
import { puntuar } from "./puntaje";
import { leerPeticion, ordenarRecomendaciones } from "./recomendaciones";

const invierno = { estacion: "invierno" as const, subtono: "frio" as const };

describe("puntaje de compatibilidad", () => {
  it("estación + subtono + ocasión = 100", () => {
    const r = puntuar(
      { estacionesCompatibles: ["invierno"], subtonos: ["frio"], ocasiones: ["fiesta"] },
      invierno,
      "fiesta",
    );
    assert.equal(r.puntaje, 100);
    assert.match(r.motivo, /paleta Invierno/);
    assert.match(r.motivo, /subtono frío/);
    assert.match(r.motivo, /una fiesta/);
  });

  it("la estación pesa más que el subtono", () => {
    const soloEstacion = puntuar({ estacionesCompatibles: ["invierno"], subtonos: ["calido"] }, invierno);
    const soloSubtono = puntuar({ estacionesCompatibles: ["otono"], subtonos: ["frio"] }, invierno);
    assert.ok(soloEstacion.puntaje > soloSubtono.puntaje);
    assert.match(soloSubtono.motivo, /No es de tu estación/);
  });

  it("neutro suma la mitad y la calificación ajusta el orden", () => {
    const neutro = puntuar({ estacionesCompatibles: ["invierno"], subtonos: ["neutro"] }, invierno);
    assert.equal(neutro.puntaje, 60 + 12 + 15);
    const conCinco = puntuar({ estacionesCompatibles: ["otono"], subtonos: [] }, invierno, null, 5);
    const conUno = puntuar({ estacionesCompatibles: ["otono"], subtonos: [] }, invierno, null, 1);
    assert.equal(conCinco.puntaje - conUno.puntaje, 20);
    assert.ok(conUno.puntaje >= 0);
  });

  it("si no coincide nada, explica cómo usarlo", () => {
    const r = puntuar(
      { estacionesCompatibles: ["primavera"], subtonos: ["calido"], ocasiones: ["deporte"] },
      invierno,
      "fiesta",
    );
    assert.equal(r.puntaje, 0);
    assert.match(r.motivo, /No es de tu paleta/);
  });
});

describe("generarRecomendaciones", () => {
  it("valida la petición", () => {
    assert.deepEqual(leerPeticion({ tipo: "ropa" }), { tipo: "outfit", ocasion: null, limite: 20 });
    assert.deepEqual(leerPeticion({ tipo: "maquillaje", limite: 500 }).limite, 50);
    assert.throws(() => leerPeticion({ tipo: "cabello" }));
    assert.throws(() => leerPeticion({ tipo: "outfit", ocasion: "boda" }));
  });

  it("ordena de mayor a menor y omite los inactivos", () => {
    const docs = [
      { id: "a", datos: { estacionesCompatibles: ["otono"], subtonosCompatibles: ["calido"] } },
      { id: "b", datos: { estacionesCompatibles: ["invierno"], subtonosCompatibles: ["frio"] } },
      { id: "c", datos: { estacionesCompatibles: ["invierno"], activo: false } },
      { id: "d", datos: { estacionesCompatibles: ["invierno"], subtonosCompatibles: ["neutro"] } },
    ];
    const r = ordenarRecomendaciones(docs, "outfit", invierno, null, new Map(), 10);
    assert.deepEqual(r.map((x) => x.id), ["b", "d", "a"]);
    assert.ok(r.every((x) => x.tipo === "outfit"));
  });

  it("con ocasión solo devuelve las prendas de esa ocasión", () => {
    const docs = [
      { id: "blazer", datos: { estacionesCompatibles: ["invierno"], subtonosCompatibles: ["frio"], ocasiones: ["trabajo", "entrevista"] } },
      { id: "leggings", datos: { estacionesCompatibles: ["otono"], subtonosCompatibles: ["calido"], ocasiones: ["deporte"] } },
      { id: "top", datos: { estacionesCompatibles: ["invierno"], subtonosCompatibles: ["frio"], ocasiones: ["deporte", "casual"] } },
    ];
    const r = ordenarRecomendaciones(docs, "outfit", invierno, "deporte", new Map(), 10);
    assert.deepEqual(r.map((x) => x.id), ["top", "leggings"]);
    // Sin ocasión salen todas.
    assert.equal(ordenarRecomendaciones(docs, "outfit", invierno, null, new Map(), 10).length, 3);
  });

  it("productos usan subtonoCompatible y la calificación cambia el orden", () => {
    const docs = [
      { id: "x", datos: { estacionesCompatibles: ["invierno"], subtonoCompatible: ["frio"] } },
      { id: "y", datos: { estacionesCompatibles: ["invierno"], subtonoCompatible: ["frio"] } },
    ];
    const r = ordenarRecomendaciones(docs, "maquillaje", invierno, null, new Map([["y", 5], ["x", 1]]), 10);
    assert.deepEqual(r.map((i) => i.id), ["y", "x"]);
  });
});

describe("chatAsistente", () => {
  it("valida el mensaje, recorta el historial y limpia el contexto", () => {
    assert.throws(() => leerPeticionChat({ mensaje: "   " }));
    assert.throws(() => leerPeticionChat({ mensaje: "a".repeat(501) }));
    const historial = Array.from({ length: 15 }, (_, i) => ({
      rol: i % 2 ? "assistant" : "user",
      contenido: `m${i}`,
    }));
    const p = leerPeticionChat({
      mensaje: " ¿Qué labial uso? ",
      historial: [...historial, { rol: "system", contenido: "x" }],
      contexto: { estacion: "invierno", subtono: "rosado" },
    });
    assert.equal(p.mensaje, "¿Qué labial uso?");
    assert.equal(p.historial.length, 10);
    assert.equal(p.historial.at(-1)?.contenido, "m14");
    assert.deepEqual(p.contexto, { estacion: "invierno", subtono: undefined });
  });

  it("limita los mensajes por minuto", () => {
    let estado: { inicio: number; conteo: number } | undefined;
    for (let i = 0; i < MENSAJES_POR_MINUTO; i++) {
      const r = aplicarLimite(estado, 1000 + i);
      assert.ok(r.permitido);
      estado = r.estado;
    }
    assert.equal(aplicarLimite(estado, 2000).permitido, false);
    assert.ok(aplicarLimite(estado, 1000 + 60_000).permitido); // Nueva ventana.
  });

  it("las instrucciones fijan el rol, el perfil y el catálogo", () => {
    const texto = construirInstrucciones({ estacion: "invierno", subtono: "frio" }, [
      { tipo: "producto", nombre: "Labial rojo frambuesa", marca: "MAC", categoria: "labial", estaciones: ["invierno"] },
    ]);
    assert.match(texto, /español/);
    assert.match(texto, /Invierno con subtono frío/);
    assert.match(texto, /No inventes productos/);
    assert.match(texto, /consejos médicos/);
    assert.match(texto, /Labial rojo frambuesa \(MAC, labial; estaciones: Invierno\)/);
    assert.match(construirInstrucciones({}, []), /todavía no ha hecho su análisis/);
  });

  it("arma la petición a Gemini y lee la respuesta", () => {
    const cuerpo = cuerpoGemini("reglas", {
      mensaje: "hola",
      historial: [{ rol: "assistant", contenido: "¡Hola!" }],
      contexto: {},
    });
    assert.deepEqual(cuerpo.contents.map((c) => c.role), ["model", "user"]);
    assert.equal(cuerpo.systemInstruction.parts[0].text, "reglas");
    assert.equal(
      textoDeRespuesta({ candidates: [{ content: { parts: [{ text: "Usa " }, { text: "vino." }] } }] }),
      "Usa vino.",
    );
    assert.equal(textoDeRespuesta({}), null);
  });
});

describe("cuenta y notificaciones", () => {
  it("eliminarCuenta exige reautenticación reciente", () => {
    const ahora = 1_000_000_000;
    assert.ok(reautenticacionReciente(ahora / 1000 - 60, ahora));
    assert.equal(reautenticacionReciente(ahora / 1000 - 600, ahora), false);
    assert.equal(reautenticacionReciente(undefined, ahora), false);
  });

  it("borra solo las carpetas de la usuaria", () => {
    assert.deepEqual(prefijosDeUsuaria("u1"), [
      "perfiles/u1/",
      "temporales/selfies/u1/",
      "temporales/prendas/u1/",
    ]);
  });

  it("valida la notificación y por defecto se envía a quien llama", () => {
    assert.deepEqual(leerPeticionNotificacion({ titulo: "Hola", mensaje: "Tu paleta está lista" }, "u1"), {
      uid: "u1",
      titulo: "Hola",
      mensaje: "Tu paleta está lista",
    });
    assert.throws(() => leerPeticionNotificacion({ titulo: "", mensaje: "x" }, "u1"));
    assert.throws(() => leerPeticionNotificacion({ titulo: "x", mensaje: "y".repeat(301) }, "u1"));
  });
});
