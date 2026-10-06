import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';
import 'model_utils.dart';

/// Aceptación del consentimiento biométrico (uso de la selfie para el
/// análisis). Se guarda dentro del perfil con la fecha y la versión del
/// texto aceptado.
class ConsentimientoBiometrico {
  /// Versión vigente del texto de consentimiento biométrico. Si cambia el
  /// texto, se incrementa y se vuelve a pedir la aceptación.
  static const versionVigente = '1.0';

  final DateTime fecha;
  final String version;

  const ConsentimientoBiometrico({required this.fecha, required this.version});

  /// Aceptación hecha ahora sobre la versión vigente.
  factory ConsentimientoBiometrico.ahora() =>
      ConsentimientoBiometrico(fecha: DateTime.now(), version: versionVigente);

  bool get esVigente => version == versionVigente;

  factory ConsentimientoBiometrico.fromMap(Map<String, dynamic> m) =>
      ConsentimientoBiometrico(
        fecha: dateFromFirestore(m['fecha']) ?? DateTime.now(),
        version: m['version'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'fecha': Timestamp.fromDate(fecha),
        'version': version,
      };
}

/// Colección: perfiles_colorimetria/{uid}
/// Resultado del análisis de colorimetría de la usuaria (1 documento por
/// usuaria, el id es el uid). La selfie NO se guarda: se borra tras el
/// análisis.
class PerfilColorimetria {
  static const coleccion = 'perfiles_colorimetria';

  final String uid;
  final EstacionColor estacionColor;
  final Subtono subtono;
  final Contraste contraste;
  final Intensidad intensidad;

  /// Confianza del análisis entre 0 y 1.
  final double confianza;
  final DateTime fechaAnalisis;
  final ConsentimientoBiometrico? consentimiento;

  const PerfilColorimetria({
    required this.uid,
    required this.estacionColor,
    required this.subtono,
    required this.contraste,
    required this.intensidad,
    required this.confianza,
    required this.fechaAnalisis,
    this.consentimiento,
  });

  /// Lee el documento de Firestore o la respuesta de `analizarSelfie`
  /// (mismas claves). Los valores desconocidos caen en un valor por defecto.
  factory PerfilColorimetria.fromMap(Map<String, dynamic> m,
      {required String uid}) {
    final consentimiento = m['consentimiento'];
    return PerfilColorimetria(
      uid: uid,
      estacionColor:
          enumFromName(EstacionColor.values, m['estacion'] as String?) ??
              EstacionColor.invierno,
      subtono: enumFromName(Subtono.values, m['subtono'] as String?) ??
          Subtono.neutro,
      contraste: enumFromName(Contraste.values, m['contraste'] as String?) ??
          Contraste.medio,
      intensidad:
          enumFromName(Intensidad.values, m['intensidad'] as String?) ??
              Intensidad.media,
      confianza: toDouble(m['confianza']).clamp(0.0, 1.0),
      fechaAnalisis: dateFromFirestore(m['fechaAnalisis']) ?? DateTime.now(),
      consentimiento: consentimiento is Map
          ? ConsentimientoBiometrico.fromMap(
              Map<String, dynamic>.from(consentimiento))
          : null,
    );
  }

  factory PerfilColorimetria.fromFirestore(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      PerfilColorimetria.fromMap(doc.data()!, uid: doc.id);

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'estacion': estacionColor.name,
        'subtono': subtono.name,
        'contraste': contraste.name,
        'intensidad': intensidad.name,
        'confianza': confianza,
        'fechaAnalisis': Timestamp.fromDate(fechaAnalisis),
        // Se omite si es null para no borrar el guardado al hacer merge.
        if (consentimiento != null) 'consentimiento': consentimiento!.toMap(),
      };

  /// `true` si [m] trae un resultado de análisis (y no solo el
  /// consentimiento guardado antes de analizar).
  static bool tieneAnalisis(Map<String, dynamic>? m) => m?['estacion'] != null;

  PerfilColorimetria copyWith({
    String? uid,
    EstacionColor? estacionColor,
    Subtono? subtono,
    Contraste? contraste,
    Intensidad? intensidad,
    double? confianza,
    DateTime? fechaAnalisis,
    ConsentimientoBiometrico? consentimiento,
  }) =>
      PerfilColorimetria(
        uid: uid ?? this.uid,
        estacionColor: estacionColor ?? this.estacionColor,
        subtono: subtono ?? this.subtono,
        contraste: contraste ?? this.contraste,
        intensidad: intensidad ?? this.intensidad,
        confianza: confianza ?? this.confianza,
        fechaAnalisis: fechaAnalisis ?? this.fechaAnalisis,
        consentimiento: consentimiento ?? this.consentimiento,
      );
}
