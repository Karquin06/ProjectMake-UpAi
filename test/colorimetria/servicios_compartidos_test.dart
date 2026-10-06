import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/core/errors/app_exception.dart';
import 'package:mackeupai/data/repositories/perfil_colorimetria_repository.dart';
import 'package:mackeupai/data/services/cloud_functions_service.dart';
import 'package:mackeupai/data/services/colorimetria_mock_service.dart';
import 'package:mackeupai/data/services/permisos_service.dart';
import 'package:mackeupai/data/services/storage_service.dart';
import 'package:mackeupai/models/models.dart';
import 'package:mackeupai/ui/colorimetria/widgets/consentimiento_biometrico.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('PermisosService.combinar', () {
    test('concedido si alguno está concedido', () {
      expect(
        PermisosService.combinar(
            [PermissionStatus.denied, PermissionStatus.granted]),
        EstadoPermiso.concedido,
      );
    });

    test('denegado permanente solo si todos lo están', () {
      expect(
        PermisosService.combinar([PermissionStatus.permanentlyDenied]),
        EstadoPermiso.denegadoPermanente,
      );
      expect(
        PermisosService.combinar(
            [PermissionStatus.permanentlyDenied, PermissionStatus.denied]),
        EstadoPermiso.denegado,
      );
    });
  });

  test('RutasStorage arma las rutas temporales acordadas', () {
    expect(RutasStorage.selfieTemporal('u1', 'a'), 'temporales/selfies/u1/a.jpg');
    expect(RutasStorage.prendaTemporal('u1', 'b'), 'temporales/prendas/u1/b.jpg');
  });

  group('CloudFunctionsBase.traducir', () {
    test('usa el código de negocio en details', () {
      final e = CloudFunctionsBase.traducir(
        'failed-precondition',
        'x',
        {'codigo': CodigosFunciones.rostroNoDetectado},
        Exception(),
      );
      expect(e.codigo, CodigosFunciones.rostroNoDetectado);
      expect(e.mensaje, AppStrings.errorRostroNoDetectado);
    });

    test('usa el código de negocio en el mensaje', () {
      final e = CloudFunctionsBase.traducir(
          'failed-precondition', CodigosFunciones.imagenOscura, null, Exception());
      expect(e.mensaje, AppStrings.errorImagenOscura);
    });

    test('sin código conocido cae en el mensaje genérico', () {
      final e = CloudFunctionsBase.traducir('internal', 'boom', null, Exception());
      expect(e, isA<AppException>());
      expect(e.mensaje, AppStrings.errorInesperado);
    });
  });

  group('PerfilColorimetriaRepository', () {
    late PerfilColorimetriaRepository repo;

    setUp(() => repo = PerfilColorimetriaRepository(db: FakeFirebaseFirestore()));

    test('solo con consentimiento no hay perfil', () async {
      await repo.guardarConsentimiento('u1', ConsentimientoBiometrico.ahora());
      expect(await repo.obtenerPerfil('u1'), isNull);
      expect((await repo.obtenerConsentimiento('u1'))!.esVigente, isTrue);
    });

    test('guardar perfil conserva el consentimiento', () async {
      await repo.guardarConsentimiento('u1', ConsentimientoBiometrico.ahora());
      final perfil = PerfilColorimetria.fromMap(
        ColorimetriaMockService.perfilEjemplo('u1').toMap()
          ..remove('consentimiento'),
        uid: 'u1',
      );
      await repo.guardarPerfil(perfil);

      final leido = await repo.obtenerPerfil('u1');
      expect(leido!.estacionColor, EstacionColor.invierno);
      expect(leido.consentimiento, isNotNull);
    });

    test('escucharPerfil emite al guardar y al eliminar', () async {
      final eventos = repo.escucharPerfil('u1');
      final esperado = expectLater(
        eventos.map((p) => p?.estacionColor),
        emitsInOrder([null, EstacionColor.invierno, null]),
      );
      await Future<void>.delayed(Duration.zero);
      await repo.guardarPerfil(ColorimetriaMockService.perfilEjemplo('u1'));
      await Future<void>.delayed(Duration.zero);
      await repo.eliminarPerfil('u1');
      await esperado;
    });
  });

  group('HojaConsentimientoBiometrico', () {
    testWidgets('Continuar se habilita solo al marcar la casilla',
        (tester) async {
      var aceptaciones = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HojaConsentimientoBiometrico(
            onAceptar: () async => aceptaciones++,
          ),
        ),
      ));

      await tester.tap(find.text(AppStrings.continuar));
      await tester.pump();
      expect(aceptaciones, 0);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text(AppStrings.continuar));
      await tester.pump();
      expect(aceptaciones, 1);
    });
  });
}
