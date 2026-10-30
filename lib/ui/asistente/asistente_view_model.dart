import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/paleta_model.dart';
import '../../models/perfil_colorimetria_model.dart';
import '../../providers/asistente_provider.dart';
import '../../providers/colorimetria_provider.dart';
import '../../providers/paleta_provider.dart';
import '../../providers/sesion_provider.dart';
import '../recomendaciones/esperar_perfil.dart';

/// Pantalla del chat con el asistente de IA — Ana.
///
/// Une [AsistenteProvider] (mensajes, envío a la Cloud Function
/// `chatAsistente` y guardado en `usuarias/{uid}/conversaciones`) con
/// [ColorimetriaProvider] (estación y subtono que se mandan como contexto).
class AsistenteViewModel extends ChangeNotifier {
  final AsistenteProvider _asistente;
  final ColorimetriaProvider _colorimetria;

  /// Nombre de la usuaria y colores de su paleta para la bienvenida.
  /// Opcionales para poder probar el chat sin ellos.
  final SesionProvider? _sesion;
  final PaletaProvider? _paletas;

  AsistenteViewModel(
    this._asistente,
    this._colorimetria, {
    this._sesion,
    this._paletas,
  }) {
    _asistente.addListener(_notificar);
    _colorimetria.addListener(_notificar);
    _paletas?.addListener(_notificar);
  }

  bool _desechado = false;

  /// Mensajes en orden (el más antiguo primero).
  List<MensajeChat> get mensajes => _asistente.mensajes;
  bool get escribiendo => _asistente.escribiendo;
  bool get puedeEnviar => _asistente.puedeEnviar;
  bool get cargandoHistorial =>
      _asistente.cargandoHistorial && _asistente.mensajes.isEmpty;
  String? get errorHistorial => _asistente.errorHistorial;
  bool get vacio => _asistente.mensajes.isEmpty;

  /// Ya se sabe si tiene análisis (para no mostrar el aviso mientras carga).
  bool get sinPerfil => _colorimetria.cargado && _colorimetria.perfil == null;

  int get largoMaximo => AsistenteProvider.largoMaximo;

  /// Primer nombre de la usuaria para el saludo ("" si no se sabe).
  String get nombre {
    final completo = _sesion?.nombreVisible.trim() ?? '';
    return completo.isEmpty ? '' : completo.split(RegExp(r'\s+')).first;
  }

  PerfilColorimetria? get perfil => _colorimetria.perfil;

  /// Colores que el asistente recomienda en la bienvenida.
  List<ColorPaleta> get coloresRecomendados =>
      (_paletas?.paleta?.coloresRecomendados ?? const []).take(5).toList();

  /// Carga la colorimetría (contexto del chat) y la última conversación.
  Future<void> cargar() async {
    await esperarPerfil(_colorimetria);
    _asistente.actualizarPerfil(_colorimetria.perfil);
    if (_asistente.cargandoHistorial) {
      // Ya la está cargando (al iniciar sesión): espera a que termine.
      final listo = Completer<void>();
      void alCambiar() {
        if (!_asistente.cargandoHistorial && !listo.isCompleted) {
          listo.complete();
        }
      }

      _asistente.addListener(alCambiar);
      try {
        await listo.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () {},
        );
      } finally {
        _asistente.removeListener(alCambiar);
      }
    } else if (!_asistente.historialCargado) {
      await _asistente.cargarHistorial();
    }
  }

  /// Envía [texto]. Devuelve el error para mostrarlo, o `null`.
  Future<String?> enviar(String texto) {
    // Por si la usuaria hizo el análisis después de abrir el chat.
    _asistente.actualizarPerfil(_colorimetria.perfil);
    return _asistente.enviar(texto);
  }

  Future<String?> reintentar(MensajeChat mensaje) =>
      _asistente.reintentar(mensaje);

  void nuevaConversacion() => _asistente.nuevaConversacion();

  void _notificar() {
    if (!_desechado) notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    _asistente.removeListener(_notificar);
    _colorimetria.removeListener(_notificar);
    _paletas?.removeListener(_notificar);
    super.dispose();
  }
}
