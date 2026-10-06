import 'package:flutter/foundation.dart';
import '../../core/constants/app_strings.dart';
import '../../models/perfil_colorimetria_model.dart';
import '../../providers/colorimetria_provider.dart';

/// Guarda el perfil recién analizado en Firestore (vía
/// [ColorimetriaProvider], que además lo publica a Home, Paleta, etc.).
class ResultadoViewModel extends ChangeNotifier {
  final ColorimetriaProvider _provider;
  final PerfilColorimetria perfil;

  ResultadoViewModel(this._provider, this.perfil);

  bool _guardando = false;
  bool _guardado = false;
  String? _error;
  bool _desechado = false;

  bool get guardando => _guardando;
  bool get guardado => _guardado;
  String? get error => _error;

  Future<void> guardar() async {
    if (_guardando || _guardado) return;
    _guardando = true;
    _error = null;
    _notificar();
    try {
      await _provider.guardarPerfil(perfil);
      _guardado = true;
    } catch (_) {
      _error = AppStrings.errorGuardarResultado;
    }
    _guardando = false;
    _notificar();
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
