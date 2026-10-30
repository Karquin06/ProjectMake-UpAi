import 'enums.dart';
import 'prenda_ropa.dart';
import 'producto_maquillaje.dart';

/// Regla de color que une las piezas de un look.
enum ArmoniaLook {
  /// Varios tonos de un mismo color (camel, caqui, chocolate).
  monocromatico,

  /// Colores vecinos en el círculo cromático (coral, durazno, dorado).
  analogo,

  /// Básicos neutros con un solo color protagonista.
  neutroAcento,

  /// Colores opuestos, suavizados por la paleta (verde musgo y teja).
  complementario,

  /// Solo básicos: beige, gris, marino, marfil.
  neutros,
}

/// Look completo (ropa + maquillaje) que combina entre sí y con la
/// estación de la usuaria. Lo arma `MotorLooks`; no se guarda en Firestore.
class LookColorimetria {
  LookColorimetria({
    required this.id,
    required this.nombre,
    required this.armonia,
    required this.estacion,
    required this.ocasion,
    required List<PrendaRopa> prendas,
    required List<ProductoMaquillaje> maquillaje,
    required this.puntaje,
  }) : prendas = List.unmodifiable(prendas),
       maquillaje = List.unmodifiable(maquillaje);

  final String id;
  final String nombre;
  final ArmoniaLook armonia;
  final EstacionColor estacion;

  /// Ocasión que comparten las prendas, o `null` si es para varias.
  final String? ocasion;
  final List<PrendaRopa> prendas;
  final List<ProductoMaquillaje> maquillaje;

  /// Qué tan bien combina, de 0 a 100.
  final int puntaje;

  /// Colores del look (sin repetir), para la franja de la tarjeta.
  List<String> get colores => [
    ...{
      for (final p in prendas) p.colorHex.toUpperCase(),
      for (final p in maquillaje) p.colorHex.toUpperCase(),
    },
  ];

  ProductoMaquillaje? producto(String categoria) {
    for (final p in maquillaje) {
      if (p.categoria == categoria) return p;
    }
    return null;
  }
}
