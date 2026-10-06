import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/core/theme/app_theme.dart';
import 'package:mackeupai/core/widgets/boton_primario.dart';
import 'package:mackeupai/data/repositories/auth_repository.dart';
import 'package:mackeupai/data/repositories/credencial_repository.dart';
import 'package:mackeupai/data/repositories/sesion_repository.dart';
import 'package:mackeupai/data/repositories/usuaria_repository.dart';
import 'package:mackeupai/models/usuaria.dart';
import 'package:mackeupai/providers/auth_provider.dart';
import 'package:mackeupai/providers/sesion_provider.dart';
import 'package:mackeupai/providers/usuaria_provider.dart';
import 'package:mackeupai/ui/auth/aviso_privacidad_view.dart';
import 'package:mackeupai/ui/auth/login_view.dart';
import 'package:mackeupai/ui/auth/recuperar_contrasena_view.dart';
import 'package:mackeupai/ui/auth/registro_view.dart';
import 'package:mackeupai/ui/auth/verificar_correo_view.dart';
import 'package:provider/provider.dart';

class _AuthRepoFalso extends Fake implements AuthRepository {
  final _cambios = StreamController<User?>.broadcast();
  @override
  User? get usuarioActual => null;
  @override
  Stream<User?> get cambiosDeSesion => _cambios.stream;
  @override
  Duration get esperaReenvioRestante => const Duration(seconds: 42);
}

class _UsuariaRepoFalso extends Fake implements UsuariaRepository {
  @override
  Stream<Usuaria?> escucharUsuaria(String uid) => const Stream.empty();
}

class _CredencialesFalsas extends Fake implements CredencialRepository {
  @override
  Future<String?> correoRecordado() async => 'recordada@ejemplo.com';
}

Widget _app(Widget pantalla) {
  final authRepo = _AuthRepoFalso();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider(authRepo)),
      ChangeNotifierProvider(
        create: (_) => UsuariaProvider(
          usuariaRepository: _UsuariaRepoFalso(),
          authRepository: authRepo,
        ),
      ),
      ProxyProvider2<AuthProvider, UsuariaProvider, SesionProvider>(
        update: (_, a, u, _) => SesionProvider(
          auth: a,
          usuaria: u,
          preferencias: SesionRepository(),
          credenciales: _CredencialesFalsas(),
        ),
      ),
    ],
    child: MaterialApp(theme: AppTheme.claro, home: pantalla),
  );
}

void main() {
  // Pantalla de teléfono pequeño para detectar desbordes.
  Future<void> telefono(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('login precarga el correo recordado', (tester) async {
    await telefono(tester);
    await tester.pumpWidget(_app(const LoginView()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('recordada@ejemplo.com'), findsOneWidget);
    expect(find.text(AppStrings.recordarme), findsOneWidget);
  });

  testWidgets('registro: botón deshabilitado hasta aceptar el aviso', (
    tester,
  ) async {
    await telefono(tester);
    await tester.pumpWidget(_app(const RegistroView()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    BotonPrimario boton() => tester.widget(find.byType(BotonPrimario));
    expect(boton().onPressed, isNull);

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(boton().onPressed, isNotNull);
  });

  testWidgets('aviso de privacidad, recuperar y verificar se renderizan', (
    tester,
  ) async {
    await telefono(tester);
    for (final pantalla in const [
      AvisoPrivacidadView(),
      RecuperarContrasenaView(),
      VerificarCorreoView(),
    ]) {
      await tester.pumpWidget(_app(pantalla));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: '$pantalla');
    }
    // La última es verificar correo: muestra la cuenta regresiva
    // (42 s restantes se redondean hacia arriba a 43).
    expect(find.text(AppStrings.reenviarEn(43)), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // cancela el temporizador
  });
}
