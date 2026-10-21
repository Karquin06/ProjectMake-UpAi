import 'dart:typed_data';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/data/datos/catalogo_ejemplo.dart';
import 'package:mackeupai/data/datos/imagen_catalogo.dart';
import 'package:mackeupai/data/repositories/catalogo_repository.dart';
import 'package:mackeupai/data/services/storage_service.dart';
import 'package:mackeupai/models/models.dart';
import 'package:mackeupai/ui/admin/catalogo_admin_view_model.dart';
import 'package:mackeupai/ui/admin/formulario_prenda_view_model.dart';
import 'package:mackeupai/ui/admin/formulario_producto_view_model.dart';
import 'package:mackeupai/ui/admin/widgets/marco_formulario_catalogo.dart';
import 'package:mackeupai/ui/admin/widgets/selector_color.dart';

/// Storage en memoria: guarda las rutas subidas y borradas.
class _StorageFalso extends Fake implements StorageService {
  final Map<String, Uint8List> archivos = {};
  final List<String> borrados = [];

  @override
  Future<String> subirArchivo(
    String ruta,
    Uint8List datos, {
    String contentType = 'image/jpeg',
    void Function(double progreso)? onProgreso,
  }) async {
    onProgreso?.call(0.5);
    archivos[ruta] = datos;
    onProgreso?.call(1);
    return ruta;
  }

  @override
  Future<String> obtenerUrl(String ruta) async => 'https://imagenes/$ruta';

  @override
  Future<void> borrar(String ruta) async {
    borrados.add(ruta);
    archivos.remove(ruta);
  }
}

// ---------------------------------------------------------------------------
// Copia de las reglas de Firestore del catálogo (productoValido y
// prendaValida). Si las reglas cambian, actualiza estas funciones.
// ---------------------------------------------------------------------------
const _subtonos = ['calido', 'frio', 'neutro'];
const _estaciones = ['primavera', 'verano', 'otono', 'invierno'];

bool _textoNoVacio(Object? v) => v is String && v.isNotEmpty;
bool _listaValida(Object? v, List<String> permitidos) =>
    v is List && v.isNotEmpty && v.every(permitidos.contains);

bool _productoValido(Map<String, dynamic> d) =>
    _textoNoVacio(d['marca']) &&
    _textoNoVacio(d['categoria']) &&
    d['precio'] is num &&
    (d['precio'] as num) >= 0 &&
    _listaValida(d['subtonoCompatible'], _subtonos) &&
    _listaValida(d['estacionesCompatibles'], _estaciones);

bool _prendaValida(Map<String, dynamic> d) =>
    _textoNoVacio(d['marca']) &&
    _textoNoVacio(d['tipoPrenda']) &&
    _textoNoVacio(d['colorPrincipal']) &&
    d['precio'] is num &&
    (d['precio'] as num) >= 0 &&
    _listaValida(d['estacionesCompatibles'], _estaciones);

/// Imagen PNG pequeña válida.
Uint8List _png() =>
    Uint8List.fromList(img.encodePng(img.Image(width: 20, height: 10)));

void main() {
  late FakeFirebaseFirestore db;
  late CatalogoRepository repo;
  late _StorageFalso storage;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = CatalogoRepository(db: db);
    storage = _StorageFalso();
  });

  group('FormularioPrendaViewModel', () {
    test('no guarda sin categoría, estación ni imagen y marca los errores',
        () async {
      final vm = FormularioPrendaViewModel(repo, storage);
      await vm.cargar();
      expect(vm.esNuevo, isTrue);
      expect(vm.errorCategoria, isNull); // Aún no intentó guardar.

      vm.cambiarNombre('Blusa');
      expect(await vm.guardar(), isFalse);
      expect(vm.errorCategoria, AppStrings.validacionCategoria);
      expect(vm.errorEstaciones, AppStrings.validacionEstaciones);
      expect(vm.errorImagen, AppStrings.validacionImagen);
      expect((await db.collection(PrendaRopa.collection).get()).size, 0);
      vm.dispose();
    });

    test('crea la prenda, sube la imagen y normaliza el color', () async {
      final vm = FormularioPrendaViewModel(repo, storage);
      await vm.cargar();
      vm
        ..cambiarNombre('  Blusa de lino ')
        ..cambiarDescripcion('Fresca')
        ..cambiarMarca('Lino & Co')
        ..cambiarColorPrincipal('Frambuesa')
        ..cambiarCategoria('superior')
        ..cambiarColor('c2185b')
        ..alternarOcasion('fiesta')
        ..alternarOcasion('trabajo')
        ..alternarEstacion(EstacionColor.verano)
        ..alternarEstacion(EstacionColor.invierno)
        ..alternarSubtono(Subtono.frio)
        ..cambiarPrecio('89900');
      await vm.seleccionarImagen(_png());
      expect(vm.imagenNueva, isNotNull);
      expect(vm.hayCambios, isTrue);

      expect(await vm.guardar(), isTrue);
      expect(vm.hayCambios, isFalse);

      final docs = (await db.collection(PrendaRopa.collection).get()).docs;
      expect(docs, hasLength(1));
      final p = PrendaRopa.fromFirestore(docs.single);
      expect(p.nombre, 'Blusa de lino');
      expect(p.marca, 'Lino & Co');
      expect(p.colorPrincipal, 'Frambuesa');
      // Cumple la regla prendaValida de Firestore.
      expect(_prendaValida(docs.single.data()), isTrue);
      expect(p.tipoPrenda, 'superior');
      expect(p.colorHex, '#C2185B');
      // Se guardan en el orden de las listas, no en el que se tocaron.
      expect(p.ocasiones, ['trabajo', 'fiesta']);
      expect(p.estacionesCompatibles,
          [EstacionColor.verano, EstacionColor.invierno]);
      expect(p.subtonosCompatibles, [Subtono.frio]);
      expect(p.precio, 89900);
      expect(p.activo, isTrue);
      expect(p.imagenRuta, startsWith('catalogo/prendas/${p.id}/'));
      expect(p.imagenUrl, 'https://imagenes/${p.imagenRuta}');
      expect(storage.archivos.keys, [p.imagenRuta]);
      vm.dispose();
    });

    test('al editar conserva los campos que el formulario no muestra',
        () async {
      final id = await repo.guardarPrenda(const PrendaRopa(
        id: '',
        nombre: 'Saco',
        marca: 'Zara',
        tipoPrenda: 'abrigo',
        colorPrincipal: 'Camel',
        colorHex: '#C19A6B',
        talla: 'M',
        material: 'Lana',
        estilo: 'Clásico',
        formalidad: 'Formal',
        estacionesCompatibles: [EstacionColor.otono],
        precio: 120000,
        imagenUrl: 'https://imagenes/vieja.jpg',
        imagenRuta: 'catalogo/prendas/x/vieja.jpg',
      ));
      final vm = FormularioPrendaViewModel(repo, storage, id: id);
      await vm.cargar();
      expect(vm.cargado, isTrue);
      expect(vm.nombre, 'Saco');
      expect(vm.categoria, 'abrigo');
      expect(vm.precio, '120000');
      expect(vm.hayCambios, isFalse);

      vm.cambiarNombre('Saco largo');
      vm.cambiarActivo(false);
      expect(await vm.guardar(), isTrue);

      final p = (await repo.obtenerPrenda(id))!;
      expect(p.nombre, 'Saco largo');
      expect(p.activo, isFalse);
      expect(p.talla, 'M');
      expect(p.material, 'Lana');
      // Sin imagen nueva no se sube ni se borra nada.
      expect(p.imagenRuta, 'catalogo/prendas/x/vieja.jpg');
      expect(storage.archivos, isEmpty);
      expect(storage.borrados, isEmpty);
      vm.dispose();
    });

    test('id que no existe → noEncontrado', () async {
      final vm = FormularioPrendaViewModel(repo, storage, id: 'no-existe');
      await vm.cargar();
      expect(vm.noEncontrado, isTrue);
      expect(vm.cargado, isFalse);
      vm.dispose();
    });

    test('rechaza imágenes que no son imágenes', () async {
      final vm = FormularioPrendaViewModel(repo, storage);
      await vm.cargar();
      await vm.seleccionarImagen(Uint8List.fromList([1, 2, 3]));
      expect(vm.imagenNueva, isNull);
      expect(vm.error, isNotNull);
      vm.dispose();
    });
  });

  group('FormularioProductoViewModel', () {
    test('reemplazar la imagen borra la anterior y quita el enlace', () async {
      final id = await repo.guardarProducto(const ProductoMaquillaje(
        id: '',
        nombre: 'Labial Rubí',
        marca: 'Mac',
        categoria: 'labial',
        tono: 'Ruby Woo',
        colorHex: '#B71C1C',
        acabado: 'Mate',
        estacionesCompatibles: [EstacionColor.invierno],
        subtonoCompatible: [Subtono.frio],
        precio: 95000,
        imagenUrl: 'https://imagenes/vieja.jpg',
        imagenRuta: 'catalogo/productos/x/vieja.jpg',
        enlace: 'https://tienda.com/rubi',
      ));
      final vm = FormularioProductoViewModel(repo, storage, id: id);
      await vm.cargar();
      expect(vm.enlace, 'https://tienda.com/rubi');

      await vm.seleccionarImagen(_png());
      vm.cambiarEnlace('');
      expect(await vm.guardar(), isTrue);

      final p = (await repo.obtenerProducto(id))!;
      expect(p.enlace, isNull);
      // Los campos opcionales vacíos no se escriben en Firestore.
      final datos = (await db
              .collection(ProductoMaquillaje.collection)
              .doc(id)
              .get())
          .data()!;
      expect(datos.containsKey('enlace'), isFalse);
      expect(datos.containsKey('codigoBarras'), isFalse);
      expect(datos['marca'], 'Mac');
      expect(datos['precio'], isA<num>());
      expect(datos['subtonoCompatible'], isA<List>());
      // Cumple la regla productoValido de Firestore.
      expect(_productoValido(datos), isTrue);
      expect(p.tono, 'Ruby Woo'); // Se conserva.
      expect(p.acabado, 'Mate'); // Se conserva.
      expect(p.imagenRuta, startsWith('catalogo/productos/$id/'));
      expect(storage.borrados, ['catalogo/productos/x/vieja.jpg']);
      vm.dispose();
    });
  });

  group('Reglas de Firestore', () {
    test('producto sin subtono o sin marca no se guarda', () async {
      final vm = FormularioProductoViewModel(repo, storage);
      await vm.cargar();
      vm
        ..cambiarNombre('Labial')
        ..cambiarCategoria('labial')
        ..cambiarColor('#C2185B')
        ..alternarEstacion(EstacionColor.invierno);
      await vm.seleccionarImagen(_png());

      expect(await vm.guardar(), isFalse);
      expect(vm.errorSubtonos, AppStrings.validacionSubtonos);

      vm.alternarSubtono(Subtono.frio);
      expect(await vm.guardar(), isFalse); // Falta la marca.

      vm.cambiarMarca('Lumina');
      expect(await vm.guardar(), isTrue);
      final docs = (await db.collection(ProductoMaquillaje.collection).get()).docs;
      expect(_productoValido(docs.single.data()), isTrue);
      vm.dispose();
    });

    test('prenda sin nombre del color no se guarda', () async {
      final vm = FormularioPrendaViewModel(repo, storage);
      await vm.cargar();
      vm
        ..cambiarNombre('Falda')
        ..cambiarMarca('Brisa')
        ..cambiarCategoria('inferior')
        ..cambiarColor('#D8A1B0')
        ..alternarEstacion(EstacionColor.verano);
      await vm.seleccionarImagen(_png());
      expect(vm.errorSubtonos, isNull); // En prendas es opcional.

      expect(await vm.guardar(), isFalse);
      vm.cambiarColorPrincipal('Rosa empolvado');
      expect(await vm.guardar(), isTrue);
      final docs = (await db.collection(PrendaRopa.collection).get()).docs;
      expect(_prendaValida(docs.single.data()), isTrue);
      vm.dispose();
    });
  });

  group('Catálogo de ejemplo', () {
    test('se carga de una vez, sin duplicar y cumpliendo las reglas', () async {
      final vm = CatalogoAdminViewModel(repo, storage);
      final r1 = await vm.cargarEjemplo();
      expect(r1.exito, isTrue);
      expect(r1.errorImagenes, isNull);
      // Todos traen foto real (Pexels): no hace falta generar ni subir nada.
      expect(storage.archivos, isEmpty);

      // Segunda vez: no duplica.
      expect((await vm.cargarEjemplo()).exito, isTrue);

      final prendas = (await db.collection(PrendaRopa.collection).get()).docs;
      final productos =
          (await db.collection(ProductoMaquillaje.collection).get()).docs;
      expect(prendas, hasLength(CatalogoEjemplo.prendas.length));
      expect(productos, hasLength(CatalogoEjemplo.productos.length));
      for (final d in prendas) {
        expect(_prendaValida(d.data()), isTrue, reason: d.id);
        expect(
          d.data()['imagenURL'],
          startsWith('https://images.pexels.com/photos/'),
          reason: d.id,
        );
      }
      for (final d in productos) {
        expect(_productoValido(d.data()), isTrue, reason: d.id);
      }
      // La lista de la pestaña actual (prendas) ya se recargó (primera
      // página: el catálogo se pide de a CatalogoRepository.tamanoPagina).
      expect(
        vm.items,
        hasLength(
          CatalogoEjemplo.prendas.length < CatalogoRepository.tamanoPagina
              ? CatalogoEjemplo.prendas.length
              : CatalogoRepository.tamanoPagina,
        ),
      );
      vm.dispose();
    });

    test('respeta la foto guardada en Storage (Editar o script)', () async {
      final vm = CatalogoAdminViewModel(repo, storage);
      await vm.cargarEjemplo();
      final id = CatalogoEjemplo.productos.first.id;
      final p = (await repo.obtenerProducto(id))!;
      await repo.guardarProducto(p.copyWith(
        imagenUrl: 'https://imagenes/foto-real.jpg',
        imagenRuta: 'catalogo/productos/$id/123.jpg',
      ));

      await vm.cargarEjemplo();
      expect((await repo.obtenerProducto(id))!.imagenUrl,
          'https://imagenes/foto-real.jpg');

      // También la copia que guarda el script en Storage (ejemplo.jpg).
      final otro = CatalogoEjemplo.prendas.first.id;
      final prenda = (await repo.obtenerPrenda(otro))!;
      await repo.guardarPrenda(prenda.copyWith(
        imagenUrl: 'https://storage/copia.jpg',
        imagenRuta: CatalogoRepository.rutaImagenEjemplo('prendas', otro),
      ));
      await vm.cargarEjemplo();
      expect((await repo.obtenerPrenda(otro))!.imagenUrl,
          'https://storage/copia.jpg');
      vm.dispose();
    });

    test('genera un JPEG válido para cada categoría', () async {
      for (final c in [...PrendaRopa.categorias, ...ProductoMaquillaje.categorias]) {
        final bytes = await ImagenCatalogo.generar(
          categoria: c,
          colorHex: '#C2185B',
          estaciones: EstacionColor.values,
          marca: "L'Oréal Paris",
        );
        final decodificada = img.decodeJpg(bytes);
        expect(decodificada, isNotNull, reason: c);
        expect(decodificada!.width, ImagenCatalogo.lado);
      }
    });

    test('incluye las marcas pedidas y todas las estaciones', () {
      final marcas = CatalogoEjemplo.productos.map((p) => p.marca).toSet();
      expect(
        marcas,
        containsAll(['L\'Oréal Paris', 'MAC', 'Maybelline', 'Bloomshell']),
      );
      for (final e in EstacionColor.values) {
        expect(
          CatalogoEjemplo.prendas.any((p) => p.estacionesCompatibles.contains(e)),
          isTrue,
        );
        expect(
          CatalogoEjemplo.productos
              .any((p) => p.estacionesCompatibles.contains(e)),
          isTrue,
        );
      }
    });
  });

  group('Validadores del formulario', () {
    test('color HEX', () {
      expect(SelectorColor.validar('#C2185B'), isNull);
      expect(SelectorColor.validar('c2185b'), isNull);
      expect(SelectorColor.validar('#E54'), isNull);
      expect(SelectorColor.validar(''), AppStrings.validacionObligatorio);
      expect(SelectorColor.validar('rojo'), AppStrings.validacionColor);
    });

    test('precio y enlace opcionales', () {
      expect(ValidadoresCatalogo.precio(''), isNull);
      expect(ValidadoresCatalogo.precio('45900'), isNull);
      expect(ValidadoresCatalogo.precio('12,50'), isNull);
      expect(ValidadoresCatalogo.precio('abc'), AppStrings.validacionPrecio);
      expect(ValidadoresCatalogo.enlace(''), isNull);
      expect(ValidadoresCatalogo.enlace('https://tienda.com'), isNull);
      expect(ValidadoresCatalogo.enlace('tienda.com'),
          AppStrings.validacionEnlace);
    });
  });
}
