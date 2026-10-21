/**
 * Convierte los ítems de `datos/catalogo.ts` en documentos de Firestore con
 * EXACTAMENTE los campos que escriben los modelos de la app
 * (`PrendaRopa.toMap` / `ProductoMaquillaje.toMap`). Los opcionales vacíos
 * (colorSecundario, codigoBarras, enlace, imagenRuta) no se escriben.
 * La imagen es una foto real de Pexels (ver `urlFoto`).
 * `fechaActualizacion` la agrega el script.
 */
import { urlFoto, type PrendaSemilla, type ProductoSemilla } from "../datos/catalogo";

export function documentoPrenda(p: PrendaSemilla): Record<string, unknown> {
  return {
    nombre: p.nombre,
    nombreMinusculas: p.nombre.trim().toLowerCase(),
    descripcion: p.descripcion,
    marca: p.marca,
    tipoPrenda: p.tipoPrenda,
    colorPrincipal: p.colorPrincipal,
    colorHex: p.colorHex,
    talla: p.talla,
    material: p.material,
    estilo: p.estilo,
    formalidad: p.formalidad,
    ocasiones: p.ocasiones,
    estacionesCompatibles: p.estacionesCompatibles,
    subtonosCompatibles: p.subtonosCompatibles,
    precio: p.precio,
    imagenURL: urlFoto(p.foto),
    activo: true,
  };
}

export function documentoProducto(p: ProductoSemilla): Record<string, unknown> {
  return {
    nombre: p.nombre,
    nombreMinusculas: p.nombre.trim().toLowerCase(),
    descripcion: p.descripcion,
    marca: p.marca,
    categoria: p.categoria,
    tono: p.tono,
    colorHex: p.colorHex,
    subtonoCompatible: p.subtonoCompatible,
    acabado: p.acabado,
    estacionesCompatibles: p.estacionesCompatibles,
    precio: p.precio,
    imagenURL: urlFoto(p.foto),
    activo: true,
  };
}
