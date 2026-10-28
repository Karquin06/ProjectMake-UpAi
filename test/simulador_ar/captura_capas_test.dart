import 'dart:typed_data';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/data/repositories/armario_repository.dart';
import 'package:mackeupai/data/repositories/capturas_ar_repository.dart';
import 'package:mackeupai/data/repositories/catalogo_repository.dart';
import 'package:mackeupai/data/services/compartir_ar_service.dart';
import 'package:mackeupai/models/captura_ar.dart';
import 'package:mackeupai/providers/armario_provider.dart';
import 'package:mackeupai/providers/producto_provider.dart';
import 'package:mackeupai/ui/simulador_ar/maquillaje_ar_view_model.dart';
import 'capas_y_looks_test.dart' show p, r, RecomendacionesPrueba;

class CapturasPrueba extends CapturasArRepository {
  List<Map<String, dynamic>> guardadas = [];
  String? cuenta;
  @override
  Future<CapturaAr> guardar(
    String uid,
    Uint8List png, {
    required String producto,
    List<Map<String, dynamic>> capas = const [],
  }) async {
    cuenta = uid;
    guardadas = capas;
    return CapturaAr(
      id: '1',
      ruta: 'captura-prueba.png',
      producto: producto,
      fecha: DateTime(2026),
    );
  }
}

class CompartirPrueba extends CompartirArService {
  final pedidos = <CapturaAr>[];
  @override
  Future<void> compartir(CapturaAr captura) async {
    pedidos.add(captura);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'la captura registra las tres capas y compartir requiere una acción separada',
    () async {
      final catalogo = CatalogoRepository(db: FakeFirebaseFirestore());
      final lista = [p('l', 'labial'), p('r', 'rubor'), p('s', 'sombra')];
      for (final producto in lista) {
        await catalogo.guardarProducto(producto);
      }
      final productos = ProductoProvider(catalogo),
          armario = ArmarioProvider(ArmarioRepository())
            ..sincronizarUsuaria('u1');
      await Future<void>.delayed(Duration.zero);
      final capturas = CapturasPrueba(), compartir = CompartirPrueba();
      final vm = MaquillajeArViewModel(
        productos,
        armario,
        recomendaciones: RecomendacionesPrueba(lista.map(r).toList()),
        capturas: capturas,
        compartir: compartir,
      );
      addTearDown(() {
        vm.dispose();
        productos.dispose();
        armario.dispose();
      });
      await vm.cargar();
      expect(await vm.compartirUltima(), isFalse);
      expect(await vm.guardarCaptura(Uint8List(3)), isFalse);
      vm.aplicarLook(vm.looks.single.id);
      vm.enfocar('rubor');
      vm.ajustarIntensidad(.6);
      expect(await vm.guardarCaptura(Uint8List(3)), isTrue);
      expect(capturas.cuenta, 'u1');
      expect(capturas.guardadas.map((c) => c['id']).toSet(), {'l', 'r', 's'});
      expect(
        capturas.guardadas.firstWhere(
          (c) => c['categoria'] == 'rubor',
        )['intensidad'],
        .6,
      );
      expect(compartir.pedidos, isEmpty);
      expect(vm.ultimaCaptura?.producto, contains('Labial'));
      expect(await vm.compartirUltima(), isTrue);
      expect(compartir.pedidos, hasLength(1));
      armario.sincronizarUsuaria('u2');
      await Future<void>.delayed(Duration.zero);
      expect(await vm.compartirUltima(), isFalse);
      expect(compartir.pedidos, hasLength(1));
    },
  );
}
