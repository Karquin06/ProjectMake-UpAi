import 'package:flutter/foundation.dart';
import '../../models/perfil_colorimetria_model.dart';
import '../../providers/colorimetria_provider.dart';

enum EstadoColorimetria { cargando, sinAnalisis, conResultado, error }

/// Qué debe hacer la vista al iniciar un análisis.
enum PasoAnalisis { pedirConsentimiento, abrirCaptura }

/// Lógica de la pantalla de entrada de colorimetría. El estado vive en
/// [ColorimetriaProvider]; aquí solo se interpreta para la vista.
class ColorimetriaViewModel extends ChangeNotifier {
  final ColorimetriaProvider _provider;

  ColorimetriaViewModel(this._provider) {
    _provider.addListener(notifyListeners);
  }

  EstadoColorimetria get estado {
    if (_provider.perfil != null) return EstadoColorimetria.conResultado;
    if (_provider.error != null) return EstadoColorimetria.error;
    if (_provider.cargando || !_provider.cargado) {
      return EstadoColorimetria.cargando;
    }
    return EstadoColorimetria.sinAnalisis;
  }

  PerfilColorimetria? get perfil => _provider.perfil;
  String? get error => _provider.error;

  Future<void> cargarPerfil() => _provider.cargarPerfil();

  /// Si falta el consentimiento vigente, la vista debe mostrarlo antes de
  /// abrir la cámara.
  PasoAnalisis iniciarAnalisis() => _provider.consentimientoVigente
      ? PasoAnalisis.abrirCaptura
      : PasoAnalisis.pedirConsentimiento;

  /// Igual que [iniciarAnalisis] pero primero pide confirmación con
  /// [confirmar] (el `DialogoConfirmacion` de la vista). `null` si cancela.
  Future<PasoAnalisis?> repetirAnalisis(
    Future<bool> Function() confirmar,
  ) async =>
      await confirmar() ? iniciarAnalisis() : null;

  Future<void> aceptarConsentimiento() => _provider.aceptarConsentimiento();

  @override
  void dispose() {
    _provider.removeListener(notifyListeners);
    super.dispose();
  }
}
