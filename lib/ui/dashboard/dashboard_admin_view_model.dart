import 'package:flutter/foundation.dart';
import '../../core/errors/firebase_error_mapper.dart';
import '../../data/services/marcas_service.dart';
import '../../models/estadisticas_marca.dart';

/// Dashboard general de la admin — Ana.
class DashboardAdminViewModel extends ChangeNotifier {
  final MarcasService _funciones;

  DashboardAdminViewModel(this._funciones);

  ResumenAdmin? _resumen;
  bool _cargando = false;
  String? _error;
  bool _cerrado = false;

  ResumenAdmin? get resumen => _resumen;
  bool get cargando => _cargando;
  String? get error => _error;

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    _notificar();
    try {
      _resumen = await _funciones.resumenAdmin();
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
