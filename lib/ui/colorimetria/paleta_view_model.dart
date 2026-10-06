import 'package:flutter/foundation.dart';
import '../../models/enums.dart';
import '../../models/paleta_model.dart';
import '../../providers/colorimetria_provider.dart';
import '../../providers/paleta_provider.dart';

enum EstadoPaleta { cargando, sinAnalisis, conPaleta, error }

/// Interpreta [ColorimetriaProvider] (¿hay análisis?) y [PaletaProvider]
/// (colores de la estación) para la pantalla de paleta.
class PaletaViewModel extends ChangeNotifier {
  final ColorimetriaProvider _colorimetria;
  final PaletaProvider _paletas;

  PaletaViewModel(this._colorimetria, this._paletas) {
    _colorimetria.addListener(notifyListeners);
    _paletas.addListener(notifyListeners);
  }

  EstadoPaleta get estado {
    if (_colorimetria.perfil == null) {
      if (_colorimetria.error != null) return EstadoPaleta.error;
      return _colorimetria.cargado
          ? EstadoPaleta.sinAnalisis
          : EstadoPaleta.cargando;
    }
    if (_paletas.paleta != null) return EstadoPaleta.conPaleta;
    if (_paletas.error != null) return EstadoPaleta.error;
    return EstadoPaleta.cargando;
  }

  String? get error => _colorimetria.error ?? _paletas.error;
  EstacionColor? get estacion => _colorimetria.perfil?.estacionColor;
  List<ColorPaleta> get recomendados =>
      _paletas.paleta?.coloresRecomendados ?? const [];
  List<ColorPaleta> get evitar => _paletas.paleta?.coloresEvitar ?? const [];

  /// Carga lo que falte (p. ej. si se abrió la paleta antes que Colorimetría).
  Future<void> cargar() async {
    if (!_colorimetria.cargado || _colorimetria.error != null) {
      await _colorimetria.cargarPerfil();
    }
    if (_colorimetria.perfil != null && _paletas.paleta == null) {
      await _paletas.refrescar();
    }
  }

  @override
  void dispose() {
    _colorimetria.removeListener(notifyListeners);
    _paletas.removeListener(notifyListeners);
    super.dispose();
  }
}
