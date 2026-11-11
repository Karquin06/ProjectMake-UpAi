import 'package:flutter/foundation.dart';
import '../../core/errors/firebase_error_mapper.dart';
import '../../data/services/marcas_service.dart';
import '../../models/estadisticas_marca.dart';

/// Panel "Mi marca": cuántas usuarias aman sus productos — Ana.
///
/// [marcaId] solo lo pasa la admin general (para ver el panel de cualquier
/// marca); el admin de la marca ve la suya (la función la toma del token).
class MiMarcaViewModel extends ChangeNotifier {
  final MarcasService _funciones;
  final String? marcaId;

  MiMarcaViewModel(this._funciones, {this.marcaId});

  ResumenMarca? _resumen;
  bool _cargando = false;
  String? _error;
  bool _cerrado = false;

  ResumenMarca? get resumen => _resumen;
  bool get cargando => _cargando;
  String? get error => _error;

  /// `true` si la marca todavía no tiene ninguna interacción.
  bool get sinDatos {
    final t = _resumen?.totales;
    return t == null || (t.gusta == 0 && t.vistas == 0 && t.pruebasAr == 0 && t.calificaciones == 0);
  }

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    _notificar();
    try {
      _resumen = await _funciones.resumenMarca(marcaId: marcaId);
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
    } finally {
      _cargando = false;
      _notificar();
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
