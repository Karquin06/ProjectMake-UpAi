import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/data/repositories/perfil_colorimetria_repository.dart';
import 'package:mackeupai/data/services/colorimetria_mock_service.dart';
import 'package:mackeupai/providers/colorimetria_provider.dart';
import 'package:mackeupai/providers/paleta_provider.dart';
import 'package:mackeupai/ui/colorimetria/paleta_view.dart';
import 'package:provider/provider.dart';

Future<void> _montar(WidgetTester tester, {required bool conPerfil}) async {
  final repo = PerfilColorimetriaRepository(db: FakeFirebaseFirestore());
  if (conPerfil) {
    await repo.guardarPerfil(ColorimetriaMockService.perfilEjemplo('u1'));
  }
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => ColorimetriaProvider(repo)..sincronizarUsuaria('u1'),
      ),
      ChangeNotifierProxyProvider<ColorimetriaProvider, PaletaProvider>(
        create: (_) =>
            PaletaProvider(ColorimetriaMockService(espera: Duration.zero)),
        update: (_, c, p) => p!..sincronizarEstacion(c.perfil?.estacionColor),
      ),
    ],
    child: const MaterialApp(home: PaletaView()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin análisis muestra el estado vacío', (tester) async {
    await _montar(tester, conPerfil: false);
    expect(find.text(AppStrings.paletaSinAnalisisMensaje), findsOneWidget);
  });

  testWidgets('con análisis muestra pestañas y el detalle de un color',
      (tester) async {
    String? copiado;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (llamada) async {
        if (llamada.method == 'Clipboard.setData') {
          copiado = (llamada.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await _montar(tester, conPerfil: true);
    expect(find.text(AppStrings.tusColores), findsOneWidget);
    expect(find.text(AppStrings.coloresAEvitar), findsOneWidget);

    await tester.tap(find.text('Azul clásico'));
    await tester.pumpAndSettle();
    expect(find.text('#0F4C81'), findsOneWidget);
    expect(find.text(AppStrings.copiarHex), findsOneWidget);

    await tester.tap(find.text(AppStrings.copiarHex));
    await tester.pumpAndSettle();
    expect(copiado, '#0F4C81');
    expect(find.text(AppStrings.hexCopiado('#0F4C81')), findsOneWidget);

    await tester.tap(find.text(AppStrings.coloresAEvitar));
    await tester.pumpAndSettle();
    expect(find.text('Mostaza'), findsOneWidget);
  });
}
