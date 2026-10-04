import '../data/repositories/credencial_repository.dart';
import '../data/repositories/sesion_repository.dart';
import '../models/usuaria.dart';
import 'auth_provider.dart';
import 'usuaria_provider.dart';

/// Vista unificada de la sesión: sesión activa, usuaria actual, rol y
/// preferencias de sesión del dispositivo.
///
/// Se recrea automáticamente cada vez que cambian [AuthProvider] o
/// [UsuariaProvider] (ver `ProxyProvider2` en `app_providers.dart`), por eso
/// es inmutable. Es lo que deben leer las pantallas y el router:
///
/// ```dart
/// final sesion = context.watch<SesionProvider>();
/// Text('Hola, ${sesion.nombreVisible}');
/// if (sesion.esAdmin) ...
/// ```
class SesionProvider {
  final AuthProvider _auth;
  final UsuariaProvider _usuaria;
  final SesionRepository _preferencias;
  final CredencialRepository _credenciales;

  const SesionProvider({
    required this._auth,
    required this._usuaria,
    required this._preferencias,
    required this._credenciales,
  });

  EstadoAuth get estado => _auth.estado;

  /// `true` mientras Firebase no confirma si hay sesión.
  bool get cargando => _auth.estado == EstadoAuth.desconocido;

  bool get haySesion => _auth.haySesion;
  bool get correoVerificado => _auth.correoVerificado;

  /// Sesión iniciada y correo verificado.
  bool get sesionActiva => _auth.estado == EstadoAuth.autenticada;

  String? get uid => _auth.uid;
  String? get correo => _usuaria.usuaria?.email ?? _auth.correo;

  /// Documento de Firestore de la usuaria (puede tardar en llegar).
  Usuaria? get usuaria => _usuaria.usuaria;
  bool get cargandoUsuaria => _usuaria.cargando;
  String? get errorUsuaria => _usuaria.error;

  String get rol => _usuaria.rol;
  bool get esAdmin => _usuaria.esAdmin;

  /// Nombre para saludos: el de Firestore, el de Auth o la parte local
  /// del correo, en ese orden. Vacío si no hay ninguno.
  String get nombreVisible {
    final candidatos = [_usuaria.usuaria?.nombre, _auth.nombreVisible];
    for (final nombre in candidatos) {
      if (nombre != null && nombre.trim().isNotEmpty) return nombre.trim();
    }
    final correo = this.correo;
    if (correo != null && correo.contains('@')) return correo.split('@').first;
    return '';
  }

  String? get fotoUrl => _usuaria.usuaria?.fotoPerfilUrl ?? _auth.fotoUrl;

  /// `true` si existe `usuarias/{uid}` en el servidor. Lanza error sin
  /// conexión.
  Future<bool> documentoExiste() async {
    final uid = _auth.uid;
    return uid != null && await _usuaria.existeUsuaria(uid);
  }

  /// Cierra la sesión; todos los providers de sesión se limpian solos.
  Future<void> cerrarSesion() => _auth.cerrarSesion();

  // ---------------------------------------------------------------------
  // Preferencias de sesión del dispositivo
  // ---------------------------------------------------------------------

  Future<bool> onboardingVisto() => _preferencias.onboardingVisto();
  Future<void> marcarOnboardingVisto() => _preferencias.marcarOnboardingVisto();

  /// "Recordarme": solo el correo, nunca la contraseña.
  Future<String?> correoRecordado() => _credenciales.correoRecordado();
  Future<void> recordarCorreo(String correo) =>
      _credenciales.recordarCorreo(correo);
  Future<void> olvidarCorreo() => _credenciales.olvidarCorreo();
}
