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

/** Nombre fijo de la foto de ejemplo en Storage (igual que en la app). */
export const NOMBRE_FOTO_EJEMPLO = "ejemplo.jpg";

/** `catalogo/{prendas|productos}/{id}/ejemplo.jpg` */
export function rutaFotoEjemplo(carpeta: "prendas" | "productos", id: string): string {
  return `catalogo/${carpeta}/${id}/${NOMBRE_FOTO_EJEMPLO}`;
}

/**
 * `true` si el documento actual tiene una foto que la admin subió con
 * "Editar" (está en Storage y no es la foto de ejemplo): no se reemplaza.
 */
export function conservarFotoPropia(actual: Record<string, unknown> | undefined): boolean {
  const url = actual?.imagenURL;
  const ruta = actual?.imagenRuta;
  return (
    typeof url === "string" &&
    url.length > 0 &&
    typeof ruta === "string" &&
    ruta.length > 0 &&
    !ruta.endsWith(`/${NOMBRE_FOTO_EJEMPLO}`)
  );
}
