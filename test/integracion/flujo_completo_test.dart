// Prueba de integración de punta a punta del módulo de Karlos.
//
// Arranca la app REAL (MakeUpAiApp: router, guardias, providers y vistas)
// reemplazando solo Firebase por repositorios en memoria. Recorre:
// onboarding → registro (consentimiento) → verificar correo → Home →
// editar perfil → cerrar sesión → login → eliminar cuenta.
import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart' show User, UserCredential;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/app.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/data/repositories/auth_repository.dart';
import 'package:mackeupai/data/repositories/credencial_repository.dart';
import 'package:mackeupai/data/repositories/sesion_repository.dart';
import 'package:mackeupai/data/repositories/usuaria_repository.dart';
import 'package:mackeupai/data/services/eliminador_cuenta.dart';
import 'package:mackeupai/data/services/notificaciones_service.dart';
import 'package:mackeupai/data/services/subidor_foto_perfil.dart';
import 'package:mackeupai/models/usuaria.dart';
import 'package:mackeupai/ui/perfil/widgets/boton_eliminar_cuenta.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------------------
// "Firebase" en memoria
// ---------------------------------------------------------------------------

class _Usuario extends Fake implements User {
  @override
  final String uid;
  @override
  final String email;
  String? nombre;
  bool verificado = false;

  _Usuario(this.uid, this.email);

  @override
  String? get displayName => nombre;
  @override
  bool get emailVerified => verificado;
  @override
  String? get photoURL => null;
}

class _Credencial extends Fake implements UserCredential {
  @override
  final User user;
  _Credencial(this.user);
}

class _AuthEnMemoria extends Fake implements AuthRepository {
  final cuentas = <String, (_Usuario, String)>{}; // correo → (usuario, clave)
  _Usuario? actual;
  final _cambios = StreamController<User?>.broadcast();
  int _siguienteUid = 1;

  /// Simula que la usuaria abrió el enlace de verificación del correo.
  void verificarCorreo(String correo) => cuentas[correo]!.$1.verificado = true;

  void _emitir() => _cambios.add(actual);

  @override
  User? get usuarioActual => actual;
  @override
  Stream<User?> get cambiosDeSesion => _cambios.stream;
  @override
  bool get tieneProveedorContrasena => actual != null;
  @override
  bool get tieneProveedorGoogle => false;
  @override
  Duration get esperaReenvioRestante => Duration.zero;

  @override
  Future<UserCredential> crearCuentaConCorreo({
    required String correo,
    required String contrasena,
  }) async {
    final usuario = _Usuario('uid-${_siguienteUid++}', correo.trim());
    cuentas[usuario.email] = (usuario, contrasena);
    actual = usuario;
    _emitir();
    return _Credencial(usuario);
  }

  @override
  Future<UserCredential> iniciarSesionConCorreo({
    required String correo,
    required String contrasena,
  }) async {
    final cuenta = cuentas[correo.trim()];
    if (cuenta == null || cuenta.$2 != contrasena) {
      throw Exception('invalid-credential');
    }
    actual = cuenta.$1;
    _emitir();
    return _Credencial(cuenta.$1);
  }

  @override
  Future<void> actualizarNombre(String nombre) async => actual?.nombre = nombre;
  @override
  Future<void> reenviarVerificacion() async {}
  @override
  Future<void> recargarUsuaria() async {}

  @override
  Future<void> reautenticarConContrasena(String contrasena) async {
    if (cuentas[actual!.email]!.$2 != contrasena) {
      throw FakeAuthError('wrong-password');
    }
  }

  @override
  Future<void> eliminarCuentaAuth() async {
    cuentas.remove(actual?.email);
    actual = null;
    _emitir();
  }

  @override
  Future<void> cerrarSesion() async {
    actual = null;
    _emitir();
  }
}

/// Error con `code` como el de Firebase para probar el mensaje traducido.
class FakeAuthError extends Fake implements Exception {
  final String code;
  FakeAuthError(this.code);
}

class _FirestoreEnMemoria extends Fake implements UsuariaRepository {
  final docs = <String, Usuaria>{};
  final _cambios = StreamController<String>.broadcast();

  @override
  Future<bool> existeUsuaria(String uid) async => docs.containsKey(uid);

  @override
  Future<bool> crearUsuaria({
    required String uid,
    required String nombre,
    required String email,
    required String versionConsentimiento,
    String? fotoPerfilURL,
  }) async {
    docs[uid] = Usuaria(
      uid: uid,
      nombre: nombre,
      email: email,
      fechaRegistro: DateTime.now(),
      consentimientos: {
        Consentimiento.avisoPrivacidad: Consentimiento(
          version: versionConsentimiento,
          fecha: DateTime.now(),
        ),
      },
    );
    _cambios.add(uid);
    return true;
  }

  @override
  Stream<Usuaria?> escucharUsuaria(String uid) async* {
    yield docs[uid];
    yield* _cambios.stream.where((u) => u == uid).map((_) => docs[uid]);
  }

  @override
  Future<void> actualizarUsuaria(
    String uid, {
    String? nombre,
    String? fotoPerfilUrl,
  }) async {
    docs[uid] = docs[uid]!.copyWith(nombre: nombre);
    _cambios.add(uid);
  }

  @override
  Future<void> guardarTokenFcm(String uid, String? token) async {}
}

class _PreferenciasEnMemoria extends Fake implements SesionRepository {
  bool visto = false;
  @override
  Future<bool> onboardingVisto() async => visto;
  @override
  Future<void> marcarOnboardingVisto() async => visto = true;
}

class _CredencialesEnMemoria extends Fake implements CredencialRepository {
  String? correo;
  @override
  Future<String?> correoRecordado() async => correo;
  @override
  Future<void> recordarCorreo(String c) async => correo = c;
  @override
  Future<void> olvidarCorreo() async => correo = null;
}

class _SinNotificaciones extends Fake implements NotificacionesService {
  @override
  bool get soportado => false;
}

class _SubidorNulo implements SubidorFotoPerfil {
  @override
  Future<String?> subirFotoPerfil({
    required String uid,
    required Uint8List jpeg,
  }) async => null;
}

// ---------------------------------------------------------------------------

void main() {
  testWidgets('flujo completo: registro → verificación → Home → perfil → '
      'cerrar sesión → login → eliminar cuenta', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = _AuthEnMemoria();
    final firestore = _FirestoreEnMemoria();
    final credenciales = _CredencialesEnMemoria();

    await tester.pumpWidget(
      MakeUpAiApp(
        dependencias: [
          Provider<AuthRepository>.value(value: auth),
          Provider<UsuariaRepository>.value(value: firestore),
          Provider<SesionRepository>.value(value: _PreferenciasEnMemoria()),
          Provider<CredencialRepository>.value(value: credenciales),
          Provider<NotificacionesService>.value(value: _SinNotificaciones()),
          Provider<SubidorFotoPerfil>.value(value: _SubidorNulo()),
          Provider<EliminadorCuenta>.value(value: EliminadorCuentaMock(auth)),
        ],
      ),
    );
    auth._emitir(); // Firebase responde: no hay sesión.

    Future<void> esperar() async {
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    Future<void> tocar(Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await esperar();
    }

    // 1. Splash (1,8 s) → onboarding → login.
    await tester.pump(const Duration(seconds: 2));
    await esperar();
    expect(find.text(AppStrings.botonComenzar), findsOneWidget);
    await tocar(find.text(AppStrings.botonComenzar));
    expect(find.text(AppStrings.bienvenida), findsOneWidget);

    // 2. Registro: sin aceptar el aviso el botón no hace nada.
    await tocar(find.textContaining(AppStrings.registrate, findRichText: true));
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Sofía Martínez');
    await tester.enterText(campos.at(1), 'sofia@ejemplo.com');
    await tester.enterText(campos.at(2), 'secreta1');
    await tester.enterText(campos.at(3), 'secreta1');
    await tocar(find.text(AppStrings.botonCrearCuentaGratis));
    expect(auth.cuentas, isEmpty, reason: 'sin consentimiento no hay cuenta');

    //    Abre el aviso, lo acepta y crea la cuenta.
    await tocar(find.text(AppStrings.consentimientoEnlace));
    expect(find.text(AppStrings.avisoPrivacidadTitulo), findsOneWidget);
    await tocar(find.text(AppStrings.botonAcepto));
    await tocar(find.text(AppStrings.botonCrearCuentaGratis));
    expect(auth.cuentas, hasLength(1));
    final uid = auth.actual!.uid;
    expect(firestore.docs[uid]!.rol, Usuaria.rolUsuaria);
    expect(firestore.docs[uid]!.consentimientoPrivacidad, isNotNull);

    // 3. Sin verificar el correo no se entra a Home.
    expect(find.text(AppStrings.verificarCorreoTitulo), findsOneWidget);
    await tocar(find.text(AppStrings.yaVerifique));
    expect(find.text(AppStrings.verificarCorreoTitulo), findsOneWidget);
    expect(find.text(AppStrings.correoAunNoVerificado), findsOneWidget);

    //    Verifica el correo → Home con nombre, estación y recomendaciones.
    auth.verificarCorreo('sofia@ejemplo.com');
    await tocar(find.text(AppStrings.yaVerifique));
    await tester.pump(const Duration(seconds: 1));
    await esperar();
    expect(find.text(AppStrings.saludo('Sofía')), findsOneWidget);
    expect(find.text(AppStrings.tuEstacionDeColor), findsOneWidget);
    expect(find.text('Labial rojo frambuesa'), findsOneWidget);

    // 4. Perfil → editar nombre.
    await tocar(find.text(AppStrings.perfilTab));
    expect(find.text('Sofía Martínez'), findsWidgets);
    await tocar(find.text(AppStrings.editarPerfil));
    await tester.enterText(find.byType(TextFormField).first, 'Sofía López');
    await esperar();
    await tocar(find.text(AppStrings.guardarCambios));
    expect(firestore.docs[uid]!.nombre, 'Sofía López');
    expect(find.text('Sofía López'), findsWidgets);

    // 5. Cerrar sesión → login (todos los datos se limpian).
    await tocar(find.text(AppStrings.cerrarSesion).first);
    await tocar(find.text(AppStrings.cerrarSesion).last); // confirmar
    expect(find.text(AppStrings.bienvenida), findsOneWidget);
    expect(auth.actual, isNull);

    // 6. Login de nuevo → Home directo (correo ya verificado).
    final camposLogin = find.byType(TextFormField);
    await tester.enterText(camposLogin.at(0), 'sofia@ejemplo.com');
    await tester.enterText(camposLogin.at(1), 'secreta1');
    await tocar(find.text(AppStrings.botonIniciarSesion));
    await tester.pump(const Duration(seconds: 1));
    await esperar();
    expect(find.text(AppStrings.saludo('Sofía')), findsOneWidget);

    // 7. Eliminar cuenta: contraseña incorrecta → error; correcta → login.
    await tocar(find.text(AppStrings.perfilTab));
    await tocar(find.byType(BotonEliminarCuenta));
    await tocar(find.text(AppStrings.eliminar)); // confirmar
    await tester.enterText(find.byType(TextFormField).last, 'equivocada');
    await tocar(find.text(AppStrings.eliminar)); // diálogo de contraseña
    expect(auth.cuentas, hasLength(1));

    await tocar(find.byType(BotonEliminarCuenta));
    await tocar(find.text(AppStrings.eliminar));
    await tester.enterText(find.byType(TextFormField).last, 'secreta1');
    await tocar(find.text(AppStrings.eliminar));
    expect(auth.cuentas, isEmpty);
    expect(auth.actual, isNull);
    expect(find.text(AppStrings.bienvenida), findsOneWidget);
    expect(find.text(AppStrings.cuentaEliminada), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
