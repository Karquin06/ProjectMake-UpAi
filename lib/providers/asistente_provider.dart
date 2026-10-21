import 'package:flutter/foundation.dart';
import '../core/constants/app_strings.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/firebase_error_mapper.dart';
import '../data/repositories/conversacion_repository.dart';
import '../data/services/funciones_ia_service.dart';
import '../models/conversacion.dart';
import '../models/perfil_colorimetria_model.dart';
import 'limpieza_sesion.dart';

enum EstadoMensaje { enviando, enviado, error }

/// Mensaje del chat tal como se muestra en pantalla.
class MensajeChat {
  final String id;
  final bool esUsuaria;
  final String contenido;
  final DateTime fecha;
  final EstadoMensaje estado;

  /// Por qué falló (solo si [estado] es [EstadoMensaje.error]).
  final String? error;

  const MensajeChat({
    required this.id,
    required this.esUsuaria,
    required this.contenido,
    required this.fecha,
    this.estado = EstadoMensaje.enviado,
    this.error,
  });

  MensajeChat conEstado(EstadoMensaje estado, {String? error}) => MensajeChat(
        id: id,
        esUsuaria: esUsuaria,
        contenido: contenido,
        fecha: fecha,
        estado: estado,
        error: error,
      );

  Mensaje aModelo() => Mensaje(
        rol: esUsuaria ? 'user' : 'assistant',
        contenido: contenido,
        fecha: fecha,
      );
}

/// Estado del chat con el asistente de IA — Ana.
///
/// Envía cada mensaje a la Cloud Function `chatAsistente` con los últimos
/// 10 mensajes y el contexto de colorimetría (estación y subtono). Guarda
/// la conversación en `usuarias/{uid}/conversaciones` y la recupera al
/// iniciar sesión. Se limpia al cerrar sesión.
class AsistenteProvider extends ChangeNotifier with LimpiezaPorSesion {
  static const largoMaximo = 500;
  static const historialMaximo = 10;

  final FuncionesIaService _funciones;
  final ConversacionRepository _conversaciones;

  AsistenteProvider({
    required this._funciones,
    required this._conversaciones,
  });

  PerfilColorimetria? _perfil;
  String? _conversacionId;
  List<MensajeChat> _mensajes = [];
  bool _escribiendo = false;
  bool _cargandoHistorial = false;
  bool _historialCargado = false;
  String? _errorHistorial;
  int _contador = 0;

  List<MensajeChat> get mensajes => List.unmodifiable(_mensajes);
  bool get escribiendo => _escribiendo;
  bool get cargandoHistorial => _cargandoHistorial;
  bool get historialCargado => _historialCargado;
  String? get errorHistorial => _errorHistorial;
  bool get tienePerfil => _perfil != null;
  PerfilColorimetria? get perfil => _perfil;

  /// `true` si se puede enviar ahora (no hay una respuesta en camino).
  bool get puedeEnviar => !_escribiendo;

  @override
  void limpiar() {
    _perfil = null;
    _conversacionId = null;
    _mensajes = [];
    _escribiendo = false;
    _cargandoHistorial = false;
    _historialCargado = false;
    _errorHistorial = null;
  }

  @override
  Future<void> alIniciarSesion(String uid) => cargarHistorial();

  /// Llamar desde `update` del proxy con el perfil de colorimetría.
  void actualizarPerfil(PerfilColorimetria? perfil) => _perfil = perfil;

  /// Recupera la conversación más reciente.
  Future<void> cargarHistorial() async {
    final uid = uidSesion;
    if (uid == null || _cargandoHistorial) return;
    _cargandoHistorial = true;
    _errorHistorial = null;
    notificarSiActivo();
    try {
      final ultima = await _conversaciones.ultima(uid);
      if (uid != uidSesion) return;
      if (ultima != null && _mensajes.isEmpty) {
        _conversacionId = ultima.id;
        _mensajes = [
          for (final m in ultima.mensajes)
            MensajeChat(
              id: _nuevoId(),
              esUsuaria: m.rol == 'user',
              contenido: m.contenido,
              fecha: m.fecha,
            ),
        ];
      }
      _historialCargado = true;
    } catch (e) {
      if (uid == uidSesion) _errorHistorial = FirebaseErrorMapper.mensaje(e);
    } finally {
      if (uid == uidSesion) {
        _cargandoHistorial = false;
        notificarSiActivo();
      }
    }
  }

  /// Envía [texto] al asistente. Devuelve el error (o `null` si salió bien).
  Future<String?> enviar(String texto) async {
    final contenido = texto.trim();
    if (contenido.isEmpty || !puedeEnviar) return null;
    if (contenido.length > largoMaximo) return AppStrings.errorMensajeLargo;
    final mensaje = MensajeChat(
      id: _nuevoId(),
      esUsuaria: true,
      contenido: contenido,
      fecha: DateTime.now(),
      estado: EstadoMensaje.enviando,
    );
    _mensajes = [..._mensajes, mensaje];
    return _procesar(mensaje);
  }

  /// Vuelve a enviar un mensaje que falló.
  Future<String?> reintentar(MensajeChat mensaje) async {
    if (!puedeEnviar || mensaje.estado != EstadoMensaje.error) return null;
    final pendiente = mensaje.conEstado(EstadoMensaje.enviando);
    _reemplazar(pendiente);
    return _procesar(pendiente);
  }

  Future<String?> _procesar(MensajeChat mensaje) async {
    final uid = uidSesion;
    if (uid == null) return AppStrings.errorSesionRequerida;
    _escribiendo = true;
    notificarSiActivo();

    // Historial: los mensajes ya respondidos antes de este (máx. 10).
    final previos = _mensajes
        .takeWhile((m) => m.id != mensaje.id)
        .where((m) => m.estado == EstadoMensaje.enviado)
        .toList();
    final historial = previos
        .skip(previos.length > historialMaximo ? previos.length - historialMaximo : 0)
        .map((m) => MensajeHistorial(esUsuaria: m.esUsuaria, contenido: m.contenido))
        .toList();

    try {
      final respuesta = await _funciones.chatAsistente(
        mensaje: mensaje.contenido,
        historial: historial,
        estacion: _perfil?.estacionColor,
        subtono: _perfil?.subtono,
      );
      if (uid != uidSesion) return null;
      final enviado = mensaje.conEstado(EstadoMensaje.enviado);
      final contestacion = MensajeChat(
        id: _nuevoId(),
        esUsuaria: false,
        contenido: respuesta.isEmpty ? AppStrings.asistenteSinRespuesta : respuesta,
        fecha: DateTime.now(),
      );
      _reemplazar(enviado);
      _mensajes = [..._mensajes, contestacion];
      _escribiendo = false;
      notificarSiActivo();
      await _guardar(uid, [enviado, contestacion]);
      return null;
    } catch (e) {
      if (uid != uidSesion) return null;
      final texto = e is AppException && e.codigo == CodigosFuncionesIa.noDesplegada
          ? AppStrings.asistenteNoDisponible
          : FirebaseErrorMapper.mensaje(e);
      _reemplazar(mensaje.conEstado(EstadoMensaje.error, error: texto));
      _escribiendo = false;
      notificarSiActivo();
      return texto;
    }
  }

  /// Guarda en Firestore (si falla, el chat sigue funcionando).
  Future<void> _guardar(String uid, List<MensajeChat> nuevos) async {
    try {
      final id = _conversacionId ??= await _conversaciones.crear(uid);
      await _conversaciones.agregarMensajes(
        uid,
        id,
        nuevos.map((m) => m.aModelo()).toList(),
      );
    } catch (_) {}
  }

  /// Empieza una conversación nueva (la anterior queda guardada).
  void nuevaConversacion() {
    if (_escribiendo) return;
    _conversacionId = null;
    _mensajes = [];
    notificarSiActivo();
  }

  void _reemplazar(MensajeChat mensaje) {
    _mensajes = [
      for (final m in _mensajes) m.id == mensaje.id ? mensaje : m,
    ];
  }

  String _nuevoId() => '${DateTime.now().microsecondsSinceEpoch}-${_contador++}';
}
