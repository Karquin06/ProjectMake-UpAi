import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/data/repositories/catalogo_repository.dart';
import 'package:mackeupai/models/models.dart';
import 'package:mackeupai/ui/admin/catalogo_admin_view_model.dart';

PrendaRopa _prenda(
  String nombre, {
  String tipo = 'superior',
  List<EstacionColor> estaciones = const [EstacionColor.invierno],
  bool activo = true,
}) =>
    PrendaRopa(
      id: '',
      nombre: nombre,
      marca: 'Marca',
      tipoPrenda: tipo,
      colorPrincipal: 'Rojo',
      colorHex: '#C62828',
      talla: 'M',
      material: 'Algodón',
      estilo: 'Clásico',
      formalidad: 'Casual',
      estacionesCompatibles: estaciones,
      precio: 50000,
      imagenUrl: '',
      activo: activo,
    );

ProductoMaquillaje _producto(String nombre, {String categoria = 'labial'}) =>
    ProductoMaquillaje(
      id: '',
      nombre: nombre,
      marca: 'Marca',
      categoria: categoria,
      tono: 'Rojo',
      colorHex: '#B71C1C',
      acabado: 'Mate',
      estacionesCompatibles: const [EstacionColor.invierno],
      subtonoCompatible: const [Subtono.frio],
      precio: 30000,
      imagenUrl: '',
    );

void main() {
  late FakeFirebaseFirestore db;
  late CatalogoRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = CatalogoRepository(db: db);
  });

  group('Modelos de catálogo', () {
    test('PrendaRopa: toMap y fromMap conservan los datos nuevos', () {
      final original = _prenda('Blusa Roja').copyWith(
        ocasiones: ['trabajo', 'fiesta'],
        subtonosCompatibles: [Subtono.frio],
        imagenRuta: 'catalogo/prendas/1.jpg',
      );
      final copia = PrendaRopa.fromMap(original.toMap(), id: 'p1');
      expect(copia.nombre, 'Blusa Roja');
      expect(copia.ocasiones, ['trabajo', 'fiesta']);
      expect(copia.subtonosCompatibles, [Subtono.frio]);
      expect(copia.colorHex, '#C62828');
      expect(copia.imagenRuta, 'catalogo/prendas/1.jpg');
      expect(copia.activo, isTrue);
      expect(original.toMap()['nombreMinusculas'], 'blusa roja');
    });

    test('documentos viejos sin campos nuevos se leen sin error', () {
      final p = PrendaRopa.fromMap({'marca': 'Zara', 'precio': 10}, id: 'x');
      expect(p.activo, isTrue);
      expect(p.nombreVisible, 'Zara');
      final m = ProductoMaquillaje.fromMap(
        {'marca': 'Mac', 'tono': 'Ruby'},
        id: 'y',
      );
      expect(m.nombreVisible, 'Mac · Ruby');
      expect(m.enlace, isNull);
    });
  });

  group('CatalogoRepository', () {
    test('guardar crea con id nuevo y luego reemplaza', () async {
      final id = await repo.guardarPrenda(_prenda('Blusa'));
      expect(id, isNotEmpty);
      final guardada = await repo.obtenerPrenda(id);
      expect(guardada!.nombre, 'Blusa');
      expect(guardada.fechaActualizacion, isNotNull);

      await repo.guardarPrenda(guardada.copyWith(nombre: 'Blusa nueva'));
      expect((await repo.obtenerPrenda(id))!.nombre, 'Blusa nueva');
      expect((await db.collection(PrendaRopa.collection).get()).size, 1);
    });

    test('filtra por categoría y por estación', () async {
      await repo.guardarPrenda(_prenda('Blusa'));
      await repo.guardarPrenda(_prenda('Falda', tipo: 'inferior'));
      await repo.guardarPrenda(
        _prenda('Saco', estaciones: [EstacionColor.otono]),
      );

      final inferiores = await repo.listarPrendas(
        filtro: const FiltroCatalogo(categoria: 'inferior'),
      );
      expect(inferiores.items.map((p) => p.nombre), ['Falda']);

      final otono = await repo.listarPrendas(
        filtro: const FiltroCatalogo(estacion: EstacionColor.otono),
      );
      expect(otono.items.map((p) => p.nombre), ['Saco']);
    });

    test('busca por inicio del nombre sin importar mayúsculas', () async {
      await repo.guardarProducto(_producto('Labial Rubí'));
      await repo.guardarProducto(_producto('Labial Coral'));
      await repo.guardarProducto(_producto('Rubor Durazno', categoria: 'rubor'));

      final pagina = await repo.listarProductos(
        filtro: const FiltroCatalogo(busqueda: 'LABIAL'),
      );
      expect(
        pagina.items.map((p) => p.nombre),
        ['Labial Coral', 'Labial Rubí'],
      );
    });

    test('pagina de a 20', () async {
      for (var i = 0; i < 25; i++) {
        await repo.guardarPrenda(_prenda('Prenda ${i.toString().padLeft(2, '0')}'));
      }
      final primera = await repo.listarPrendas();
      expect(primera.items, hasLength(20));
      expect(primera.hayMas, isTrue);

      final segunda = await repo.listarPrendas(despuesDe: primera.ultimo);
      expect(segunda.items, hasLength(5));
      expect(segunda.hayMas, isFalse);
      final ids = {...primera.items.map((p) => p.id), ...segunda.items.map((p) => p.id)};
      expect(ids, hasLength(25));
    });

    test('activar, desactivar y eliminar', () async {
      final id = await repo.guardarProducto(_producto('Labial'));
      await repo.cambiarActivoProducto(id, false);
      expect((await repo.obtenerProducto(id))!.activo, isFalse);

      final soloActivos = await repo.listarProductos(
        filtro: const FiltroCatalogo(soloActivos: true),
      );
      expect(soloActivos.items, isEmpty);

      await repo.eliminarProducto(id);
      expect(await repo.obtenerProducto(id), isNull);
    });
  });

  group('CatalogoAdminViewModel', () {
    test('carga prendas y luego productos al cambiar de pestaña', () async {
      await repo.guardarPrenda(_prenda('Blusa'));
      await repo.guardarProducto(_producto('Labial'));
      final vm = CatalogoAdminViewModel(repo);

      await vm.cargar();
      expect(vm.items.map((i) => i.nombre), ['Blusa']);

      vm.cambiarTipo(TipoCatalogo.productos);
      await Future<void>.delayed(Duration.zero);
      await pumpEventQueue();
      expect(vm.tipo, TipoCatalogo.productos);
      expect(vm.items.map((i) => i.nombre), ['Labial']);
      vm.dispose();
    });

    test('filtra por categoría y limpia filtros', () async {
      await repo.guardarPrenda(_prenda('Blusa'));
      await repo.guardarPrenda(_prenda('Falda', tipo: 'inferior'));
      final vm = CatalogoAdminViewModel(repo);
      await vm.cargar();
      expect(vm.items, hasLength(2));

      vm.cambiarCategoria('inferior');
      await pumpEventQueue();
      expect(vm.items.map((i) => i.nombre), ['Falda']);
      expect(vm.hayFiltros, isTrue);

      vm.limpiarFiltros();
      await pumpEventQueue();
      expect(vm.items, hasLength(2));
      expect(vm.hayFiltros, isFalse);
      vm.dispose();
    });

    test('cambiarActivo y eliminar actualizan la lista', () async {
      await repo.guardarPrenda(_prenda('Blusa'));
      final vm = CatalogoAdminViewModel(repo);
      await vm.cargar();
      final item = vm.items.single;

      expect(await vm.cambiarActivo(item), isNull);
      expect(vm.items.single.activo, isFalse);

      expect(await vm.eliminar(vm.items.single), isNull);
      expect(vm.items, isEmpty);
      expect((await db.collection(PrendaRopa.collection).get()).size, 0);
      vm.dispose();
    });
  });
}
