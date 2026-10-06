import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/core/routes/app_router.dart';
import 'package:mackeupai/core/routes/app_routes.dart';
import 'package:mackeupai/core/routes/guardia_ruta.dart';
import 'package:mackeupai/data/repositories/auth_repository.dart';
import 'package:mackeupai/data/repositories/credencial_repository.dart';
import 'package:mackeupai/data/repositories/sesion_repository.dart';
import 'package:mackeupai/data/repositories/usuaria_repository.dart';
import 'package:mackeupai/models/usuaria.dart';
import 'package:mackeupai/providers/auth_provider.dart';
import 'package:mackeupai/providers/sesion_provider.dart';
import 'package:mackeupai/providers/usuaria_provider.dart';
import 'package:provider/provider.dart';

class _UsuarioFalso extends Fake implements User {
  @override
  final String uid;
  @override
  final bool emailVerified;

  _UsuarioFalso({this.emailVerified = true}) : uid = 'u1';

  @override
  String? get email => 'sofia@ejemplo.com';
  @override
  String? get displayName => null;
  @override
  String? get photoURL => null;
}

class _AuthRepoFalso extends Fake implements AuthRepository {
  User? usuario;
  final _cambios = StreamController<User?>.broadcast();

  @override
  User? get usuarioActual => usuario;
  @override
  Stream<User?> get cambiosDeSesion => _cambios.stream;
  @override
  Duration get esperaReenvioRestante => Duration.zero;

  void emitir(User? nuevo) {
    usuario = nuevo;
    _cambios.add(nuevo);
  }
}

class _UsuariaRepoFalso extends Fake implements UsuariaRepository {
  String rol = Usuaria.rolUsuaria;

  @override
  Stream<Usuaria?> escucharUsuaria(String uid) => Stream.value(
    Usuaria(
      uid: uid,
      nombre: 'Sofía',
      email: 'sofia@ejemplo.com',
      fechaRegistro: DateTime(2026),
      rol: rol,
    ),
  );
}

void main() {
  late _AuthRepoFalso authRepo;
  late _UsuariaRepoFalso usuariaRepo;

  setUp(() {
    authRepo = _AuthRepoFalso();
    usuariaRepo = _UsuariaRepoFalso();
  });

  Future<SesionProvider> sesionCon(User? usuario) async {
    authRepo.emitir(usuario);
    final auth = AuthProvider(authRepo);
    final usuarias = UsuariaProvider(
      usuariaRepository: usuariaRepo,
      authRepository: authRepo,
    );
    authRepo.emitir(usuario); // primer evento: Firebase ya respondió
    await Future<void>.delayed(Duration.zero); // llega el documento
    return SesionProvider(
      auth: auth,
      usuaria: usuarias,
      preferencias: SesionRepository(),
      credenciales: CredencialRepository(),
    );
  }

  group('GuardiaRuta.destinoPara', () {
    test(
      'sin sesión → login (rutas privadas); públicas siempre permitidas',
      () async {
        final s = await sesionCon(null);
        expect(GuardiaRuta.destinoPara(NivelAcceso.publica, s), isNull);
        expect(
          GuardiaRuta.destinoPara(NivelAcceso.autenticada, s),
          AppRoutes.login,
        );
        expect(GuardiaRuta.destinoPara(NivelAcceso.admin, s), AppRoutes.login);
        expect(
          GuardiaRuta.destinoPara(NivelAcceso.verificacionPendiente, s),
          AppRoutes.login,
        );
      },
    );

    test('correo sin verificar → verificar_correo', () async {
      final s = await sesionCon(_UsuarioFalso(emailVerified: false));
      expect(
        GuardiaRuta.destinoPara(NivelAcceso.autenticada, s),
        AppRoutes.verificarCorreo,
      );
      expect(
        GuardiaRuta.destinoPara(NivelAcceso.admin, s),
        AppRoutes.verificarCorreo,
      );
      expect(
        GuardiaRuta.destinoPara(NivelAcceso.verificacionPendiente, s),
        isNull,
      );
    });

    test('verificada sin rol admin → entra a todo menos admin', () async {
      final s = await sesionCon(_UsuarioFalso());
      expect(GuardiaRuta.destinoPara(NivelAcceso.autenticada, s), isNull);
      expect(GuardiaRuta.destinoPara(NivelAcceso.admin, s), AppRoutes.home);
      expect(
        GuardiaRuta.destinoPara(NivelAcceso.verificacionPendiente, s),
        AppRoutes.home,
      );
    });

    test('admin → entra a rutas de admin', () async {
      usuariaRepo.rol = Usuaria.rolAdmin;
      final s = await sesionCon(_UsuarioFalso());
      expect(GuardiaRuta.destinoPara(NivelAcceso.admin, s), isNull);
      expect(s.nombreVisible, 'Sofía');
    });
  });

  test('todas las pantallas de la estructura tienen ruta registrada', () {
    const esperadas = [
      AppRoutes.splash,
      AppRoutes.onboarding,
      AppRoutes.login,
      AppRoutes.registro,
      AppRoutes.avisoPrivacidad,
      AppRoutes.verificarCorreo,
      AppRoutes.recuperarContrasena,
      AppRoutes.home,
      AppRoutes.perfil,
      AppRoutes.editarPerfil,
      AppRoutes.colorimetria,
      AppRoutes.capturaSelfie,
      AppRoutes.analisis,
      AppRoutes.resultado,
      AppRoutes.paleta,
      AppRoutes.simuladorAr,
      AppRoutes.escaner,
      AppRoutes.analisisPrenda,
      AppRoutes.armario,
      AppRoutes.recomendaciones,
      AppRoutes.detallePrenda,
      AppRoutes.detalleProducto,
      AppRoutes.asistente,
      AppRoutes.catalogoAdmin,
      AppRoutes.formularioPrenda,
      AppRoutes.formularioProducto,
    ];
    expect(AppRouter.rutasRegistradas.toSet(), esperadas.toSet());
    expect(AppRouter.nivelDe(AppRoutes.catalogoAdmin), NivelAcceso.admin);
    expect(AppRouter.nivelDe(AppRoutes.login), NivelAcceso.publica);
  });

  testWidgets(
    'correo sin verificar que abre /paleta termina en verificar_correo',
    (tester) async {
      authRepo.usuario = _UsuarioFalso(emailVerified: false);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider(authRepo)),
            ChangeNotifierProvider(
              create: (_) => UsuariaProvider(
                usuariaRepository: usuariaRepo,
                authRepository: authRepo,
              ),
            ),
            ProxyProvider2<AuthProvider, UsuariaProvider, SesionProvider>(
              update: (_, a, u, _) => SesionProvider(
                auth: a,
                usuaria: u,
                preferencias: SesionRepository(),
                credenciales: CredencialRepository(),
              ),
            ),
          ],
          child: MaterialApp(
            initialRoute: AppRoutes.paleta,
            // Abre solo /paleta (por defecto Flutter también apilaría '/').
            onGenerateInitialRoutes: (ruta) => [
              AppRouter.onGenerateRoute(RouteSettings(name: ruta)),
            ],
            onGenerateRoute: AppRouter.onGenerateRoute,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.verificarCorreoTitulo), findsOneWidget);
      expect(find.textContaining('paleta_view'), findsNothing);
    },
  );
}
