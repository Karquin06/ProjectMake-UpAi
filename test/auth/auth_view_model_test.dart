import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/core/routes/app_routes.dart';
import 'package:mackeupai/data/repositories/auth_repository.dart';
import 'package:mackeupai/data/repositories/credencial_repository.dart';
import 'package:mackeupai/data/repositories/sesion_repository.dart';
import 'package:mackeupai/data/repositories/usuaria_repository.dart';
import 'package:mackeupai/models/usuaria.dart';
import 'package:mackeupai/providers/auth_provider.dart';
import 'package:mackeupai/providers/sesion_provider.dart';
import 'package:mackeupai/providers/usuaria_provider.dart';
import 'package:mackeupai/ui/auth/auth_view_model.dart';

class _UsuarioFalso extends Fake implements User {
  @override
  final String uid = 'u1';
  @override
  bool emailVerified;

  _UsuarioFalso({this.emailVerified = false});

  @override
  String? get email => 'sofia@ejemplo.com';
  @override
  String? get displayName => 'Sofía';
  @override
  String? get photoURL => null;
}

class _CredencialFalsa extends Fake implements UserCredential {
  @override
  final User user;
  _CredencialFalsa(this.user);
}

class _AuthRepoFalso extends Fake implements AuthRepository {
  User? usuario;
  final llamadas = <String>[];
  final _cambios = StreamController<User?>.broadcast();
  bool googleEsNueva = false;

  @override
  User? get usuarioActual => usuario;
  @override
  Stream<User?> get cambiosDeSesion => _cambios.stream;

  @override
  Future<UserCredential> crearCuentaConCorreo({
    required String correo,
    required String contrasena,
  }) async {
    llamadas.add('crearCuenta');
    usuario = _UsuarioFalso();
    return _CredencialFalsa(usuario!);
  }

  @override
  Future<UserCredential> iniciarSesionConCorreo({
    required String correo,
    required String contrasena,
  }) async {
    llamadas.add('iniciarSesion');
    usuario = _UsuarioFalso(emailVerified: false);
    return _CredencialFalsa(usuario!);
  }

  @override
  Future<UserCredential?> iniciarSesionConGoogle() async {
    llamadas.add('google');
    usuario = _UsuarioFalso(emailVerified: true);
    return _CredencialFalsa(usuario!);
  }

  @override
  Future<void> actualizarNombre(String nombre) async =>
      llamadas.add('actualizarNombre');
  @override
  Future<void> reenviarVerificacion() async => llamadas.add('verificacion');
  @override
  Future<void> eliminarCuentaAuth() async {
    llamadas.add('eliminarCuentaAuth');
    usuario = null;
  }

  @override
  Future<void> cerrarSesion() async {
    llamadas.add('cerrarSesion');
    usuario = null;
  }
}

class _UsuariaRepoFalso extends Fake implements UsuariaRepository {
  bool falla = false;
  bool existe = false;
  final creadas = <String>[];
  String? versionGuardada;

  @override
  Stream<Usuaria?> escucharUsuaria(String uid) => const Stream.empty();
  @override
  Future<bool> existeUsuaria(String uid) async => existe;

  @override
  Future<bool> crearUsuaria({
    required String uid,
    required String nombre,
    required String email,
    required String versionConsentimiento,
    String? fotoPerfilURL,
  }) async {
    if (falla) throw Exception('Firestore caído');
    creadas.add(uid);
    versionGuardada = versionConsentimiento;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _AuthRepoFalso authRepo;
  late _UsuariaRepoFalso usuariaRepo;
  late AuthViewModel vm;

  setUp(() {
    authRepo = _AuthRepoFalso();
    usuariaRepo = _UsuariaRepoFalso();
    final auth = AuthProvider(authRepo);
    final usuarias = UsuariaProvider(
      usuariaRepository: usuariaRepo,
      authRepository: authRepo,
    );
    vm = AuthViewModel(
      auth: auth,
      usuarias: usuarias,
      sesion: SesionProvider(
        auth: auth,
        usuaria: usuarias,
        preferencias: SesionRepository(),
        credenciales: CredencialRepository(),
      ),
    );
  });

  Future<bool> registrar() => vm.crearCuenta(
    nombre: 'Sofía Martínez',
    correo: 'sofia@ejemplo.com',
    contrasena: 'secreta1',
  );

  group('registro', () {
    test('sin aceptar el aviso no se crea nada', () async {
      expect(await registrar(), isFalse);
      expect(vm.error, AppStrings.errorConsentimientoRequerido);
      expect(authRepo.llamadas, isEmpty);
      expect(usuariaRepo.creadas, isEmpty);
    });

    test(
      'con aviso aceptado crea Auth, documento y envía verificación',
      () async {
        vm.cambiarConsentimiento(true);
        expect(await registrar(), isTrue);
        expect(authRepo.llamadas, [
          'crearCuenta',
          'actualizarNombre',
          'verificacion',
        ]);
        expect(usuariaRepo.creadas, ['u1']);
        expect(usuariaRepo.versionGuardada, isNotEmpty);
        // Correo sin verificar: no entra a Home.
        expect(vm.rutaTrasIngresar, AppRoutes.verificarCorreo);
      },
    );

    test('si falla Firestore se elimina la cuenta de Auth', () async {
      usuariaRepo.falla = true;
      vm.cambiarConsentimiento(true);
      expect(await registrar(), isFalse);
      expect(authRepo.llamadas, contains('eliminarCuentaAuth'));
      expect(authRepo.llamadas, isNot(contains('verificacion')));
      expect(vm.error, isNotNull);
    });
  });

  test('login con correo sin verificar va a verificar_correo', () async {
    final ok = await vm.iniciarSesionConCorreo(
      correo: 'sofia@ejemplo.com',
      contrasena: 'secreta1',
    );
    expect(ok, isTrue);
    expect(vm.rutaTrasIngresar, AppRoutes.verificarCorreo);
  });

  group('Google', () {
    test('primera vez pide consentimiento y no crea documento', () async {
      expect(
        await vm.continuarConGoogle(),
        ResultadoGoogle.requiereConsentimiento,
      );
      expect(usuariaRepo.creadas, isEmpty);
    });

    test('al aceptar crea el documento y entra a Home', () async {
      await vm.continuarConGoogle();
      expect(await vm.completarRegistroGoogle(), isTrue);
      expect(usuariaRepo.creadas, ['u1']);
      expect(vm.rutaTrasIngresar, AppRoutes.home);
    });

    test('al rechazar elimina la cuenta y cierra sesión', () async {
      await vm.continuarConGoogle();
      await vm.cancelarRegistroGoogle();
      expect(
        authRepo.llamadas,
        containsAll(['eliminarCuentaAuth', 'cerrarSesion']),
      );
      expect(usuariaRepo.creadas, isEmpty);
      expect(vm.error, AppStrings.errorConsentimientoGoogle);
    });

    test('cuenta existente entra directo', () async {
      usuariaRepo.existe = true;
      expect(await vm.continuarConGoogle(), ResultadoGoogle.exito);
    });
  });
}
