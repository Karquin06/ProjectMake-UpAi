import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/constants/app_constants.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/core/routes/app_router.dart';
import 'package:mackeupai/core/theme/app_theme.dart';
import 'package:mackeupai/data/repositories/auth_repository.dart';
import 'package:mackeupai/data/repositories/credencial_repository.dart';
import 'package:mackeupai/data/repositories/perfil_colorimetria_repository.dart';
import 'package:mackeupai/data/repositories/sesion_repository.dart';
import 'package:mackeupai/data/repositories/usuaria_repository.dart';
import 'package:mackeupai/data/services/notificaciones_service.dart';
import 'package:mackeupai/models/models.dart';
import 'package:mackeupai/providers/notificaciones_provider.dart';
import 'package:mackeupai/providers/auth_provider.dart';
import 'package:mackeupai/providers/colorimetria_provider.dart';
import 'package:mackeupai/providers/paleta_provider.dart';
import 'package:mackeupai/data/services/colorimetria_mock_service.dart';
import 'package:mackeupai/providers/sesion_provider.dart';
import 'package:mackeupai/providers/usuaria_provider.dart';
import 'package:mackeupai/ui/home/home_datos_mock.dart';
import 'package:mackeupai/ui/home/home_view_model.dart';
import 'package:mackeupai/ui/home/main_navigation_view.dart';
import 'package:provider/provider.dart';

class _UsuarioFalso extends Fake implements User {
  @override
  String get uid => 'u1';
  @override
  bool get emailVerified => true;
  @override
  String? get email => 'sofia@ejemplo.com';
  @override
  String? get displayName => 'sofía martínez';
  @override
  String? get photoURL => null;
}

class _AuthRepoFalso extends Fake implements AuthRepository {
  final _cambios = StreamController<User?>.broadcast();
  @override
  User? get usuarioActual => _UsuarioFalso();
  @override
  Stream<User?> get cambiosDeSesion => _cambios.stream;
}

class _NotificacionesFalsas extends Fake implements NotificacionesService {
  @override
  bool get soportado => false;
}

class _UsuariaRepoFalso extends Fake implements UsuariaRepository {
  @override
  Stream<Usuaria?> escucharUsuaria(String uid) => const Stream.empty();
}

SesionProvider _sesion(AuthRepository repo) {
  final auth = AuthProvider(repo);
  return SesionProvider(
    auth: auth,
    usuaria: UsuariaProvider(
      usuariaRepository: _UsuariaRepoFalso(),
      authRepository: repo,
    ),
    preferencias: SesionRepository(),
    credenciales: CredencialRepository(),
  );
}

void main() {
  group('HomeViewModel', () {
    test('carga nombre, perfil, paleta y recomendaciones', () async {
      final vm = HomeViewModel(
        cargarPerfil: (uid) async => HomeDatosMock.perfil(uid),
        cargarPaleta: (_) async => HomeDatosMock.paleta,
        cargarRecomendaciones: (_) async => HomeDatosMock.recomendaciones,
      );
      vm.actualizarSesion(_sesion(_AuthRepoFalso()));
      await Future<void>.delayed(Duration.zero); // microtask de carga
      await Future<void>.delayed(Duration.zero);

      expect(vm.nombre, 'Sofía');
      expect(vm.tieneColorimetria, isTrue);
      expect(vm.perfil!.estacionColor, EstacionColor.invierno);
      expect(vm.paleta, isNotEmpty);
      expect(vm.recomendaciones, isNotEmpty);
      expect(vm.error, isNull);
    });

    test('sin perfil ni recomendaciones queda en estado vacío', () async {
      final vm = HomeViewModel(
        cargarPerfil: (_) async => null,
        cargarPaleta: (_) async => const [],
        cargarRecomendaciones: (_) async => const [],
      );
      vm.actualizarSesion(_sesion(_AuthRepoFalso()));
      await vm.cargar();
      expect(vm.tieneColorimetria, isFalse);
      expect(vm.recomendaciones, isEmpty);
    });

    test('error muestra mensaje y Reintentar vuelve a cargar', () async {
      var falla = true;
      final vm = HomeViewModel(
        cargarPerfil: (_) async {
          if (falla) throw TimeoutException('lento');
          return null;
        },
        cargarPaleta: (_) async => const [],
        cargarRecomendaciones: (_) async => const [],
      );
      vm.actualizarSesion(_sesion(_AuthRepoFalso()));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(vm.error, AppStrings.errorTiempoAgotado);

      falla = false;
      await vm.cargar();
      expect(vm.error, isNull);
    });

    test('Escáner y Armario siguen sus banderas', () {
      final vm = HomeViewModel();
      expect(
        vm.estaHabilitado(AccesoHome.escaner),
        AppConstants.escanerHabilitado,
      );
      expect(
        vm.estaHabilitado(AccesoHome.armario),
        AppConstants.armarioHabilitado,
      );
      expect(vm.estaHabilitado(AccesoHome.paleta), isTrue);
    });
  });

  testWidgets('Home se renderiza en 360 px y navega desde sus accesos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _AuthRepoFalso();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider(repo)),
          ChangeNotifierProvider(
            create: (_) => UsuariaProvider(
              usuariaRepository: _UsuariaRepoFalso(),
              authRepository: repo,
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
          ChangeNotifierProxyProvider<SesionProvider, NotificacionesProvider>(
            create: (c) => NotificacionesProvider(
              servicio: _NotificacionesFalsas(),
              usuarias: c.read<UsuariaProvider>(),
            ),
            update: (_, s, n) => n!..sincronizarUsuaria(s.uidActiva),
          ),
          // Pestaña Colorimetría (Jaider) con Firestore falso.
          ChangeNotifierProxyProvider<SesionProvider, ColorimetriaProvider>(
            create: (_) => ColorimetriaProvider(
              PerfilColorimetriaRepository(db: FakeFirebaseFirestore()),
            ),
            update: (_, s, p) => p!..sincronizarUsuaria(s.uidActiva),
          ),
          ChangeNotifierProxyProvider<ColorimetriaProvider, PaletaProvider>(
            create: (_) => PaletaProvider(ColorimetriaMockService()),
            update: (_, c, p) =>
                p!..sincronizarEstacion(c.perfil?.estacionColor),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.claro,
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const MainNavigationView(),
        ),
      ),
    );
    // Indicador de carga mientras llegan los datos mock.
    await tester.pump();
    expect(find.text(AppStrings.cargando), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.saludo('Sofía')), findsOneWidget);
    expect(find.text(AppStrings.tuEstacionDeColor), findsOneWidget);
    expect(find.text(AppStrings.proximamente), findsNWidgets(2));
    expect(find.text('Labial rojo frambuesa'), findsOneWidget);

    // Acceso deshabilitado → aviso "Próximamente".
    await tester.tap(find.text(AppStrings.accesoEscaner));
    await tester.pump();
    expect(
      find.text(AppStrings.accesoProximamente(AppStrings.accesoEscaner)),
      findsOneWidget,
    );

    // "Mi paleta" abre la paleta de Jaider (sin análisis en el Firestore
    // falso → estado vacío).
    await tester.tap(find.text(AppStrings.accesoPaleta));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.paletaSinAnalisisMensaje), findsOneWidget);
    Navigator.of(
      tester.element(find.text(AppStrings.paletaSinAnalisisMensaje)),
    ).pop();
    await tester.pumpAndSettle();

    // "Colorimetría" cambia a la pestaña de Colorimetría.
    await tester.tap(find.text(AppStrings.accesoColorimetria).first);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.colorimetriaTitulo), findsOneWidget);
  });
}
