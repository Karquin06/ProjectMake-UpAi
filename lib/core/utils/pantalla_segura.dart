import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Activa `FLAG_SECURE` en Android mientras se muestra una pantalla con el
/// rostro de la usuaria (selfie, simulador AR, capturas): el sistema bloquea
/// capturas y grabaciones de pantalla y oculta la vista previa en "apps
/// recientes" (fugas de datos, OWASP M6/M9).
///
/// Lleva la cuenta de pantallas protegidas abiertas: si se apilan dos, cerrar
/// la de arriba no desprotege la de abajo. En web, iOS o tests sin el canal
/// nativo no hace nada.
class PantallaSegura {
  PantallaSegura._();

  static const canal = MethodChannel('mackeupai/pantalla_segura');
  static int _activas = 0;

  static Future<void> activar() async {
    _activas++;
    if (_activas == 1) await _invocar('activar');
  }

  static Future<void> desactivar() async {
    if (_activas == 0) return;
    _activas--;
    if (_activas == 0) await _invocar('desactivar');
  }

  @visibleForTesting
  static int get activas => _activas;

  @visibleForTesting
  static void reiniciar() => _activas = 0;

  static Future<void> _invocar(String metodo) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await canal.invokeMethod<void>(metodo);
    } on MissingPluginException {
      // Sin el canal nativo (tests de widgets, otras plataformas).
    } on PlatformException {
      // No crítico: la pantalla funciona igual sin la protección.
    }
  }
}
