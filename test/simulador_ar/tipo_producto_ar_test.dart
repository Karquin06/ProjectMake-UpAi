import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/models/maquillaje_ar.dart';
import 'package:mackeupai/models/producto_maquillaje.dart';
import 'package:mackeupai/data/repositories/catalogo_repository.dart';
import 'package:mackeupai/data/repositories/armario_repository.dart';
import 'package:mackeupai/providers/producto_provider.dart';
import 'package:mackeupai/providers/armario_provider.dart';
import 'package:mackeupai/ui/simulador_ar/maquillaje_ar_view_model.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'capas_y_looks_test.dart' show p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'tipo AR explícito se conserva al guardar, copiar y leer sin alterar categoría',
    () {
      final original = p('g', 'labial').copyWith(tipoEfectoAr: 'brillo');
      final copia = ProductoMaquillaje.fromMap(
        original.toMap(),
        id: original.id,
      );
      expect(copia.categoria, 'labial');
      expect(copia.tipoEfectoAr, 'brillo');
      expect(RegistroEfectosAr().paraProducto(copia)?.categoria, 'brillo');
      expect(copia.copyWith(tono: 'otro').tipoEfectoAr, 'brillo');
      expect(
        copia
            .copyWith(quitarTipoEfectoAr: true)
            .toMap()
            .containsKey('tipoEfectoAr'),
        isFalse,
      );
    },
  );
  test(
    'nombre comercial y acabado brillante no se confunden con el tipo de producto',
    () {
      final r = RegistroEfectosAr(),
          producto = p('g', 'labial').copyWith(
            nombre: 'Brillo labial rosa nacarado',
            acabado: 'Brillante',
          );
      expect(r.paraProducto(producto)?.categoria, 'labial');
      expect(
        r.paraProducto(producto.copyWith(tipoEfectoAr: 'brillo'))?.categoria,
        'brillo',
      );
      expect(
        r
            .paraProducto(
              producto.copyWith(nombre: 'Otro nombre', tipoEfectoAr: 'brillo'),
            )
            ?.categoria,
        'brillo',
      );
      expect(producto.toMap().containsKey('tipoEfectoAr'), isFalse);
    },
  );
  test(
    'base queda desactivada como experimental y tipos desconocidos no se aplican',
    () {
      final r = RegistroEfectosAr();
      expect(r.buscar('base')!.experimental, isTrue);
      expect(r.admite(p('b', 'base')), isFalse);
      expect(
        r.admite(p('x', 'labial').copyWith(tipoEfectoAr: 'inexistente')),
        isFalse,
      );
    },
  );
  test(
    'gloss en modo libre utiliza su propia capa sin retirar labial ni rubor',
    () async {
      final repo = CatalogoRepository(db: FakeFirebaseFirestore());
      for (final producto in [
        p('l', 'labial'),
        p('r', 'rubor'),
        p('g', 'labial').copyWith(tipoEfectoAr: 'brillo'),
      ]) {
        await repo.guardarProducto(producto);
      }
      final productos = ProductoProvider(repo),
          armario = ArmarioProvider(ArmarioRepository())
            ..sincronizarUsuaria('u1');
      await Future<void>.delayed(Duration.zero);
      final vm = MaquillajeArViewModel(productos, armario);
      await vm.cargar();
      vm.cambiarModo(ModoMaquillajeAr.libre);
      vm.seleccionar('l');
      vm.seleccionar('r');
      vm.seleccionar('g');
      expect(vm.capas.map((c) => c.efecto.categoria).toSet(), {
        'labial',
        'rubor',
        'brillo',
      });
      expect(vm.categoria, 'brillo');
      vm.quitar('brillo');
      expect(vm.capas.map((c) => c.efecto.categoria).toSet(), {
        'labial',
        'rubor',
      });
      vm.dispose();
      productos.dispose();
      armario.dispose();
    },
  );
}
