import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';
import 'model_utils.dart';

/// Colección global: prendasRopa/{id}
///
/// `tipoPrenda` guarda la categoría como clave de texto (ver [categorias]).
/// Los campos de catálogo (nombre, descripción, ocasiones, colorHex, activo…)
/// los usa el catálogo de administración y las recomendaciones.
class PrendaRopa {
  static const collection = 'prendasRopa';

  /// Claves válidas de `tipoPrenda` (etiquetas en `EtiquetasTexto.categoria`).
  static const categorias = [
    'superior',
    'inferior',
    'vestido',
    'abrigo',
    'accesorio',
  ];

  final String id;
  final String nombre;
  final String descripcion;
  final String marca;
  final String tipoPrenda;
  final String colorPrincipal;
  final String? colorSecundario;

  /// Color de la prenda en HEX (`#E75480`), base para la compatibilidad.
  final String colorHex;
  final String talla;
  final String material;
  final String estilo;
  final String formalidad;

  /// Claves de ocasión (`trabajo`, `fiesta`, `casual`, `entrevista`…).
  final List<String> ocasiones;
  final List<EstacionColor> estacionesCompatibles;
  final List<Subtono> subtonosCompatibles;
  final double precio;
  final String imagenUrl;

  /// Ruta en Storage de la imagen (para borrarla al eliminar o reemplazar).
  final String? imagenRuta;

  /// Si es `false` no se muestra a las usuarias (solo en el catálogo admin).
  final bool activo;
  final DateTime? fechaActualizacion;

  const PrendaRopa({
    required this.id,
    this.nombre = '',
    this.descripcion = '',
    required this.marca,
    required this.tipoPrenda,
    required this.colorPrincipal,
    this.colorSecundario,
    this.colorHex = '',
    required this.talla,
    required this.material,
    required this.estilo,
    required this.formalidad,
    this.ocasiones = const [],
    this.estacionesCompatibles = const [],
    this.subtonosCompatibles = const [],
    required this.precio,
    required this.imagenUrl,
    this.imagenRuta,
    this.activo = true,
    this.fechaActualizacion,
  });

  /// Nombre para mostrar: si no tiene, usa la marca.
  String get nombreVisible => nombre.trim().isNotEmpty ? nombre : marca;

  factory PrendaRopa.fromMap(Map<String, dynamic> m, {required String id}) =>
      PrendaRopa(
        id: id,
        nombre: m['nombre'] as String? ?? '',
        descripcion: m['descripcion'] as String? ?? '',
        marca: m['marca'] as String? ?? '',
        tipoPrenda: m['tipoPrenda'] as String? ?? '',
        colorPrincipal: m['colorPrincipal'] as String? ?? '',
        colorSecundario: m['colorSecundario'] as String?,
        colorHex: m['colorHex'] as String? ?? '',
        talla: m['talla'] as String? ?? '',
        material: m['material'] as String? ?? '',
        estilo: m['estilo'] as String? ?? '',
        formalidad: m['formalidad'] as String? ?? '',
        ocasiones: stringList(m['ocasiones']),
        estacionesCompatibles:
            enumListFromNames(EstacionColor.values, m['estacionesCompatibles']),
        subtonosCompatibles:
            enumListFromNames(Subtono.values, m['subtonosCompatibles']),
        precio: toDouble(m['precio']),
        imagenUrl: m['imagenURL'] as String? ?? '',
        imagenRuta: m['imagenRuta'] as String?,
        activo: m['activo'] as bool? ?? true,
        fechaActualizacion: dateFromFirestore(m['fechaActualizacion']),
      );

  factory PrendaRopa.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      PrendaRopa.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        // Para buscar por nombre sin importar mayúsculas.
        'nombreMinusculas': nombreVisible.trim().toLowerCase(),
        'descripcion': descripcion,
        'marca': marca,
        'tipoPrenda': tipoPrenda,
        'colorPrincipal': colorPrincipal,
        'colorSecundario': colorSecundario,
        'colorHex': colorHex,
        'talla': talla,
        'material': material,
        'estilo': estilo,
        'formalidad': formalidad,
        'ocasiones': ocasiones,
        'estacionesCompatibles':
            estacionesCompatibles.map((e) => e.name).toList(),
        'subtonosCompatibles': subtonosCompatibles.map((e) => e.name).toList(),
        'precio': precio,
        'imagenURL': imagenUrl,
        'imagenRuta': imagenRuta,
        'activo': activo,
        'fechaActualizacion': dateToFirestore(fechaActualizacion),
      };

  PrendaRopa copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    String? marca,
    String? tipoPrenda,
    String? colorPrincipal,
    String? colorSecundario,
    String? colorHex,
    String? talla,
    String? material,
    String? estilo,
    String? formalidad,
    List<String>? ocasiones,
    List<EstacionColor>? estacionesCompatibles,
    List<Subtono>? subtonosCompatibles,
    double? precio,
    String? imagenUrl,
    String? imagenRuta,
    bool? activo,
    DateTime? fechaActualizacion,
  }) =>
      PrendaRopa(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        descripcion: descripcion ?? this.descripcion,
        marca: marca ?? this.marca,
        tipoPrenda: tipoPrenda ?? this.tipoPrenda,
        colorPrincipal: colorPrincipal ?? this.colorPrincipal,
        colorSecundario: colorSecundario ?? this.colorSecundario,
        colorHex: colorHex ?? this.colorHex,
        talla: talla ?? this.talla,
        material: material ?? this.material,
        estilo: estilo ?? this.estilo,
        formalidad: formalidad ?? this.formalidad,
        ocasiones: ocasiones ?? this.ocasiones,
        estacionesCompatibles:
            estacionesCompatibles ?? this.estacionesCompatibles,
        subtonosCompatibles: subtonosCompatibles ?? this.subtonosCompatibles,
        precio: precio ?? this.precio,
        imagenUrl: imagenUrl ?? this.imagenUrl,
        imagenRuta: imagenRuta ?? this.imagenRuta,
        activo: activo ?? this.activo,
        fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      );
}
