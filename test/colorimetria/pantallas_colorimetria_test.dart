import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/data/repositories/perfil_colorimetria_repository.dart';
import 'package:mackeupai/data/services/colorimetria_mock_service.dart';
import 'package:mackeupai/data/services/permisos_service.dart';
import 'package:mackeupai/models/models.dart';
import 'package:mackeupai/providers/colorimetria_provider.dart';
import 'package:mackeupai/providers/paleta_provider.dart';
import 'package:mackeupai/ui/colorimetria/captura_selfie_view_model.dart';
import 'package:mackeupai/ui/colorimetria/colorimetria_view.dart';
import 'package:mackeupai/ui/colorimetria/colorimetria_view_model.dart';
import 'package:provider/provider.dart';

class _PermisosFalsos extends PermisosService {
  EstadoPermiso respuesta;
  int pedidos = 0;
  _PermisosFalsos(this.respuesta);

  @override
  Future<EstadoPermiso> pedirCamara() async {
    pedidos++;
    return respuesta;
  }
}

/// Espera a que corran los microtasks diferidos del provider.
Future<void> _esperar() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late PerfilColorimetriaRepository repo;
  late ColorimetriaProvider provider;

  setUp(() {
    repo = PerfilColorimetriaRepository(db: FakeFirebaseFirestore());
    provider = ColorimetriaProvider(repo)..sincronizarUsuaria('u1');
  });

  group('ColorimetriaViewModel', () {
    test('sin análisis pide consentimiento', () async {
      await _esperar();
      final vm = ColorimetriaViewModel(provider);
      expect(vm.estado, EstadoColorimetria.sinAnalisis);
      expect(vm.iniciarAnalisis(), PasoAnalisis.pedirConsentimiento);

      await vm.aceptarConsentimiento();
      expect(vm.iniciarAnalisis(), PasoAnalisis.abrirCaptura);
      expect((await repo.obtenerConsentimiento('u1'))!.esVigente, isTrue);
    });

    test('con perfil guardado muestra el resultado', () async {
      await repo.guardarPerfil(ColorimetriaMockService.perfilEjemplo('u1'));
      await _esperar();
      await provider.refrescar();
      final vm = ColorimetriaViewModel(provider);
      expect(vm.estado, EstadoColorimetria.conResultado);
      expect(vm.perfil!.estacionColor, EstacionColor.invierno);
    });

    test('repetirAnalisis respeta la confirmación', () async {
      await _esperar();
      final vm = ColorimetriaViewModel(provider);
      expect(await vm.repetirAnalisis(() async => false), isNull);
      expect(await vm.repetirAnalisis(() async => true),
          PasoAnalisis.pedirConsentimiento);
    });

    test('al cerrar sesión se limpia el perfil', () async {
      await repo.guardarPerfil(ColorimetriaMockService.perfilEjemplo('u1'));
      await _esperar();
      await provider.refrescar();
      expect(provider.tienePerfil, isTrue);
      provider.sincronizarUsuaria(null);
      await _esperar();
      expect(provider.tienePerfil, isFalse);
    });
  });

  testWidgets('ColorimetriaView muestra el estado vacío y el consentimiento',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: ColorimetriaView()),
    ));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.sinAnalisisTitulo), findsOneWidget);

    await tester.tap(find.text(AppStrings.iniciarAnalisis));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.consentimientoTitulo), findsOneWidget);
  });

  group('PaletaProvider', () {
    test('carga la paleta al tener estación y la limpia sin ella', () async {
      final paletas = PaletaProvider(ColorimetriaMockService(espera: Duration.zero));
      paletas.sincronizarEstacion(EstacionColor.invierno);
      await _esperar();
      expect(paletas.paleta!.coloresRecomendados, isNotEmpty);

      paletas.sincronizarEstacion(null);
      await _esperar();
      expect(paletas.paleta, isNull);
    });
  });

  group('CapturaSelfieViewModel', () {
    test('permiso denegado', () async {
      final vm = CapturaSelfieViewModel(_PermisosFalsos(EstadoPermiso.denegado));
      await vm.iniciar();
      expect(vm.estado, EstadoCaptura.permisoDenegado);
    });

    test('permiso denegado permanente y reintento al volver de ajustes',
        () async {
      final permisos = _PermisosFalsos(EstadoPermiso.denegadoPermanente);
      final vm = CapturaSelfieViewModel(permisos, listarCamaras: () async => []);
      await vm.iniciar();
      expect(vm.estado, EstadoCaptura.permisoDenegadoPermanente);

      permisos.respuesta = EstadoPermiso.concedido;
      await vm.alCambiarCicloDeVida(AppLifecycleState.resumed);
      expect(permisos.pedidos, 2);
      // Sin cámaras disponibles termina en error claro.
      expect(vm.estado, EstadoCaptura.error);
      expect(vm.error, AppStrings.errorCamaraNoDisponible);
    });
  });
}
