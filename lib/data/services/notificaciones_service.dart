import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Notificación recibida con la app abierta (primer plano).
class NotificacionEntrante {
  final String? titulo;
  final String? cuerpo;
  final Map<String, dynamic> datos;

  const NotificacionEntrante({this.titulo, this.cuerpo, this.datos = const {}});
}

/// Envuelve Firebase Cloud Messaging: permiso, token del dispositivo y
/// mensajes en primer plano. Es la ÚNICA clase que usa `FirebaseMessaging`.
///
/// Solo se usa en Android: en web FCM exige una clave VAPID y un service
/// worker que el proyecto aún no tiene, y iOS no está configurado.
class NotificacionesService {
  FirebaseMessaging? _instancia;

  FirebaseMessaging get _messaging =>
      _instancia ??= FirebaseMessaging.instance;

  /// `true` si las notificaciones push funcionan en esta plataforma.
  bool get soportado =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Pide permiso para mostrar notificaciones (Android 13+ muestra el
  /// diálogo del sistema). Devuelve `true` si fue concedido.
  Future<bool> solicitarPermiso() async {
    final ajustes = await _messaging.requestPermission();
    return ajustes.authorizationStatus == AuthorizationStatus.authorized ||
        ajustes.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Token FCM de este dispositivo.
  Future<String?> obtenerToken() => _messaging.getToken();

  /// Emite el nuevo token cuando Firebase lo renueva.
  Stream<String> get cambiosDeToken => _messaging.onTokenRefresh;

  /// Mensajes que llegan con la app abierta. (Con la app en segundo plano
  /// el sistema muestra la notificación por sí solo.)
  Stream<NotificacionEntrante> get mensajesEnPrimerPlano =>
      FirebaseMessaging.onMessage.map(
        (m) => NotificacionEntrante(
          titulo: m.notification?.title,
          cuerpo: m.notification?.body,
          datos: m.data,
        ),
      );

  /// Invalida el token de este dispositivo (al cerrar sesión).
  Future<void> eliminarToken() => _messaging.deleteToken();
}
