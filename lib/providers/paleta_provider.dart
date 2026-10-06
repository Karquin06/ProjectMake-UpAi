import 'package:flutter/foundation.dart';
import '../core/errors/firebase_error_mapper.dart';
import '../data/repositories/paleta_repository.dart';
import '../data/services/colorimetria_service.dart';
import '../models/enums.dart';
import '../models/paleta_model.dart';

/// Paleta de la estación de la usuaria. Sigue a [ColorimetriaProvider]:
/// se registra con `ChangeNotifierProxyProvider` y llama a
/// [sincronizarEstacion] cada vez que cambia el perfil.
class PaletaProvider extends ChangeNotifier {
  final Future<Paleta> Function(EstacionColor estacion) _cargar;

  PaletaProvider(ColorimetriaService servicio) : _cargar = servicio.generarPaleta;

  /// Lee `paletas/{estacion}` y, si no está cargada, la pide a
  /// `generarPaleta`.
  PaletaProvider.conRespaldo(
    PaletaRepository repositorio,
    ColorimetriaService servicio,
  ) : _cargar = ((estacion) async =>
            await repositorio.obtenerPaleta(estacion) ??
            await servicio.generarPaleta(estacion));

  /// Para pruebas o para cambiar la fuente (p. ej. `PaletaRepository`).
  PaletaProvider.conFuente(this._cargar);

  EstacionColor? _estacion;
  Paleta? _paleta;
  bool _cargando = false;
  String? _error;
  bool _desechado = false;

  EstacionColor? get estacion => _estacion;
  Paleta? get paleta => _paleta;
  bool get cargando => _cargando;
  String? get error => _error;

  /// Cambia la estación a mostrar; `null` (sin análisis o sesión cerrada)
  /// limpia la paleta.
  void sincronizarEstacion(EstacionColor? estacion) {
    if (estacion == _estacion) return;
    _estacion = estacion;
    _paleta = null;
    _error = null;
    // Diferido: se llama desde `update` durante el build.
    Future.microtask(() {
      if (_desechado || _estacion != estacion) return;
      if (estacion == null) {
        notifyListeners();
      } else {
        refrescar();
      }
    });
  }

  Future<void> refrescar() async {
    final estacion = _estacion;
    if (estacion == null || _cargando) return;
    _cargando = true;
    _error = null;
    _notificar();
    try {
      final paleta = await _cargar(estacion);
      if (estacion == _estacion) _paleta = paleta;
    } catch (e) {
      if (estacion == _estacion) _error = FirebaseErrorMapper.mensaje(e);
    }
    _cargando = false;
    _notificar();
    // Si la estación cambió mientras cargaba, carga la nueva.
    if (estacion != _estacion && _estacion != null) await refrescar();
  }

  void _notificar() {
    if (!_desechado) notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    super.dispose();
  }
}
