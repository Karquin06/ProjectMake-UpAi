import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';

/// Configuración común de las pruebas. Sin variables de entorno no cambia nada.
///
/// Para revisar que las pantallas se vean bien en cualquier tamaño, corre la
/// suite con un tamaño de pantalla (en puntos lógicos) y una escala de letra:
///
///   MACKEUP_PANTALLA=320x568 MACKEUP_LETRA=1.3 flutter test
///
/// Un desborde ("A RenderFlex overflowed by ...") hace fallar la prueba e
/// indica el widget y la línea que lo causa. Las pruebas que fijan su propio
/// tamaño con `tester.view.physicalSize` siguen usando el suyo.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final pantalla = Platform.environment['MACKEUP_PANTALLA'];
  final letra = double.tryParse(Platform.environment['MACKEUP_LETRA'] ?? '');
  if (pantalla != null || letra != null) {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    setUp(() {
      final vista = binding.platformDispatcher.views.first;
      if (pantalla != null) {
        final partes = pantalla.toLowerCase().split('x').map(double.parse).toList();
        vista.physicalSize = Size(partes[0], partes[1]);
        vista.devicePixelRatio = 1;
      }
      if (letra != null) binding.platformDispatcher.textScaleFactorTestValue = letra;
    });
    tearDown(() {
      binding.platformDispatcher.views.first.reset();
      binding.platformDispatcher.clearTextScaleFactorTestValue();
    });
  }
  await testMain();
}
