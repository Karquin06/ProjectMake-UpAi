import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/utils/pantalla_segura.dart';
import 'package:mackeupai/core/widgets/pantalla_protegida.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final llamadas = <String>[];

  setUp(() {
    llamadas.clear();
    PantallaSegura.reiniciar();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PantallaSegura.canal, (call) async {
      llamadas.add(call.method);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PantallaSegura.canal, null);
  });

  group('PantallaSegura', () {
    test('activa al entrar y desactiva al salir', () async {
      await PantallaSegura.activar();
      await PantallaSegura.desactivar();
      expect(llamadas, ['activar', 'desactivar']);
    });

    test('dos pantallas apiladas: cerrar la de arriba no desprotege', () async {
      await PantallaSegura.activar();
      await PantallaSegura.activar();
      await PantallaSegura.desactivar();
      expect(llamadas, ['activar']);
      expect(PantallaSegura.activas, 1);
      await PantallaSegura.desactivar();
      expect(llamadas, ['activar', 'desactivar']);
    });

    test('desactivar de más no llama al canal', () async {
      await PantallaSegura.desactivar();
      expect(llamadas, isEmpty);
      expect(PantallaSegura.activas, 0);
    });

    test('sin canal nativo no lanza error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PantallaSegura.canal, null);
      await PantallaSegura.activar();
      await PantallaSegura.desactivar();
      expect(PantallaSegura.activas, 0);
    });

    test('un error de la plataforma no rompe la pantalla', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PantallaSegura.canal,
              (call) async => throw PlatformException(code: 'x'));
      await PantallaSegura.activar();
      expect(PantallaSegura.activas, 1);
    });
  });

  testWidgets('PantallaProtegida protege mientras está montada', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PantallaProtegida(child: Text('rostro'))),
    );
    expect(find.text('rostro'), findsOneWidget);
    expect(llamadas, ['activar']);

    await tester.pumpWidget(const MaterialApp(home: Text('otra')));
    expect(llamadas, ['activar', 'desactivar']);
    expect(PantallaSegura.activas, 0);
  });
}
