import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mackeupai/core/constants/app_constants.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/core/theme/app_theme.dart';
import 'package:mackeupai/data/repositories/auth_repository.dart';
import 'package:mackeupai/data/repositories/credencial_repository.dart';
import 'package:mackeupai/data/repositories/sesion_repository.dart';
import 'package:mackeupai/data/repositories/usuaria_repository.dart';
import 'package:mackeupai/data/services/notificaciones_service.dart';
import 'package:mackeupai/data/services/subidor_foto_perfil.dart';
import 'package:mackeupai/models/usuaria.dart';
import 'package:mackeupai/providers/auth_provider.dart';
import 'package:mackeupai/providers/limpieza_sesion.dart';
import 'package:mackeupai/providers/notificaciones_provider.dart';
import 'package:mackeupai/providers/sesion_provider.dart';
import 'package:mackeupai/providers/usuaria_provider.dart';
import 'package:mackeupai/ui/perfil/editar_perfil_view.dart';
import 'package:mackeupai/ui/perfil/editar_perfil_view_model.dart';
import 'package:mackeupai/ui/perfil/perfil_view.dart';
import 'package:mackeupai/ui/perfil/perfil_view_model.dart';
import 'package:provider/provider.dart';

final _registro = <String>[];

class _UsuarioFalso extends Fake implements User {
  @override
  String get uid => 'u1';
  @override
  bool get emailVerified => true;
  @override
  String? get email => 'sofia@ejemplo.com';
  @override
  String? get displayName => 'Sofía';
  @override
  String? get photoURL => null;
}

class _AuthRepoFalso extends Fake implements AuthRepository {
  User? usuario = _UsuarioFalso();
  final cambios = StreamController<User?>.broadcast();
  @override
  User? get usuarioActual => usuario;
  @override
  Stream<User?> get cambiosDeSesion => cambios.stream;
  @override
  Future<void> actualizarNombre(String nombre) async =>
      _registro.add('auth.nombre=$nombre');
  @override
  Future<void> cerrarSesion() async {
    _registro.add('auth.cerrarSesion');
    usuario = null;
    cambios.add(null);
  }
}

class _UsuariaRepoFalso extends Fake implements UsuariaRepository {
  @override
  Stream<Usuaria?> escucharUsuaria(String uid) => Stream.value(
    Usuaria(
      uid: uid,
      nombre: 'Sofía Martínez',
      email: 'sofia@ejemplo.com',
      fechaRegistro: DateTime(2026),
    ),
  );
  @override
  Future<void> actualizarUsuaria(
    String uid, {
    String? nombre,
    String? fotoPerfilUrl,
  }) async => _registro.add('doc.nombre=$nombre foto=$fotoPerfilUrl');
  @override
  Future<void> guardarTokenFcm(String uid, String? token) async =>
      _registro.add('doc.token=$token');
}

class _NotificacionesFalsas extends Fake implements NotificacionesService {
  @override
  bool get soportado => true;
  @override
  Future<bool> solicitarPermiso() async => true;
  @override
  Future<String?> obtenerToken() async => 'token-1';
  @override
  Stream<String> get cambiosDeToken => const Stream.empty();
  @override
  Stream<NotificacionEntrante> get mensajesEnPrimerPlano =>
      const Stream.empty();
  @override
  Future<void> eliminarToken() async => _registro.add('fcm.eliminarToken');
}

class _ProviderDePrueba extends ChangeNotifier with LimpiezaPorSesion {
  final eventos = <String>[];
  @override
  void limpiar() => eventos.add('limpiar');
  @override
  Future<void> alIniciarSesion(String uid) async => eventos.add('iniciar:$uid');
}

Uint8List _jpeg(int ancho, int alto) =>
    img.encodeJpg(img.Image(width: ancho, height: alto));

void main() {
  late _AuthRepoFalso authRepo;
  late AuthProvider auth;
  late UsuariaProvider usuarias;
  late SesionProvider sesion;
  late NotificacionesProvider notificaciones;

  setUp(() async {
    _registro.clear();
    authRepo = _AuthRepoFalso();
    auth = AuthProvider(authRepo);
    usuarias = UsuariaProvider(
      usuariaRepository: _UsuariaRepoFalso(),
      authRepository: authRepo,
      subidorFoto: SubidorFotoPerfilMock(),
    );
    authRepo.cambios.add(authRepo.usuario);
    sesion = SesionProvider(
      auth: auth,
      usuaria: usuarias,
      preferencias: SesionRepository(),
      credenciales: CredencialRepository(),
    );
    notificaciones = NotificacionesProvider(
      servicio: _NotificacionesFalsas(),
      usuarias: usuarias,
    );
    await Future<void>.delayed(Duration.zero);
  });

  group('EditarPerfilViewModel', () {
    EditarPerfilViewModel crear() => EditarPerfilViewModel(
      usuarias: usuarias,
      auth: auth,
      nombreInicial: 'Sofía Martínez',
      correo: 'sofia@ejemplo.com',
    );

    test('sin cambios no se puede guardar', () {
      expect(crear().puedeGuardar, isFalse);
    });

    test('cambiar el nombre lo guarda en Firestore y en Auth', () async {
      final vm = crear()..cambiarNombre('Sofía López ');
      expect(await vm.guardar(), ResultadoGuardado.guardado);
      expect(_registro, [
        'doc.nombre=Sofía López foto=null',
        'auth.nombre=Sofía López',
      ]);
    });

    test(
      'la foto se reduce a 1080 px y queda pendiente con Storage mock',
      () async {
        final vm = crear();
        await vm.seleccionarFoto(_jpeg(2400, 1200));
        expect(vm.error, isNull);
        final reducida = img.decodeJpg(vm.fotoNueva!)!;
        expect(reducida.width, AppConstants.ladoMaximoImagen);
        expect(reducida.height, 540);
        expect(await vm.guardar(), ResultadoGuardado.fotoPendiente);
      },
    );

    test('rechaza imágenes inválidas o demasiado pesadas', () async {
      final vm = crear();
      await vm.seleccionarFoto(Uint8List.fromList([1, 2, 3]));
      expect(vm.error, AppStrings.errorImagenInvalida);
      await vm.seleccionarFoto(
        Uint8List(AppConstants.tamanoMaximoImagenBytes + 1),
      );
      expect(vm.error, AppStrings.errorImagenMuyGrande);
      expect(vm.fotoNueva, isNull);
    });
  });

  test(
    'cerrar sesión desregistra el token antes de salir y limpia todo',
    () async {
      notificaciones.sincronizarUsuaria('u1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(_registro, contains('doc.token=token-1'));
      expect(notificaciones.permisoConcedido, isTrue);
      expect(usuarias.usuaria, isNotNull);

      final vm = PerfilViewModel(
        notificaciones: notificaciones,
        auth: auth,
        usuarias: usuarias,
      )..actualizarSesion(sesion);
      expect(await vm.cerrarSesion(), isTrue);
      expect(_registro.sublist(_registro.indexOf('doc.token=null')), [
        'doc.token=null',
        'fcm.eliminarToken',
        'auth.cerrarSesion',
      ]);

      // Los providers se limpian solos al detectar el cierre de sesión.
      notificaciones.sincronizarUsuaria(null);
      await Future<void>.delayed(Duration.zero);
      expect(usuarias.usuaria, isNull);
      expect(auth.haySesion, isFalse);
      expect(notificaciones.permisoConcedido, isFalse);
    },
  );

  test('LimpiezaPorSesion limpia al cambiar de cuenta', () async {
    final p = _ProviderDePrueba();
    p.sincronizarUsuaria('a');
    await Future<void>.delayed(Duration.zero);
    p.sincronizarUsuaria('b');
    await Future<void>.delayed(Duration.zero);
    p.sincronizarUsuaria(null);
    await Future<void>.delayed(Duration.zero);
    expect(p.eventos, ['iniciar:a', 'limpiar', 'iniciar:b', 'limpiar']);
  });

  testWidgets('Perfil y Editar perfil se renderizan en 360 px', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget app(Widget pantalla) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: usuarias),
        ChangeNotifierProvider.value(value: notificaciones),
        ProxyProvider2<AuthProvider, UsuariaProvider, SesionProvider>(
          update: (_, a, u, _) => SesionProvider(
            auth: a,
            usuaria: u,
            preferencias: SesionRepository(),
            credenciales: CredencialRepository(),
          ),
        ),
      ],
      child: MaterialApp(theme: AppTheme.claro, home: pantalla),
    );

    await tester.pumpWidget(app(const PerfilView()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Sofía Martínez'), findsOneWidget);
    expect(find.text(AppStrings.cerrarSesion), findsOneWidget);
    expect(find.text(AppStrings.eliminarCuenta), findsOneWidget);

    await tester.pumpWidget(app(const EditarPerfilView()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.guardarCambios), findsOneWidget);
  });
}
