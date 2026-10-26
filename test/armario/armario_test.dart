import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/data/repositories/armario_repository.dart';
import 'package:mackeupai/models/elemento_armario.dart';
import 'package:mackeupai/providers/armario_provider.dart';

ElementoArmario articulo({bool prenda = false}) => ElementoArmario(
  id: 'mismo-id',
  nombre: 'Coral',
  colorHex: '#F04060',
  imagenUrl: '',
  esPrenda: prenda,
  categoria: prenda ? 'superior' : 'labial',
  detalle: 'Tono coral',
  fecha: DateTime(2026, 10, 26),
);
Future<void> esperar() => Future<void>.delayed(Duration.zero);

class AlmacenConError extends ArmarioRepository {
  @override
  Future<void> guardar(String uid, List<ElementoArmario> elementos) async =>
      throw StateError('disco');
}

class LecturaTardia extends ArmarioRepository {
  final pendiente = Completer<List<ElementoArmario>>();
  @override
  Future<List<ElementoArmario>> cargar(String uid) =>
      uid == 'a' ? pendiente.future : Future.value([]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'persiste una copia del catálogo y la recupera en otra instancia',
    () async {
      await ArmarioRepository().guardar('a', [
        articulo(),
        articulo(prenda: true),
      ]);
      final items = await ArmarioRepository().cargar('a');
      expect(items.map((e) => e.clave), [
        'producto:mismo-id',
        'prenda:mismo-id',
      ]);
      expect(items.first.colorHex, '#F04060');
      expect(items.first.fecha, DateTime(2026, 10, 26));
      expect(await ArmarioRepository().cargar('b'), isEmpty);
    },
  );
  test(
    'no duplica artículos y quitar no elimina el catálogo ni otra cuenta',
    () async {
      final repo = ArmarioRepository();
      final p = ArmarioProvider(repo);
      addTearDown(p.dispose);
      p.sincronizarUsuaria('a');
      await esperar();
      expect(await p.agregar(articulo()), isTrue);
      expect(await p.agregar(articulo()), isTrue);
      expect(p.elementos, hasLength(1));
      await p.agregar(articulo(prenda: true));
      expect(p.elementos, hasLength(2));
      await p.quitar(articulo());
      expect(p.elementos.single.esPrenda, isTrue);
      p.sincronizarUsuaria('b');
      expect(p.elementos, isEmpty);
      await esperar();
      await p.agregar(articulo());
      expect((await repo.cargar('a')).single.esPrenda, isTrue);
      expect((await repo.cargar('b')).single.esPrenda, isFalse);
    },
  );
  test(
    'un fallo de escritura conserva la lista anterior y comunica el error',
    () async {
      FlutterSecureStorage.setMockInitialValues({'armario.v1.a': '[]'});
      final p = ArmarioProvider(AlmacenConError());
      addTearDown(p.dispose);
      p.sincronizarUsuaria('a');
      await esperar();
      expect(await p.agregar(articulo()), isFalse);
      expect(p.elementos, isEmpty);
      expect(p.error, AppStrings.armarioErrorGuardado);
    },
  );
  test('un archivo dañado no se sobrescribe con una lista vacía', () async {
    FlutterSecureStorage.setMockInitialValues({
      'armario.v1.a': 'archivo dañado',
    });
    final p = ArmarioProvider(ArmarioRepository());
    addTearDown(p.dispose);
    p.sincronizarUsuaria('a');
    await esperar();
    expect(p.error, AppStrings.armarioErrorLectura);
    expect(await p.agregar(articulo()), isFalse);
    expect(
      await const FlutterSecureStorage().read(key: 'armario.v1.a'),
      'archivo dañado',
    );
  });
  test(
    'una lectura de la cuenta anterior no contamina la sesión actual',
    () async {
      final repo = LecturaTardia();
      final actual = ArmarioProvider(repo);
      addTearDown(actual.dispose);
      actual.sincronizarUsuaria('a');
      await esperar();
      actual.sincronizarUsuaria('b');
      await esperar();
      repo.pendiente.complete([articulo()]);
      await esperar();
      expect(actual.uidSesion, 'b');
      expect(actual.elementos, isEmpty);
      expect(actual.cargando, isFalse);
    },
  );
}
