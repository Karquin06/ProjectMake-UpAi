import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mackeupai/core/errors/app_exception.dart';
import 'package:mackeupai/data/services/funciones_ia_service.dart';
import 'package:mackeupai/data/repositories/perfil_colorimetria_repository.dart';
import 'package:mackeupai/data/repositories/catalogo_repository.dart';
import 'package:mackeupai/data/repositories/recomendacion_repository.dart';
import 'package:mackeupai/data/repositories/armario_repository.dart';
import 'package:mackeupai/models/enums.dart';
import 'package:mackeupai/providers/colorimetria_provider.dart';
import 'package:mackeupai/providers/recomendacion_provider.dart';
import 'package:mackeupai/providers/producto_provider.dart';
import 'package:mackeupai/providers/armario_provider.dart';
import 'package:mackeupai/ui/simulador_ar/maquillaje_ar_view_model.dart';
import 'reparacion_ar_test.dart' show render, diferencia;
import 'capas_y_looks_test.dart' show p, crearPerfilAr;

class FuncionesSinDespliegue extends Fake implements FuncionesIaService {
  @override
  Future<List<RecomendacionGenerada>> generarRecomendaciones({
    required TipoRecomendacion tipo,
    String? ocasion,
    int limite = 20,
  }) async => throw const AppException(
    'Función no desplegada en esta prueba',
    codigo: CodigosFuncionesIa.noDesplegada,
  );
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'perfil persistido → recomendaciones del equipo → catálogo → cuatro capas visuales reales del fixture',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final db = FakeFirebaseFirestore();
      final perfiles = PerfilColorimetriaRepository(db: db),
          catalogo = CatalogoRepository(db: db);
      final colorimetria = ColorimetriaProvider(perfiles);
      final recos = RecomendacionProvider(
        funciones: FuncionesSinDespliegue(),
        catalogo: catalogo,
        recomendaciones: RecomendacionRepository(db: db),
      );
      final productos = ProductoProvider(catalogo),
          armario = ArmarioProvider(ArmarioRepository());
      final vm = MaquillajeArViewModel(
        productos,
        armario,
        recomendaciones: recos,
        colorimetria: colorimetria,
      );
      addTearDown(() {
        vm.dispose();
        productos.dispose();
        armario.dispose();
        recos.dispose();
        colorimetria.dispose();
      });
      await t.runAsync(() async {
        await perfiles.guardarPerfil(
          crearPerfilAr(),
        ); // Mismo contrato de salida del escáner.
        for (final tipo in ['base', 'rubor', 'sombra', 'labial']) {
          await catalogo.guardarProducto(
            p(tipo, tipo),
          ); // Documentos fixture, no producción.
        }
        await catalogo.guardarProducto(
          p('incompatible', 'labial', estacion: EstacionColor.otono),
        );
        armario.sincronizarUsuaria('u1');
        recos.sincronizarUsuaria('u1');
        colorimetria.sincronizarUsuaria('u1');
        // Deliberadamente sin actualizarPerfil en el test: lo hace el flujo AR
        // cuando esperarPerfil termina, incluso antes del siguiente build proxy.
        await vm.cargar();
      });
      expect(vm.perfil!.uid, 'u1');
      expect(recos.usandoRespaldo, isTrue);
      expect(vm.looks, isNotEmpty);
      vm.aplicarLook(vm.looks.first.id);
      expect(vm.capas.map((c) => c.efecto.categoria).toSet(), {
        'base',
        'rubor',
        'sombra',
        'labial',
      });
      expect(vm.capas.any((c) => c.producto.id == 'incompatible'), isFalse);
      for (final capa in vm.capas) {
        expect(
          capa.producto.colorHex,
          p(capa.producto.id, capa.producto.categoria).colorHex,
        );
      }
      expect(vm.compatibilidadSeleccion, contains('recomendado'));
      final original = await render(t, []), foto = await render(t, vm.capas);
      for (final q in [
        (100, 55),
        (100, 165),
        (100, 188),
        (50, 115),
        (65, 85),
      ]) {
        expect(diferencia(original, foto, q.$1, q.$2), greaterThan(0));
      }
      vm.quitar('base');
      expect(vm.capas.map((c) => c.efecto.categoria).toSet(), {
        'rubor',
        'sombra',
        'labial',
      });
      await t.runAsync(() async {
        armario.sincronizarUsuaria('otra');
        await Future<void>.delayed(Duration.zero);
      });
      expect(vm.capas, isEmpty);
      expect(vm.perfil, isNull);
    },
  );
}
