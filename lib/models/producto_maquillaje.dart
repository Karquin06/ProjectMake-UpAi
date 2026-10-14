import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';
import 'model_utils.dart';

/// Colección global: productosMaquillaje/{id}
///
/// `categoria` guarda el tipo de producto como clave de texto (ver
/// [categorias]). Los campos de catálogo (nombre, descripción, colorHex,
/// activo…) los usan el catálogo de administración, las recomendaciones y
/// el simulador AR.
class ProductoMaquillaje {
  static const collection = 'productosMaquillaje';

  /// Claves válidas de `categoria` (etiquetas en `EtiquetasTexto.categoria`).
  static const categorias = ['labial', 'rubor', 'sombra', 'base'];

  final String id;
  final String nombre;
  final String descripcion;
  final String marca;
  final String categoria;
  final String tono;

  /// Color del producto en HEX (`#C2185B`); lo usa el simulador AR.
  final String colorHex;
  final List<Subtono> subtonoCompatible;
  final String acabado;
  final String? codigoBarras;
  final List<EstacionColor> estacionesCompatibles;
  final double precio;
  final String imagenUrl;

  /// Ruta en Storage de la imagen (para borrarla al eliminar o reemplazar).
  final String? imagenRuta;

  /// Enlace opcional de compra o del fabricante.
  final String? enlace;

  /// Si es `false` no se muestra a las usuarias (solo en el catálogo admin).
  final bool activo;
  final DateTime? fechaActualizacion;

  const ProductoMaquillaje({
    required this.id,
    this.nombre = '',
    this.descripcion = '',
    required this.marca,
    required this.categoria,
    required this.tono,
    this.colorHex = '',
    this.subtonoCompatible = const [],
    required this.acabado,
    this.codigoBarras,
    this.estacionesCompatibles = const [],
    required this.precio,
    required this.imagenUrl,
    this.imagenRuta,
    this.enlace,
    this.activo = true,
    this.fechaActualizacion,
  });

  /// Nombre para mostrar: si no tiene, usa marca y tono.
  String get nombreVisible {
    if (nombre.trim().isNotEmpty) return nombre;
    return [marca, tono].where((t) => t.trim().isNotEmpty).join(' · ');
  }

  factory ProductoMaquillaje.fromMap(Map<String, dynamic> m,
          {required String id}) =>
      ProductoMaquillaje(
        id: id,
        nombre: m['nombre'] as String? ?? '',
        descripcion: m['descripcion'] as String? ?? '',
        marca: m['marca'] as String? ?? '',
        categoria: m['categoria'] as String? ?? '',
        tono: m['tono'] as String? ?? '',
        colorHex: m['colorHex'] as String? ?? '',
        subtonoCompatible:
            enumListFromNames(Subtono.values, m['subtonoCompatible']),
        acabado: m['acabado'] as String? ?? '',
        codigoBarras: m['codigoBarras'] as String?,
        estacionesCompatibles:
            enumListFromNames(EstacionColor.values, m['estacionesCompatibles']),
        precio: toDouble(m['precio']),
        imagenUrl: m['imagenURL'] as String? ?? '',
        imagenRuta: m['imagenRuta'] as String?,
        enlace: m['enlace'] as String?,
        activo: m['activo'] as bool? ?? true,
        fechaActualizacion: dateFromFirestore(m['fechaActualizacion']),
      );

  factory ProductoMaquillaje.fromFirestore(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      ProductoMaquillaje.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        // Para buscar por nombre sin importar mayúsculas.
        'nombreMinusculas': nombreVisible.trim().toLowerCase(),
        'descripcion': descripcion,
        'marca': marca,
        'categoria': categoria,
        'tono': tono,
        'colorHex': colorHex,
        'subtonoCompatible': subtonoCompatible.map((e) => e.name).toList(),
        'acabado': acabado,
        'codigoBarras': codigoBarras,
        'estacionesCompatibles':
            estacionesCompatibles.map((e) => e.name).toList(),
        'precio': precio,
        'imagenURL': imagenUrl,
        'imagenRuta': imagenRuta,
        'enlace': enlace,
        'activo': activo,
        'fechaActualizacion': dateToFirestore(fechaActualizacion),
      };

  ProductoMaquillaje copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    String? marca,
    String? categoria,
    String? tono,
    String? colorHex,
    List<Subtono>? subtonoCompatible,
    String? acabado,
    String? codigoBarras,
    List<EstacionColor>? estacionesCompatibles,
    double? precio,
    String? imagenUrl,
    String? imagenRuta,
    String? enlace,
    bool? activo,
    DateTime? fechaActualizacion,
  }) =>
      ProductoMaquillaje(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        descripcion: descripcion ?? this.descripcion,
        marca: marca ?? this.marca,
        categoria: categoria ?? this.categoria,
        tono: tono ?? this.tono,
        colorHex: colorHex ?? this.colorHex,
        subtonoCompatible: subtonoCompatible ?? this.subtonoCompatible,
        acabado: acabado ?? this.acabado,
        codigoBarras: codigoBarras ?? this.codigoBarras,
        estacionesCompatibles:
            estacionesCompatibles ?? this.estacionesCompatibles,
        precio: precio ?? this.precio,
        imagenUrl: imagenUrl ?? this.imagenUrl,
        imagenRuta: imagenRuta ?? this.imagenRuta,
        enlace: enlace ?? this.enlace,
        activo: activo ?? this.activo,
        fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      );
}
