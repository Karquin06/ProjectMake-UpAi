import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_utils.dart';

/// Aceptación de un documento legal (p. ej. el aviso de privacidad).
/// Se guarda dentro del mapa `consentimientos` de `usuarias/{uid}`.
class Consentimiento {
  /// Clave del aviso de privacidad dentro de `consentimientos`.
  static const avisoPrivacidad = 'avisoPrivacidad';

  final String version;
  final DateTime fecha;

  const Consentimiento({required this.version, required this.fecha});

  factory Consentimiento.fromMap(Map<String, dynamic> m) => Consentimiento(
        version: m['version'] as String? ?? '',
        fecha: dateFromFirestore(m['fecha']) ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'version': version,
        'fecha': Timestamp.fromDate(fecha),
      };
}

/// Colección raíz: usuarias/{uid}
class Usuaria {
  static const collection = 'usuarias';

  // Subcolecciones privadas de cada usuaria
  static const subPerfilColorimetria = 'perfilColorimetria';
  static const subPaletas = 'paletas';
  static const subRecomendaciones = 'recomendaciones';
  static const subArmario = 'armario';
  static const subConversaciones = 'conversaciones';
  static const subPrendasAnalizadas = 'prendasAnalizadas';
  static const subSuscripciones = 'suscripciones';

  // Valores posibles de `rol`. El rol NO se modifica desde la app
  // (lo protegen las reglas de Firestore); un admin se asigna desde consola.
  static const rolUsuaria = 'usuaria';
  static const rolAdmin = 'admin';

  final String uid;
  final String nombre;
  final String email;
  final DateTime fechaRegistro;
  final String? fotoPerfilUrl;
  final String? tokenNotificaciones;
  final String rol;
  final Map<String, Consentimiento> consentimientos;

  const Usuaria({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.fechaRegistro,
    this.fotoPerfilUrl,
    this.tokenNotificaciones,
    this.rol = rolUsuaria,
    this.consentimientos = const {},
  });

  bool get esAdmin => rol == rolAdmin;

  /// Consentimiento del aviso de privacidad, si fue aceptado.
  Consentimiento? get consentimientoPrivacidad =>
      consentimientos[Consentimiento.avisoPrivacidad];

  factory Usuaria.fromMap(Map<String, dynamic> m, {required String id}) =>
      Usuaria(
        uid: id,
        nombre: m['nombre'] as String? ?? '',
        email: m['email'] as String? ?? '',
        fechaRegistro: dateFromFirestore(m['fechaRegistro']) ?? DateTime.now(),
        fotoPerfilUrl: m['fotoPerfilURL'] as String?,
        tokenNotificaciones: m['tokenNotificaciones'] as String?,
        rol: m['rol'] as String? ?? rolUsuaria,
        consentimientos: _consentimientosDesde(m['consentimientos']),
      );

  factory Usuaria.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Usuaria.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'nombre': nombre,
        'email': email,
        'fechaRegistro': Timestamp.fromDate(fechaRegistro),
        'fotoPerfilURL': fotoPerfilUrl,
        'tokenNotificaciones': tokenNotificaciones,
        'rol': rol,
        'consentimientos':
            consentimientos.map((clave, c) => MapEntry(clave, c.toMap())),
      };

  /// `rol` no se incluye a propósito: no puede cambiarse desde la app.
  Usuaria copyWith({
    String? nombre,
    String? email,
    String? fotoPerfilUrl,
    String? tokenNotificaciones,
    Map<String, Consentimiento>? consentimientos,
  }) =>
      Usuaria(
        uid: uid,
        nombre: nombre ?? this.nombre,
        email: email ?? this.email,
        fechaRegistro: fechaRegistro,
        fotoPerfilUrl: fotoPerfilUrl ?? this.fotoPerfilUrl,
        tokenNotificaciones: tokenNotificaciones ?? this.tokenNotificaciones,
        rol: rol,
        consentimientos: consentimientos ?? this.consentimientos,
      );

  static Map<String, Consentimiento> _consentimientosDesde(dynamic raw) {
    if (raw is! Map) return const {};
    final resultado = <String, Consentimiento>{};
    raw.forEach((clave, valor) {
      if (valor is Map) {
        resultado[clave.toString()] =
            Consentimiento.fromMap(Map<String, dynamic>.from(valor));
      }
    });
    return resultado;
  }
}
