import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/core/theme/app_theme.dart';
import 'package:mackeupai/data/repositories/armario_repository.dart';
import 'package:mackeupai/data/repositories/catalogo_repository.dart';
import 'package:mackeupai/models/enums.dart';
import 'package:mackeupai/models/maquillaje_ar.dart';
import 'package:mackeupai/providers/armario_provider.dart';
import 'package:mackeupai/providers/producto_provider.dart';
import 'package:mackeupai/ui/simulador_ar/maquillaje_ar_view_model.dart';
import 'package:mackeupai/ui/simulador_ar/widgets/selector_producto_ar.dart';
import 'capas_y_looks_test.dart' show p, r, RecomendacionesPrueba;

void main() {
  testWidgets(
    'elige look de tres productos, quita sombra y sustituye labial en modo libre',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FlutterSecureStorage.setMockInitialValues({});
      final entorno = await tester.runAsync(() async {
        final catalogo = CatalogoRepository(db: FakeFirebaseFirestore());
        final labial = p('l', 'labial'),
            rubor = p('r', 'rubor'),
            sombra = p('s', 'sombra');
        for (final producto in [
          labial,
          rubor,
          sombra,
          p('otra', 'labial', estacion: EstacionColor.otono),
        ]) {
          await catalogo.guardarProducto(producto);
        }
        final productos = ProductoProvider(catalogo),
            armario = ArmarioProvider(ArmarioRepository())
              ..sincronizarUsuaria('u1');
        await Future<void>.delayed(Duration.zero);
        final vm = MaquillajeArViewModel(
          productos,
          armario,
          recomendaciones: RecomendacionesPrueba([
            r(labial),
            r(rubor),
            r(sombra),
          ]),
        );
        await vm.cargar();
        return (vm, productos, armario);
      });
      final (vm, productos, armario) = entorno!;
      addTearDown(() {
        vm.dispose();
        productos.dispose();
        armario.dispose();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MaquillajeArViewModel>.value(value: vm),
            ChangeNotifierProvider<ArmarioProvider>.value(value: armario),
          ],
          child: MaterialApp(
            theme: AppTheme.claro,
            home: const Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SelectorProductoAr(alturaMaxima: 420),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Combinación 1'));
      await tester.pumpAndSettle();
      expect(vm.capas, hasLength(3));
      expect(tester.takeException(), isNull);
      final sombraChip = find.byKey(const ValueKey('capa-sombra'));
      await tester.ensureVisible(sombraChip);
      final borrar = find.descendant(
        of: sombraChip,
        matching: find.byTooltip(AppStrings.arQuitarCapa),
      );
      await tester.tap(borrar);
      await tester.pumpAndSettle();
      expect(vm.capas.map((c) => c.efecto.categoria).toSet(), {
        'labial',
        'rubor',
      });
      await tester.ensureVisible(find.text(AppStrings.arModoLibre));
      await tester.tap(find.text(AppStrings.arModoLibre));
      await tester.pumpAndSettle();
      expect(vm.modo, ModoMaquillajeAr.libre);
      expect(vm.productos.map((p) => p.id), contains('otra'));
      final dropdown = find.byType(DropdownButton<String>).first;
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('otra · otra').last);
      await tester.pumpAndSettle();
      expect(
        vm.capas.firstWhere((c) => c.efecto.categoria == 'labial').producto.id,
        'otra',
      );
      expect(
        vm.capas.firstWhere((c) => c.efecto.categoria == 'rubor').producto.id,
        'r',
      );
      await tester.ensureVisible(find.byTooltip(AppStrings.arLimpiar));
      await tester.tap(find.byTooltip(AppStrings.arLimpiar));
      await tester.pumpAndSettle();
      expect(vm.capas, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
