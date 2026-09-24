import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';
import 'model_utils.dart';

/// Colección global: productosMaquillaje/{id}
class ProductoMaquillaje {
  static const collection = 'productosMaquillaje';

  final String id;
  final String marca;
  final String categoria;
  final String tono;
  final List<Subtono> subtonoCompatible;
  final String acabado;
  final String? codigoBarras;
  final List<EstacionColor> estacionesCompatibles;
  final double precio;
  final String imagenUrl;

  const ProductoMaquillaje({
    required this.id,
    required this.marca,
    required this.categoria,
    required this.tono,
    this.subtonoCompatible = const [],
    required this.acabado,
    this.codigoBarras,
    this.estacionesCompatibles = const [],
    required this.precio,
    required this.imagenUrl,
  });

  factory ProductoMaquillaje.fromMap(Map<String, dynamic> m,
          {required String id}) =>
      ProductoMaquillaje(
        id: id,
        marca: m['marca'] as String? ?? '',
        categoria: m['categoria'] as String? ?? '',
        tono: m['tono'] as String? ?? '',
        subtonoCompatible:
            enumListFromNames(Subtono.values, m['subtonoCompatible']),
        acabado: m['acabado'] as String? ?? '',
        codigoBarras: m['codigoBarras'] as String?,
        estacionesCompatibles:
            enumListFromNames(EstacionColor.values, m['estacionesCompatibles']),
        precio: toDouble(m['precio']),
        imagenUrl: m['imagenURL'] as String? ?? '',
      );

  factory ProductoMaquillaje.fromFirestore(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      ProductoMaquillaje.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
        'marca': marca,
        'categoria': categoria,
        'tono': tono,
        'subtonoCompatible': subtonoCompatible.map((e) => e.name).toList(),
        'acabado': acabado,
        'codigoBarras': codigoBarras,
        'estacionesCompatibles':
            estacionesCompatibles.map((e) => e.name).toList(),
        'precio': precio,
        'imagenURL': imagenUrl,
      };
}
