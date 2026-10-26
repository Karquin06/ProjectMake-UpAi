import 'package:flutter/foundation.dart';
import '../core/constants/app_strings.dart';
import '../data/repositories/armario_repository.dart';
import '../models/elemento_armario.dart';
import 'limpieza_sesion.dart';

class ArmarioProvider extends ChangeNotifier with LimpiezaPorSesion {
  ArmarioProvider(this._repositorio);
  final ArmarioRepository _repositorio;
  List<ElementoArmario> _elementos = [];
  String? _uidDatos;
  int _revision = 0;
  @override
  void sincronizarUsuaria(String? uid) {
    if (uid != uidSesion) _revision++;
    super.sincronizarUsuaria(uid);
  }

  bool _cargando = false, _guardando = false;
  String? _error;
  List<ElementoArmario> get elementos =>
      _uidDatos == uidSesion ? List.unmodifiable(_elementos) : const [];
  bool get cargando => _cargando || _uidDatos != uidSesion;
  bool get guardando => _guardando;
  String? get error => _error;
  bool contiene(ElementoArmario e) => elementos.any((x) => x.clave == e.clave);
  @override
  Future<void> alIniciarSesion(String uid) => cargar();
  Future<void> cargar() async {
    final uid = uidSesion;
    final revision = _revision;
    if (uid == null || _cargando || _guardando) return;
    _cargando = true;
    _error = null;
    notificarSiActivo();
    try {
      final datos = await _repositorio.cargar(uid);
      if (uidSesion != uid || revision != _revision) return;
      _elementos = datos;
      _uidDatos = uid;
    } catch (_) {
      if (uidSesion == uid && revision == _revision) {
        _error = AppStrings.armarioErrorLectura;
      }
    } finally {
      if (uidSesion == uid && revision == _revision) {
        _cargando = false;
        notificarSiActivo();
      }
    }
  }

  Future<bool> agregar(ElementoArmario e) => _cambiar(e, eliminar: false);
  Future<bool> quitar(ElementoArmario e) => _cambiar(e, eliminar: true);
  Future<bool> _cambiar(ElementoArmario e, {required bool eliminar}) async {
    final uid = uidSesion;
    final revision = _revision;
    if (uid == null || cargando || _guardando || _uidDatos != uid) return false;
    final nuevos = [
      for (final x in _elementos)
        if (x.clave != e.clave) x,
    ];
    if (!eliminar) nuevos.insert(0, e);
    _guardando = true;
    _error = null;
    notificarSiActivo();
    try {
      await _repositorio.guardar(uid, nuevos);
      if (uidSesion != uid || revision != _revision) return false;
      _elementos = nuevos;
      return true;
    } catch (_) {
      if (uidSesion == uid && revision == _revision) {
        _error = AppStrings.armarioErrorGuardado;
      }
      return false;
    } finally {
      if (uidSesion == uid && revision == _revision) {
        _guardando = false;
        notificarSiActivo();
      }
    }
  }

  @override
  void limpiar() {
    _elementos = [];
    _uidDatos = null;
    _cargando = false;
    _guardando = false;
    _error = null;
  }
}
