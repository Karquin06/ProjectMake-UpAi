import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Preferencias de sesión guardadas en el dispositivo (almacenamiento
/// seguro). Son datos no críticos: si el almacenamiento falla se usan los
/// valores por defecto en lugar de romper el flujo.
class SesionRepository {
  static const _claveOnboardingVisto = 'sesion.onboardingVisto';

  final FlutterSecureStorage _almacen;

  SesionRepository({FlutterSecureStorage? almacen})
    : _almacen = almacen ?? const FlutterSecureStorage();

  /// `true` si la usuaria ya vio el onboarding en este dispositivo.
  Future<bool> onboardingVisto() async {
    try {
      return await _almacen.read(key: _claveOnboardingVisto) == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> marcarOnboardingVisto() async {
    try {
      await _almacen.write(key: _claveOnboardingVisto, value: 'true');
    } catch (_) {
      // No crítico: el onboarding se volverá a mostrar.
    }
  }
}
