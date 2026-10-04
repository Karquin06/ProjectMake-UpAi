import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// "Recordarme": guarda SOLO el correo de la usuaria en almacenamiento
/// seguro para precargarlo en el login.
///
/// NUNCA guarda contraseñas: la sesión la mantiene Firebase Authentication
/// y la contraseña solo existe mientras la usuaria la escribe.
class CredencialRepository {
  static const _claveCorreo = 'credencial.correoRecordado';

  final FlutterSecureStorage _almacen;

  CredencialRepository({FlutterSecureStorage? almacen})
    : _almacen = almacen ?? const FlutterSecureStorage();

  Future<String?> correoRecordado() async {
    try {
      return await _almacen.read(key: _claveCorreo);
    } catch (_) {
      return null;
    }
  }

  Future<void> recordarCorreo(String correo) async {
    try {
      await _almacen.write(key: _claveCorreo, value: correo.trim());
    } catch (_) {
      // No crítico: la usuaria escribirá su correo la próxima vez.
    }
  }

  Future<void> olvidarCorreo() async {
    try {
      await _almacen.delete(key: _claveCorreo);
    } catch (_) {
      // No crítico.
    }
  }
}
