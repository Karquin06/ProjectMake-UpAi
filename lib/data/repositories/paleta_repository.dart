import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/enums.dart';
import '../../models/paleta_model.dart';

/// Repositorio de `paletas/{estacion}` (solo lectura desde la app; las
/// paletas se cargan con `functions` → `npm run sembrar:paletas`).
class PaletaRepository {
  final FirebaseFirestore? _dbInyectada;

  PaletaRepository({FirebaseFirestore? db}) : _dbInyectada = db;

  FirebaseFirestore get _db => _dbInyectada ?? FirebaseFirestore.instance;

  /// `null` si la paleta de [estacion] aún no está cargada.
  Future<Paleta?> obtenerPaleta(EstacionColor estacion) async {
    final doc =
        await _db.collection(Paleta.coleccion).doc(estacion.name).get();
    return doc.exists ? Paleta.fromFirestore(doc) : null;
  }
}
