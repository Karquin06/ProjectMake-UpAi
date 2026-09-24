import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';
import 'model_utils.dart';

/// Subcolección: usuarias/{uid}/perfilColorimetria/{id}
/// Relación 1:1 con la usuaria: usa un único documento (p. ej. id = 'actual').
class PerfilColorimetria {
  static const docIdActual = 'actual';

  final String id;
  final String uid;
  final String fotoSelfieUrl;
  final String tonoPiel;
  final Subtono? subtono;
  final String colorOjos;
  final String colorCabello;
  final EstacionColor? estacionColor;
  final DateTime fechaAnalisis;

  const PerfilColorimetria({
    required this.id,
    required this.uid,
    required this.fotoSelfieUrl,
    required this.tonoPiel,
    this.subtono,
    required this.colorOjos,
    required this.colorCabello,
    this.estacionColor,
    required this.fechaAnalisis,
  });

  factory PerfilColorimetria.fromMap(Map<String, dynamic> m,
          {required String id}) =>
      PerfilColorimetria(
        id: id,
        uid: m['uid'] as String? ?? '',
        fotoSelfieUrl: m['fotoSelfieURL'] as String? ?? '',
        tonoPiel: m['tonoPiel'] as String? ?? '',
        subtono: enumFromName(Subtono.values, m['subtono'] as String?),
        colorOjos: m['colorOjos'] as String? ?? '',
        colorCabello: m['colorCabello'] as String? ?? '',
        estacionColor:
            enumFromName(EstacionColor.values, m['estacionColor'] as String?),
        fechaAnalisis: dateFromFirestore(m['fechaAnalisis']) ?? DateTime.now(),
      );

  factory PerfilColorimetria.fromFirestore(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      PerfilColorimetria.fromMap(doc.data()!, id: doc.id);

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'fotoSelfieURL': fotoSelfieUrl,
        'tonoPiel': tonoPiel,
        'subtono': subtono?.name,
        'colorOjos': colorOjos,
        'colorCabello': colorCabello,
        'estacionColor': estacionColor?.name,
        'fechaAnalisis': Timestamp.fromDate(fechaAnalisis),
      };
}
