import 'package:flutter/foundation.dart';
import '../../core/errors/firebase_error_mapper.dart';
import '../../data/repositories/marca_repository.dart';
import '../../models/marca.dart';

/// Lista de marcas de la admin general — Ana.
class MarcasAdminViewModel extends ChangeNotifier {
  final MarcaRepository _repo;

  MarcasAdminViewModel(this._repo);

  bool _cargando = false;
  String? _error;
  List<Marca> _marcas = const [];
  String _busqueda = '';
  bool _cerrado = false;

  bool get cargando => _cargando;
  String? get error => _error;
  bool get vacia => !_cargando && _error == null && _marcas.isEmpty;

  /// Marcas filtradas por la búsqueda.
  List<Marca> get marcas {
    final q = _busqueda.trim().toLowerCase();
    if (q.isEmpty) return _marcas;
    return _marcas.where((m) => m.nombre.toLowerCase().contains(q)).toList();
  }

  int get total => _marcas.length;
  int get activas => _marcas.where((m) => m.activa).length;

  void buscar(String texto) {
    _busqueda = texto;
    _notificar();
  }

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    _notificar();
    try {
      _marcas = await _repo.listar();
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
    } finally {
      _cargando = false;
      _notificar();
    }
  }

  /// Devuelve el mensaje de error, o `null` si salió bien.
  Future<String?> cambiarActiva(Marca marca, bool activa) async {
    final anterior = _marcas;
    _marcas = [
      for (final m in _marcas) m.id == marca.id ? m.copyWith(activa: activa) : m,
    ];
    _notificar();
    try {
      await _repo.cambiarActiva(marca.id, activa);
      return null;
    } catch (e) {
      _marcas = anterior;
      _notificar();
      return FirebaseErrorMapper.mensaje(e);
    }
  }

  void _notificar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
