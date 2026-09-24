import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_utils.dart';

/// Colección global: planes/{id}  (id = gratis | premium | pro)
class Plan {
  static const collection = 'planes';

  final String id;
  final String nombre;
  final double precioMensual;
  final double precioAnual;
  final List<String> features;

  /// Límites de uso, p. ej. {'analisisMes': 1, 'recomendacionesMes': 3,
  /// 'consultasIaMes': 0}. Usa -1 para "ilimitado".
  final Map<String, dynamic> limites;

  const Plan({
    required this.id,
    required this.nombre,
    required this.precioMensual,
    required this.precioAnual,
    this.features = const [],
    this.limites = const {},
  });

  factory Plan.fromMap(Map<String, dynamic> m, {required String id}) => Plan(
        id: id,
        nombre: m['nombre'] as String? ?? '',
        precioMensual: toDouble(m['precioMensual']),
        precioAnual: toDouble(m['precioAnual']),
        features: stringList(m['features']),
        limites: Map<String, dynamic>.from(m['limites'] as Map? ?? {}),
      );

  factory Plan.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Plan.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'precioMensual': precioMensual,
        'precioAnual': precioAnual,
        'features': features,
        'limites': limites,
      };
}
