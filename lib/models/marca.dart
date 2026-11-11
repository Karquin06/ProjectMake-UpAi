import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_utils.dart';

/// Colección global: marcas/{id} — Ana.
///
/// La crea la admin general. Sus productos están en `productosMaquillaje`
/// con `marcaId`. [admins] son los correos que pueden administrarla (los
/// pone la Cloud Function `asignarAdminMarca`, no la app).
class Marca {
  static const collection = 'marcas';

  final String id;
  final String nombre;
  final String descripcion;

  /// Color de la marca en HEX (`#C2185B`); tiñe su panel y sus tarjetas.
  final String colorHex;
  final String logoUrl;

  /// Ruta del logo en Storage (para borrarlo al reemplazarlo).
  final String? logoRuta;
  final String? sitioWeb;
  final bool activa;
  final List<String> admins;
  final DateTime? fechaCreacion;

  const Marca({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.colorHex = '',
    this.logoUrl = '',
    this.logoRuta,
    this.sitioWeb,
    this.activa = true,
    this.admins = const [],
    this.fechaCreacion,
  });

  /// Iniciales para el avatar cuando no hay logo ("L'Oréal Paris" → "LP").
  String get iniciales {
    final palabras = nombre
        .split(RegExp(r"[\s'’\-]+"))
        .where((p) => p.isNotEmpty && RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ0-9]').hasMatch(p[0]))
        .toList();
    if (palabras.isEmpty) return '?';
    if (palabras.length == 1) {
      return palabras.first.substring(0, palabras.first.length < 2 ? 1 : 2).toUpperCase();
    }
    return (palabras.first[0] + palabras.last[0]).toUpperCase();
  }

  factory Marca.fromMap(Map<String, dynamic> m, {required String id}) => Marca(
        id: id,
        nombre: m['nombre'] as String? ?? '',
        descripcion: m['descripcion'] as String? ?? '',
        colorHex: m['colorHex'] as String? ?? '',
        logoUrl: m['logoURL'] as String? ?? '',
        logoRuta: m['logoRuta'] as String?,
        sitioWeb: (m['sitioWeb'] is String && (m['sitioWeb'] as String).isNotEmpty)
            ? m['sitioWeb'] as String
            : null,
        activa: m['activa'] as bool? ?? true,
        admins: [
          for (final a in (m['admins'] as List? ?? const [])) if (a is String) a,
        ],
        fechaCreacion: dateFromFirestore(m['fechaCreacion']),
      );

  factory Marca.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Marca.fromMap(doc.data()!, id: doc.id);

  /// `admins` NO se escribe desde la app (lo maneja la Cloud Function).
  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'nombreMinusculas': nombre.trim().toLowerCase(),
        'descripcion': descripcion,
        'colorHex': colorHex,
        'logoURL': logoUrl,
        'logoRuta': ?logoRuta,
        'sitioWeb': ?sitioWeb,
        'activa': activa,
        'fechaCreacion': Timestamp.fromDate(fechaCreacion ?? DateTime.now()),
      };

  Marca copyWith({
    String? nombre,
    String? descripcion,
    String? colorHex,
    String? logoUrl,
    String? logoRuta,
    String? sitioWeb,
    bool? activa,
  }) =>
      Marca(
        id: id,
        nombre: nombre ?? this.nombre,
        descripcion: descripcion ?? this.descripcion,
        colorHex: colorHex ?? this.colorHex,
        logoUrl: logoUrl ?? this.logoUrl,
        logoRuta: logoRuta ?? this.logoRuta,
        sitioWeb: sitioWeb ?? this.sitioWeb,
        activa: activa ?? this.activa,
        admins: admins,
        fechaCreacion: fechaCreacion,
      );
}
