import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';
import 'model_utils.dart';

/// Recomendación de un ítem del catálogo para la usuaria.
///
/// Subcolección: `usuarias/{uid}/recomendaciones/{id}` (el id es el del
/// producto o la prenda). Se guarda cuando la usuaria la califica, para
/// mejorar el orden de las siguientes recomendaciones.
///
/// Referencia a un producto O a una prenda (uno de los dos es null): así lo
/// exigen las reglas de Firestore.
class Recomendacion {
  static const coleccion = 'recomendaciones';

  final String id;
  final String uid;
  final String? productoId;
  final String? prendaId;
  final TipoRecomendacion tipo;
  final String? ocasion;
  final DateTime fecha;

  /// Compatibilidad con su colorimetría, de 0 a 100.
  final int puntaje;

  /// Por qué le queda bien (según su estación y subtono).
  final String motivo;

  /// Calificación de la usuaria (1 a 5), o `null` si no ha calificado.
  final int? calificacion;

  const Recomendacion({
    required this.id,
    required this.uid,
    this.productoId,
    this.prendaId,
    required this.tipo,
    this.ocasion,
    required this.fecha,
    this.puntaje = 0,
    this.motivo = '',
    this.calificacion,
  });

  /// Id del producto o la prenda recomendada.
  String get itemId => productoId ?? prendaId ?? id;

  bool get esPrenda => prendaId != null;

  factory Recomendacion.fromMap(Map<String, dynamic> m, {required String id}) =>
      Recomendacion(
        id: id,
        uid: m['uid'] as String? ?? '',
        productoId: m['productoId'] as String?,
        prendaId: m['prendaId'] as String?,
        tipo: enumFromName(TipoRecomendacion.values, m['tipo'] as String?) ??
            TipoRecomendacion.maquillaje,
        ocasion: m['ocasion'] as String?,
        fecha: dateFromFirestore(m['fecha']) ?? DateTime.now(),
        puntaje: (m['puntaje'] as num?)?.round() ?? 0,
        motivo: m['motivo'] as String? ?? '',
        calificacion: (m['calificacion'] as num?)?.round(),
      );

  factory Recomendacion.fromFirestore(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      Recomendacion.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'productoId': productoId,
        'prendaId': prendaId,
        'tipo': tipo.name,
        'ocasion': ocasion,
        'fecha': Timestamp.fromDate(fecha),
        'puntaje': puntaje,
        'motivo': motivo,
        'calificacion': calificacion,
      };

  Recomendacion copyWith({
    int? puntaje,
    String? motivo,
    int? calificacion,
    String? ocasion,
    DateTime? fecha,
  }) =>
      Recomendacion(
        id: id,
        uid: uid,
        productoId: productoId,
        prendaId: prendaId,
        tipo: tipo,
        ocasion: ocasion ?? this.ocasion,
        fecha: fecha ?? this.fecha,
        puntaje: puntaje ?? this.puntaje,
        motivo: motivo ?? this.motivo,
        calificacion: calificacion ?? this.calificacion,
      );
}
