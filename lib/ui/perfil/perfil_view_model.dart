import 'package:flutter/foundation.dart';
import '../../core/constants/app_strings.dart';
import '../../core/errors/app_exception.dart';
import '../../core/errors/firebase_error_mapper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notificaciones_provider.dart';
import '../../providers/sesion_provider.dart';
import '../../providers/usuaria_provider.dart';

/// Datos y acciones de la pantalla de perfil.
class PerfilViewModel extends ChangeNotifier {
  final NotificacionesProvider _notificaciones;
  final AuthProvider _auth;
  final UsuariaProvider _usuarias;
  SesionProvider? _sesion;
  bool _desechado = false;
  bool _cerrandoSesion = false;
  bool _eliminandoCuenta = false;
  String? _error;

  PerfilViewModel({
    required this._notificaciones,
    required this._auth,
    required this._usuarias,
  });

  String get nombre => _sesion?.nombreVisible ?? '';
  String get correo => _sesion?.correo ?? '';
  String? get fotoUrl => _sesion?.fotoUrl;
  bool get cerrandoSesion => _cerrandoSesion;
  bool get eliminandoCuenta => _eliminandoCuenta;

  /// `true` si la cuenta usa contraseña (se pide para reautenticar); si
  /// no, se reautentica con Google.
  bool get reautenticaConContrasena => _auth.tieneProveedorContrasena;
  String? get error => _error;

  /// Cargando la primera vez (aún no hay ni nombre ni documento).
  bool get cargando =>
      (_sesion?.cargandoUsuaria ?? true) &&
      _sesion?.usuaria == null &&
      nombre.isEmpty;

  /// Error al leer `usuarias/{uid}` (con reintento).
  String? get errorUsuaria => _sesion?.errorUsuaria;

  /// Se llama cada vez que cambia la sesión (ver `PerfilView`).
  void actualizarSesion(SesionProvider sesion) {
    _sesion = sesion;
    // Diferido: se llama desde `update`, durante el build.
    Future.microtask(_notificar);
  }

  void reintentar() => _sesion?.reintentarUsuaria();

  /// Cierra la sesión: primero desregistra las notificaciones de este
  /// dispositivo y luego sale de Firebase. Todos los providers con datos de
  /// la usuaria se limpian solos al detectar el cambio de sesión.
  Future<bool> cerrarSesion() async {
    final sesion = _sesion;
    if (sesion == null || _cerrandoSesion) return false;
    _cerrandoSesion = true;
    _error = null;
    _notificar();
    try {
      await _notificaciones.desregistrar();
      await sesion.cerrarSesion();
      return true;
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
      return false;
    } finally {
      _cerrandoSesion = false;
      _notificar();
    }
  }

  /// Elimina la cuenta: reautentica (con [contrasena] o con Google),
  /// desregistra las notificaciones, llama a `eliminarCuenta`, olvida el
  /// correo de "Recordarme" y cierra la sesión. Devuelve `true` si se
  /// eliminó; `false` si falló o la usuaria canceló el selector de Google.
  Future<bool> eliminarCuenta({String? contrasena}) async {
    final sesion = _sesion;
    if (sesion == null || _eliminandoCuenta) return false;
    _eliminandoCuenta = true;
    _error = null;
    _notificar();
    try {
      if (contrasena != null) {
        await _auth.reautenticarConContrasena(contrasena);
      } else if (!await _auth.reautenticarConGoogle()) {
        return false; // Cerró el selector de Google.
      }
      await _notificaciones.desregistrar();
      await _usuarias.eliminarCuenta();
      await sesion.olvidarCorreo();
      await sesion.cerrarSesion();
      return true;
    } catch (e) {
      final excepcion = AppException.desde(e);
      _error =
          (excepcion.codigo == 'wrong-password' ||
              excepcion.codigo == 'invalid-credential')
          ? AppStrings.errorContrasenaIncorrecta
          : excepcion.mensaje;
      return false;
    } finally {
      _eliminandoCuenta = false;
      _notificar();
    }
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
