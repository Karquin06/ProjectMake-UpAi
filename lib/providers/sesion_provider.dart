import '../models/usuaria.dart';
import 'auth_provider.dart';
import 'usuaria_provider.dart';

/// Vista unificada de la sesión: sesión activa, usuaria actual y rol.
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

  const SesionProvider({required this._auth, required this._usuaria});

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
}
