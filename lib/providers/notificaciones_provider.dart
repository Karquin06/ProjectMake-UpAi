import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/services/notificaciones_service.dart';
import 'limpieza_sesion.dart';
import 'usuaria_provider.dart';

/// Notificaciones push de la usuaria con sesión: al iniciar sesión pide
/// permiso, guarda el token FCM en `usuarias/{uid}` y reenvía los mensajes
/// en primer plano por [entrantes] (Home los muestra como aviso). Al
/// cerrar sesión deja de escuchar.
class NotificacionesProvider extends ChangeNotifier with LimpiezaPorSesion {
  final NotificacionesService _servicio;
  final UsuariaProvider _usuarias;

  final _entrantes = StreamController<NotificacionEntrante>.broadcast();
  StreamSubscription<String>? _subToken;
  StreamSubscription<NotificacionEntrante>? _subMensajes;
  bool _permisoConcedido = false;

  NotificacionesProvider({required this._servicio, required this._usuarias});

  bool get permisoConcedido => _permisoConcedido;

  /// Mensajes recibidos con la app abierta.
  Stream<NotificacionEntrante> get entrantes => _entrantes.stream;

  @override
  Future<void> alIniciarSesion(String uid) async {
    if (!_servicio.soportado) return;
    try {
      _permisoConcedido = await _servicio.solicitarPermiso();
      notificarSiActivo();
      if (!_permisoConcedido || uidSesion != uid) return;

      await _guardarToken(uid, await _servicio.obtenerToken());
      _subToken = _servicio.cambiosDeToken.listen(
        (token) => _guardarToken(uid, token),
      );
      _subMensajes = _servicio.mensajesEnPrimerPlano.listen(_entrantes.add);
    } catch (e) {
      // Las notificaciones no son críticas: la app sigue funcionando.
      debugPrint('NotificacionesProvider: $e');
    }
  }

  Future<void> _guardarToken(String uid, String? token) async {
    if (token == null || uidSesion != uid) return;
    try {
      await _usuarias.guardarTokenFcm(token, uid: uid);
    } catch (e) {
      debugPrint('No se pudo guardar el token FCM: $e');
    }
  }

  /// Antes de cerrar sesión: borra el token del documento (para no enviar
  /// notificaciones de esta cuenta al dispositivo) y lo invalida.
  Future<void> desregistrar() async {
    final uid = uidSesion;
    if (!_servicio.soportado || uid == null) return;
    try {
      await _usuarias.guardarTokenFcm(null, uid: uid);
      await _servicio.eliminarToken();
    } catch (e) {
      debugPrint('No se pudo desregistrar el token FCM: $e');
    }
  }

  @override
  void limpiar() {
    _subToken?.cancel();
    _subMensajes?.cancel();
    _subToken = null;
    _subMensajes = null;
    _permisoConcedido = false;
  }

  @override
  void dispose() {
    limpiar();
    _entrantes.close();
    super.dispose();
  }
}
