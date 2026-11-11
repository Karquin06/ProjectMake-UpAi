import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import '../data/repositories/me_gusta_repository.dart';
import 'limpieza_sesion.dart';

/// Productos a los que la usuaria les dio ❤️ — Ana.
///
/// El cambio se ve al instante (optimista) y se revierte si Firestore
/// falla. Se limpia solo al cerrar sesión.
class MeGustaProvider extends ChangeNotifier with LimpiezaPorSesion {
  final MeGustaRepository _repo;

  MeGustaProvider(this._repo);

  final Set<String> _ids = {};
  final Set<String> _enCurso = {};
  bool _cargado = false;

  bool get cargado => _cargado;
  Set<String> get ids => Set.unmodifiable(_ids);

  bool leGusta(String productoId) => _ids.contains(productoId);

  @override
  void limpiar() {
    _ids.clear();
    _enCurso.clear();
    _cargado = false;
  }

  @override
  Future<void> alIniciarSesion(String uid) async {
    try {
      final ids = await _repo.productos(uid);
      if (uid != uidSesion) return;
      _ids
        ..clear()
        ..addAll(ids);
      _cargado = true;
      notificarSiActivo();
    } catch (_) {
      // Sin corazones cargados la app sigue funcionando.
    }
  }

  /// Pone o quita el corazón. Devuelve el mensaje de error, o `null`.
  Future<String?> alternar(String productoId) async {
    final uid = uidSesion;
    if (uid == null || _enCurso.contains(productoId)) return null;
    final marcar = !_ids.contains(productoId);
    _enCurso.add(productoId);
    if (marcar) {
      _ids.add(productoId);
    } else {
      _ids.remove(productoId);
    }
    notificarSiActivo();
    try {
      if (marcar) {
        await _repo.marcar(uid, productoId);
      } else {
        await _repo.quitar(uid, productoId);
      }
      return null;
    } on AppException catch (e) {
      if (marcar) {
        _ids.remove(productoId);
      } else {
        _ids.add(productoId);
      }
      return e.mensaje;
    } finally {
      _enCurso.remove(productoId);
      notificarSiActivo();
    }
  }
}
