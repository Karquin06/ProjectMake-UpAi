import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/routes/app_routes.dart';
import 'package:mackeupai/data/repositories/auth_repository.dart';
import 'package:mackeupai/data/repositories/credencial_repository.dart';
import 'package:mackeupai/data/repositories/sesion_repository.dart';
import 'package:mackeupai/data/repositories/usuaria_repository.dart';
import 'package:mackeupai/models/usuaria.dart';
import 'package:mackeupai/providers/auth_provider.dart';
import 'package:mackeupai/providers/sesion_provider.dart';
import 'package:mackeupai/providers/usuaria_provider.dart';
import 'package:mackeupai/ui/splash/splash_view_model.dart';

class _UsuarioFalso extends Fake implements User {
  @override
  final String uid = 'u1';
  @override
  final bool emailVerified;
  _UsuarioFalso({required this.emailVerified});
  @override
  String? get email => 'sofia@ejemplo.com';
  @override
  String? get displayName => null;
  @override
  String? get photoURL => null;
}

class _AuthRepoFalso extends Fake implements AuthRepository {
  User? usuario;
  bool cerroSesion = false;
  final _cambios = StreamController<User?>.broadcast();
  @override
  User? get usuarioActual => usuario;
  @override
  Stream<User?> get cambiosDeSesion => _cambios.stream;
  @override
  Future<void> cerrarSesion() async {
    cerroSesion = true;
    usuario = null;
  }
}

class _UsuariaRepoFalso extends Fake implements UsuariaRepository {
  bool existe = true;
  bool sinConexion = false;
  @override
  Stream<Usuaria?> escucharUsuaria(String uid) => const Stream.empty();
  @override
  Future<bool> existeUsuaria(String uid) async {
    if (sinConexion) throw Exception('sin conexión');
    return existe;
  }
}

class _PreferenciasFalsas extends Fake implements SesionRepository {
  bool visto = false;
  @override
  Future<bool> onboardingVisto() async => visto;
}

void main() {
  late _AuthRepoFalso authRepo;
  late _UsuariaRepoFalso usuariaRepo;
  late _PreferenciasFalsas preferencias;

  setUp(() {
    authRepo = _AuthRepoFalso();
    usuariaRepo = _UsuariaRepoFalso();
    preferencias = _PreferenciasFalsas();
  });

  SesionProvider sesion() {
    final auth = AuthProvider(authRepo);
    // Simula que Firebase ya respondió.
    authRepo._cambios.add(authRepo.usuario);
    return SesionProvider(
      auth: auth,
      usuaria: UsuariaProvider(
        usuariaRepository: usuariaRepo,
        authRepository: authRepo,
      ),
      preferencias: preferencias,
      credenciales: CredencialRepository(),
    );
  }

  Future<String?> decidir() async {
    final s = sesion();
    await Future<void>.delayed(Duration.zero);
    return SplashViewModel().decidir(s);
  }

  test('sin sesión y primera vez → onboarding', () async {
    final vm = SplashViewModel();
    final s = sesion();
    await Future<void>.delayed(Duration.zero);
    expect(await vm.decidir(s), isNull);
    expect(vm.mostrarOnboarding, isTrue);
  });

  test('sin sesión y onboarding visto → login', () async {
    preferencias.visto = true;
    expect(await decidir(), AppRoutes.login);
  });

  test('correo sin verificar → verificar_correo', () async {
    authRepo.usuario = _UsuarioFalso(emailVerified: false);
    expect(await decidir(), AppRoutes.verificarCorreo);
  });

  test('verificada con documento → home', () async {
    authRepo.usuario = _UsuarioFalso(emailVerified: true);
    expect(await decidir(), AppRoutes.home);
  });

  test('verificada SIN documento → cierra sesión y va a login', () async {
    authRepo.usuario = _UsuarioFalso(emailVerified: true);
    usuariaRepo.existe = false;
    expect(await decidir(), AppRoutes.login);
    expect(authRepo.cerroSesion, isTrue);
  });

  test('sin conexión no cierra la sesión', () async {
    authRepo.usuario = _UsuarioFalso(emailVerified: true);
    usuariaRepo.sinConexion = true;
    expect(await decidir(), AppRoutes.home);
    expect(authRepo.cerroSesion, isFalse);
  });
}
