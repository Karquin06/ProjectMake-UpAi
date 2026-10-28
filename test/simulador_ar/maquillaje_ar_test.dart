import 'dart:ui';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:provider/provider.dart';
import 'package:mackeupai/ui/simulador_ar/widgets/selector_producto_ar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/data/repositories/armario_repository.dart';
import 'package:mackeupai/data/repositories/catalogo_repository.dart';
import 'package:mackeupai/models/deteccion_facial_ar.dart';
import 'package:mackeupai/models/enums.dart';
import 'package:mackeupai/models/producto_maquillaje.dart';
import 'package:mackeupai/providers/armario_provider.dart';
import 'package:mackeupai/providers/producto_provider.dart';
import 'package:mackeupai/ui/simulador_ar/maquillaje_ar_view_model.dart';
import 'package:mackeupai/ui/simulador_ar/widgets/contorno_labios_painter.dart';

ProductoMaquillaje producto(
  String id, {
  String categoria = 'labial',
  String hex = '#E04060',
  EstacionColor estacion = EstacionColor.invierno,
  bool activo = true,
}) => ProductoMaquillaje(
  id: id,
  nombre: id,
  marca: 'Marca',
  categoria: categoria,
  tono: id,
  colorHex: hex,
  acabado: 'mate',
  precio: 20000,
  imagenUrl: '',
  estacionesCompatibles: [estacion],
  activo: activo,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  Future<(MaquillajeArViewModel, ProductoProvider, ArmarioProvider)> entorno({
    String? inicial,
  }) async {
    final catalogo = CatalogoRepository(db: FakeFirebaseFirestore());
    for (final p in [
      producto('rojo'),
      producto('rosa'),
      producto('otra-estacion', estacion: EstacionColor.primavera),
      producto('rubor', categoria: 'rubor'),
      producto('sin-color', hex: ''),
      producto('desactivado', activo: false),
    ]) {
      await catalogo.guardarProducto(p);
    }
    final productos = ProductoProvider(catalogo)
      ..sincronizarEstacion(EstacionColor.invierno);
    final armario = ArmarioProvider(ArmarioRepository())
      ..sincronizarUsuaria('a');
    await Future<void>.delayed(Duration.zero);
    final vm = MaquillajeArViewModel(
      productos,
      armario,
      productoInicial: inicial,
    );
    addTearDown(() {
      vm.dispose();
      productos.dispose();
      armario.dispose();
    });
    await vm.cargar();
    return (vm, productos, armario);
  }

  test(
    'el modo libre ofrece categorías activas aunque no sean de su estación',
    () async {
      final (vm, _, _) = await entorno();
      expect(vm.productos.map((p) => p.id).toSet(), {
        'rojo',
        'rosa',
        'otra-estacion',
        'rubor',
      });
      expect(vm.seleccionado, isNull);
    },
  );
  test(
    'abre el producto recibido desde recomendaciones y guarda el mismo tono',
    () async {
      final (vm, _, armario) = await entorno(inicial: 'rosa');
      expect(vm.seleccionado?.id, 'rosa');
      expect(await vm.guardar(), isTrue);
      expect(armario.elementos.single.id, 'rosa');
      expect(armario.elementos.single.colorHex, '#E04060');
      vm.comparar();
      expect(vm.original, isTrue);
      vm.seleccionar('rojo');
      expect(vm.original, isFalse);
      vm.ajustarIntensidad(2);
      expect(vm.intensidad, 1);
    },
  );
  test('un rubor recibido por ruta utiliza su capa independiente', () async {
    final (vm, _, _) = await entorno(inicial: 'rubor');
    expect(vm.aviso, isNull);
    expect(vm.seleccionado?.categoria, 'rubor');
  });
  test('la prueba libre conserva el producto al cambiar de estación', () async {
    final (vm, productos, _) = await entorno(inicial: 'rosa');
    productos.sincronizarEstacion(EstacionColor.primavera);
    await Future<void>.delayed(Duration.zero);
    expect(vm.productos.map((p) => p.id), contains('otra-estacion'));
    expect(vm.seleccionado?.id, 'rosa');
  });
  test('las superficies de maquillaje excluyen la abertura de la boca', () {
    final d = DeteccionFacialAr(
      tamanoImagen: const Size(100, 100),
      rotacion: 0,
      esFrontal: false,
      rostroDetectado: true,
      contornosLabios: const [
        [Offset(10, 40), Offset(50, 30), Offset(90, 40)],
        [Offset(10, 40), Offset(50, 43), Offset(90, 40)],
        [Offset(10, 60), Offset(50, 57), Offset(90, 60)],
        [Offset(10, 60), Offset(50, 70), Offset(90, 60)],
      ],
    );
    final arriba = ContornoLabiosPainter.superficie(
      d,
      const Size(100, 100),
      0,
      1,
    );
    final abajo = ContornoLabiosPainter.superficie(
      d,
      const Size(100, 100),
      3,
      2,
    );
    expect(arriba.contains(const Offset(50, 36)), isTrue);
    expect(abajo.contains(const Offset(50, 64)), isTrue);
    expect(arriba.contains(const Offset(50, 50)), isFalse);
    expect(abajo.contains(const Offset(50, 50)), isFalse);
  });
  test(
    'comparación original no dibuja maquillaje ni oculta una pérdida de rostro',
    () async {
      final fotogramas = ValueNotifier<DeteccionFacialAr?>(null);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      ContornoLabiosPainter(
        fotogramas,
        color: Colors.red,
        original: true,
      ).paint(canvas, const Size(20, 20));
      final pic = recorder.endRecording(), imagen = await recorderImage(pic);
      final data = await imagen.toByteData();
      expect(data!.buffer.asUint8List().every((b) => b == 0), isTrue);
      imagen.dispose();
      pic.dispose();
      fotogramas.dispose();
    },
  );
  testWidgets(
    'los controles caben en poca altura y permiten comparar el original',
    (tester) async {
      tester.view.physicalSize = const Size(360, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final preparados = await tester.runAsync(() => entorno(inicial: 'rosa'));
      final (vm, _, armario) = preparados!;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MaquillajeArViewModel>.value(value: vm),
            ChangeNotifierProvider<ArmarioProvider>.value(value: armario),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: SelectorProductoAr(alturaMaxima: 110)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text(AppStrings.arOriginal));
      await tester.tap(find.text(AppStrings.arOriginal));
      await tester.pumpAndSettle();
      expect(vm.original, isTrue);
      expect(find.text(AppStrings.arMaquillaje), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<Image> recorderImage(Picture pic) => pic.toImage(20, 20);
