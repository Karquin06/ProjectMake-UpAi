import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';
import 'model_utils.dart';

/// Colección global: prendasRopa/{id}
class PrendaRopa {
  static const collection = 'prendasRopa';

  final String id;
  final String marca;
  final String tipoPrenda;
  final String colorPrincipal;
  final String? colorSecundario;
  final String talla;
  final String material;
  final String estilo;
  final String formalidad;
  final List<EstacionColor> estacionesCompatibles;
  final double precio;
  final String imagenUrl;

  const PrendaRopa({
    required this.id,
    required this.marca,
    required this.tipoPrenda,
    required this.colorPrincipal,
    this.colorSecundario,
    required this.talla,
    required this.material,
    required this.estilo,
    required this.formalidad,
    this.estacionesCompatibles = const [],
    required this.precio,
    required this.imagenUrl,
  });

  factory PrendaRopa.fromMap(Map<String, dynamic> m, {required String id}) =>
      PrendaRopa(
        id: id,
        marca: m['marca'] as String? ?? '',
        tipoPrenda: m['tipoPrenda'] as String? ?? '',
        colorPrincipal: m['colorPrincipal'] as String? ?? '',
        colorSecundario: m['colorSecundario'] as String?,
        talla: m['talla'] as String? ?? '',
        material: m['material'] as String? ?? '',
        estilo: m['estilo'] as String? ?? '',
        formalidad: m['formalidad'] as String? ?? '',
        estacionesCompatibles:
            enumListFromNames(EstacionColor.values, m['estacionesCompatibles']),
        precio: toDouble(m['precio']),
        imagenUrl: m['imagenURL'] as String? ?? '',
      );

  factory PrendaRopa.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      PrendaRopa.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
        'marca': marca,
        'tipoPrenda': tipoPrenda,
        'colorPrincipal': colorPrincipal,
        'colorSecundario': colorSecundario,
        'talla': talla,
        'material': material,
        'estilo': estilo,
        'formalidad': formalidad,
        'estacionesCompatibles':
            estacionesCompatibles.map((e) => e.name).toList(),
        'precio': precio,
        'imagenURL': imagenUrl,
      };
}
