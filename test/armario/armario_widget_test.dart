import 'package:mackeupai/data/repositories/capturas_ar_repository.dart';
import 'package:mackeupai/models/captura_ar.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/core/theme/app_theme.dart';
import 'package:mackeupai/data/repositories/armario_repository.dart';
import 'package:mackeupai/data/repositories/catalogo_repository.dart';
import 'package:mackeupai/data/repositories/perfil_colorimetria_repository.dart';
import 'package:mackeupai/models/producto_maquillaje.dart';
import 'package:mackeupai/providers/armario_provider.dart';
import 'package:mackeupai/providers/colorimetria_provider.dart';
import 'package:mackeupai/ui/armario/armario_view.dart';

class _CapturasVacias extends CapturasArRepository {
  @override
  Future<List<CapturaAr>> listar(String uid) async => [];
}

void main() {
  testWidgets(
    'explorar, guardar, recuperar y quitar un labial en pantalla de 360 px',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FlutterSecureStorage.setMockInitialValues({});
      final catalogo = CatalogoRepository(db: FakeFirebaseFirestore());
      await catalogo.guardarProducto(
        const ProductoMaquillaje(
          id: 'rosa',
          nombre: 'Labial rosa',
          marca: 'Marca',
          categoria: 'labial',
          tono: 'Rosa',
          colorHex: '#E06090',
          acabado: 'mate',
          precio: 1000,
          imagenUrl: '',
        ),
      );
      final armario = ArmarioProvider(ArmarioRepository())
        ..sincronizarUsuaria('u1');
      final colorimetria = ColorimetriaProvider(
        PerfilColorimetriaRepository(db: FakeFirebaseFirestore()),
      );
      addTearDown(armario.dispose);
      addTearDown(colorimetria.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<CapturasArRepository>(create: (_) => _CapturasVacias()),
            Provider<CatalogoRepository>.value(value: catalogo),
            ChangeNotifierProvider<ArmarioProvider>.value(value: armario),
            ChangeNotifierProvider<ColorimetriaProvider>.value(
              value: colorimetria,
            ),
          ],
          child: MaterialApp(theme: AppTheme.claro, home: const ArmarioView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.armarioVacio), findsOneWidget);
      await tester.tap(find.text(AppStrings.armarioCatalogo));
      await tester.pumpAndSettle();
      expect(find.text('Labial rosa'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(AppStrings.armarioAgregar));
      await tester.pumpAndSettle();
      expect(armario.elementos.single.id, 'rosa');
      expect(
        (await ArmarioRepository().cargar('u1')).single.nombre,
        'Labial rosa',
      );
      await tester.tap(find.text(AppStrings.armarioGuardados));
      await tester.pumpAndSettle();
      expect(find.text('Labial rosa'), findsOneWidget);
      await tester.tap(find.byTooltip(AppStrings.armarioQuitar).first);
      await tester.pumpAndSettle();
      expect(armario.elementos, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(AppStrings.arResultados));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.arSinCapturas), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
