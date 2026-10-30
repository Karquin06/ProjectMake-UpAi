import 'package:flutter/foundation.dart';
import '../../core/errors/firebase_error_mapper.dart';
import '../../data/repositories/catalogo_repository.dart';
import '../../data/services/looks/motor_looks.dart';
import '../../models/look_colorimetria.dart';
import '../../models/prenda_ropa.dart';
import '../../models/producto_maquillaje.dart';
import '../../providers/colorimetria_provider.dart';

enum EstadoLooks { cargando, sinAnalisis, listo, error }

/// Looks completos (ropa + maquillaje) armados con la colorimetría de la
/// usuaria y el catálogo activo. El catálogo se trae una vez; cambiar la
/// ocasión solo vuelve a correr el motor (en el teléfono, sin red).
class LooksViewModel extends ChangeNotifier {
  LooksViewModel(
    this._colorimetria,
    this._catalogo, {
    this._motor = const MotorLooks(),
  }) {
    _colorimetria.addListener(_alCambiarPerfil);
  }

  final ColorimetriaProvider _colorimetria;
  final CatalogoRepository _catalogo;
  final MotorLooks _motor;

  List<PrendaRopa>? _prendas;
  List<ProductoMaquillaje>? _productos;
  List<LookColorimetria> _looks = const [];
  String? _ocasion;
  String? _error;
  bool _cargando = false;
  bool _desechado = false;

  List<LookColorimetria> get looks => _looks;
  String? get ocasion => _ocasion;
  String? get error => _error;

  EstadoLooks get estado {
    if (_error != null) return EstadoLooks.error;
    if (_cargando || !_colorimetria.cargado) return EstadoLooks.cargando;
    if (_colorimetria.perfil == null) return EstadoLooks.sinAnalisis;
    return _prendas == null ? EstadoLooks.cargando : EstadoLooks.listo;
  }

  Future<void> cargar() async {
    if (_cargando) return;
    _cargando = true;
    _error = null;
    _notificar();
    try {
      if (!_colorimetria.cargado || _colorimetria.error != null) {
        await _colorimetria.cargarPerfil();
      }
      if (_colorimetria.error != null) {
        _error = _colorimetria.error;
      } else if (_colorimetria.perfil != null) {
        final resultado = await Future.wait([
          _catalogo.prendasActivas(),
          _catalogo.productosActivos(),
        ]);
        _prendas = resultado[0] as List<PrendaRopa>;
        _productos = resultado[1] as List<ProductoMaquillaje>;
        _generar();
      }
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
    } finally {
      _cargando = false;
      _notificar();
    }
  }

  void cambiarOcasion(String? ocasion) {
    if (ocasion == _ocasion) return;
    _ocasion = ocasion;
    _generar();
    _notificar();
  }

  void _generar() {
    final perfil = _colorimetria.perfil;
    _looks = perfil == null || _prendas == null
        ? const []
        : _motor.crear(
            perfil: perfil,
            prendas: _prendas!,
            productos: _productos ?? const [],
            ocasion: _ocasion,
          );
  }

  /// Si la usuaria rehace su análisis, los looks se recalculan.
  void _alCambiarPerfil() {
    _generar();
    _notificar();
  }

  void _notificar() {
    if (!_desechado) notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    _colorimetria.removeListener(_alCambiarPerfil);
    super.dispose();
  }
}
