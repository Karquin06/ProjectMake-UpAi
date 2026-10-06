import 'dart:typed_data';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/core/errors/app_exception.dart';
import 'package:mackeupai/data/repositories/paleta_repository.dart';
import 'package:mackeupai/data/repositories/perfil_colorimetria_repository.dart';
import 'package:mackeupai/data/services/cloud_functions_service.dart';
import 'package:mackeupai/data/services/colorimetria_mock_service.dart';
import 'package:mackeupai/data/services/storage_service.dart';
import 'package:mackeupai/models/models.dart';
import 'package:mackeupai/providers/colorimetria_provider.dart';
import 'package:mackeupai/providers/paleta_provider.dart';
import 'package:mackeupai/ui/colorimetria/analisis_view_model.dart';
import 'package:mackeupai/ui/colorimetria/resultado_view.dart';
import 'package:mackeupai/ui/colorimetria/resultado_view_model.dart';
import 'package:provider/provider.dart';

class _StorageFalso extends StorageService {
  final subidos = <String>[];
  final borrados = <String>[];
  Object? errorSubida;

  @override
  Future<String> subirArchivo(String ruta, Uint8List datos,
      {String contentType = 'image/jpeg',
      void Function(double progreso)? onProgreso}) async {
    if (errorSubida != null) throw errorSubida!;
    onProgreso?.call(0.5);
    onProgreso?.call(1);
    subidos.add(ruta);
    return ruta;
  }

  @override
  Future<void> borrar(String ruta) async => borrados.add(ruta);
}

class _ColorimetriaQueFalla extends ColorimetriaMockService {
  final AppException error;
  _ColorimetriaQueFalla(this.error) : super(espera: Duration.zero);

  @override
  Future<PerfilColorimetria> analizarSelfie({
    required String uid,
    required String rutaImagen,
    ConsentimientoBiometrico? consentimiento,
  }) async =>
      throw error;
}

AnalisisViewModel _vm(_StorageFalso storage, ColorimetriaService servicio) =>
    AnalisisViewModel(
      storage: storage,
      colorimetria: servicio,
      uid: 'u1',
      selfie: Uint8List.fromList([1, 2, 3]),
      subirSelfie: true,
    );

void main() {
  group('AnalisisViewModel', () {
    test('éxito: sube, analiza, borra en Storage y suelta la foto local',
        () async {
      final storage = _StorageFalso();
      final vm = _vm(storage, ColorimetriaMockService(espera: Duration.zero));
      await vm.analizar();
      await Future<void>.delayed(Duration.zero);

      expect(vm.estado, EstadoAnalisis.listo);
      expect(vm.perfil!.estacionColor, EstacionColor.invierno);
      expect(storage.subidos.single, startsWith('temporales/selfies/u1/'));
      expect(storage.borrados, storage.subidos);
      expect(vm.puedeReintentar, isFalse);
    });

    test('rostro no detectado sugiere tomar otra foto', () async {
      final storage = _StorageFalso();
      final vm = _vm(
        storage,
        _ColorimetriaQueFalla(const AppException(
          AppStrings.errorRostroNoDetectado,
          codigo: CodigosFunciones.rostroNoDetectado,
        )),
      );
      await vm.analizar();
      await Future<void>.delayed(Duration.zero);

      expect(vm.estado, EstadoAnalisis.error);
      expect(vm.error, AppStrings.errorRostroNoDetectado);
      expect(vm.sugiereOtraFoto, isTrue);
      expect(storage.borrados, isNotEmpty);
    });

    test('sin conexión muestra el mensaje de red y permite reintentar',
        () async {
      final storage = _StorageFalso()
        ..errorSubida = const AppException('x', codigo: 'retry-limit-exceeded');
      final vm = _vm(storage, ColorimetriaMockService(espera: Duration.zero));
      await vm.analizar();

      expect(vm.error, AppStrings.errorSinConexion);
      expect(vm.sugiereOtraFoto, isFalse);
      expect(vm.puedeReintentar, isTrue);

      storage.errorSubida = null;
      await vm.analizar();
      expect(vm.estado, EstadoAnalisis.listo);
    });
  });

  group('Resultado', () {
    late PerfilColorimetriaRepository repo;
    late ColorimetriaProvider provider;

    setUp(() async {
      repo = PerfilColorimetriaRepository(db: FakeFirebaseFirestore());
      provider = ColorimetriaProvider(repo)..sincronizarUsuaria('u1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });

    test('guardar persiste el perfil y lo publica en el provider', () async {
      final vm = ResultadoViewModel(
          provider, ColorimetriaMockService.perfilEjemplo('u1'));
      await vm.guardar();
      expect(vm.guardado, isTrue);
      expect(provider.perfil!.estacionColor, EstacionColor.invierno);
      expect(await repo.obtenerPerfil('u1'), isNotNull);
    });

    testWidgets('ResultadoView guarda y muestra el subtono', (tester) async {
      final perfil = ColorimetriaMockService.perfilEjemplo('u1');
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          onGenerateRoute: (_) => MaterialPageRoute(
            settings: RouteSettings(arguments: perfil),
            builder: (_) => const ResultadoView(),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.subtonoFrioDetalle), findsOneWidget);
      expect(find.text(AppStrings.verMiPaletaBoton), findsOneWidget);
      expect(provider.tienePerfil, isTrue);
    });
  });

  group('Paletas', () {
    test('PaletaRepository lee paletas/{estacion}', () async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('paletas')
          .doc('invierno')
          .set(ColorimetriaMockService.paletaEjemplo.toMap());
      final repo = PaletaRepository(db: db);
      expect((await repo.obtenerPaleta(EstacionColor.invierno))!
          .coloresEvitar, isNotEmpty);
      expect(await repo.obtenerPaleta(EstacionColor.verano), isNull);
    });

    test('PaletaProvider usa la función si la paleta no está en Firestore',
        () async {
      final paletas = PaletaProvider.conRespaldo(
        PaletaRepository(db: FakeFirebaseFirestore()),
        ColorimetriaMockService(espera: Duration.zero),
      )..sincronizarEstacion(EstacionColor.verano);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(paletas.paleta!.estacion, EstacionColor.verano);
    });
  });
}
