import 'dart:typed_data';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/core/errors/app_exception.dart';
import 'package:mackeupai/core/utils/importador_productos.dart';
import 'package:mackeupai/data/repositories/catalogo_repository.dart';
import 'package:mackeupai/data/repositories/marca_repository.dart';
import 'package:mackeupai/data/repositories/me_gusta_repository.dart';
import 'package:mackeupai/data/services/marcas_service.dart';
import 'package:mackeupai/data/services/storage_service.dart';
import 'package:mackeupai/models/models.dart';
import 'package:mackeupai/providers/me_gusta_provider.dart';
import 'package:mackeupai/ui/admin/formulario_producto_view_model.dart';
import 'package:mackeupai/ui/marcas/formulario_marca_view_model.dart';
import 'package:mackeupai/ui/marcas/importar_productos_view_model.dart';
import 'package:mackeupai/ui/marcas/marcas_admin_view_model.dart';
import 'package:mackeupai/ui/marcas/mi_marca_view_model.dart';
import 'package:mackeupai/ui/marcas/widgets/elementos_panel.dart';

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
    archivos[ruta] = datos;
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

/// Cloud Functions de marcas sin red.
class _MarcasFalso extends Fake implements MarcasService {
  final List<(String, String?)> asignaciones = [];
  Object? error;
  ResumenMarca? resumen;
  String? marcaPedida;

  @override
  Future<AsignacionMarca> asignarAdminMarca({
    required String correo,
    required String? marcaId,
  }) async {
    if (error != null) throw error!;
    asignaciones.add((correo, marcaId));
    return AsignacionMarca(uid: 'u', correo: correo, marcaId: marcaId);
  }

  @override
  Future<ResumenMarca> resumenMarca({String? marcaId}) async {
    marcaPedida = marcaId;
    if (error != null) throw error!;
    return resumen!;
  }
}

/// Deja correr las tareas pendientes (microtareas y Firestore falso).
Future<void> _esperar() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Uint8List _png() =>
    Uint8List.fromList(img.encodePng(img.Image(width: 20, height: 10)));

/// Respuesta de `resumenMarca` tal como la manda la Cloud Function.
Map<String, dynamic> _respuestaResumen() => {
      'marca': {'id': 'm1', 'nombre': 'Glow Studio', 'logoURL': '', 'colorHex': '#C2185B'},
      'totales': {
        'productos': 3,
        'gusta': 12,
        'corazones': 8,
        'calificaciones': 6,
        'promedio': 4.5,
        'vistas': 40,
        'pruebasAr': 9,
        'porEstacion': {'primavera': 2, 'verano': 1, 'otono': 0, 'invierno': 9},
      },
      'productos': [
        {'id': 'p1', 'nombre': 'Labial Rubí', 'gusta': 9, 'vistas': 20, 'promedio': 4.8},
        {'id': 'p2', 'nombre': 'Rubor Coral', 'gusta': 3, 'vistas': 0},
        {'id': 'p3', 'nombre': 'Sombra Nueva', 'gusta': 0, 'activo': false},
      ],
    };

void main() {
  group('Modelos', () {
    test('Marca: ida y vuelta, iniciales y admins no se escriben', () {
      final m = Marca.fromMap({
        'nombre': "L'Oréal Paris",
        'colorHex': '#C2185B',
        'logoURL': 'https://logo',
        'activa': false,
        'admins': ['ana@x.com', 3],
      }, id: 'm1');
      expect(m.iniciales, 'LP');
      expect(m.admins, ['ana@x.com']);
      expect(m.activa, isFalse);
      final mapa = m.toMap();
      expect(mapa['nombreMinusculas'], "l'oréal paris");
      expect(mapa['logoURL'], 'https://logo');
      expect(mapa.containsKey('admins'), isFalse);
      expect(mapa.containsKey('sitioWeb'), isFalse);
    });

    test('ResumenMarca: totales, estación favorita y top sin ceros', () {
      final r = ResumenMarca.fromMap(_respuestaResumen());
      expect(r.nombre, 'Glow Studio');
      expect(r.totales.gusta, 12);
      expect(r.totales.promedio, 4.5);
      expect(r.totales.estacionFavorita, EstacionColor.invierno);
      expect(r.productos, hasLength(3));
      expect(r.top.map((p) => p.id), ['p1', 'p2']);
      expect(r.productos.first.conversion, 45);
      expect(r.productos[1].conversion, 0); // Sin vistas no divide por 0.
      expect(r.productos.last.activo, isFalse);
    });

    test('ResumenMarca vacío no falla y no tiene favorita', () {
      final r = ResumenMarca.fromMap(const {});
      expect(r.totales.estacionFavorita, isNull);
      expect(r.totales.porEstacion[EstacionColor.verano], 0);
      expect(r.top, isEmpty);
    });

    test('ResumenAdmin: totales, estaciones y ranking', () {
      final r = ResumenAdmin.fromMap({
        'totales': {'usuarias': 8, 'conAnalisis': 6, 'productos': 30, 'prendas': 20, 'marcas': 2},
        'usuariasPorEstacion': {'primavera': 3, 'invierno': 3},
        'topProductos': [
          {'id': 'p1', 'nombre': 'Labial', 'gusta': 5},
        ],
        'marcas': [
          {'id': 'm1', 'nombre': 'Glow', 'gusta': 5, 'admins': 1, 'activa': true},
        ],
      });
      expect(r.porcentajeConAnalisis, 75);
      expect(r.usuariasPorEstacion[EstacionColor.otono], 0);
      expect(r.topProductos.single.gusta, 5);
      expect(r.ranking.single.admins, 1);
    });

    test('Usuaria: rol marca solo cuenta con marcaId', () {
      final conMarca = Usuaria.fromMap(
        {'rol': Usuaria.rolMarca, 'marcaId': 'm1'},
        id: 'u1',
      );
      expect(conMarca.esAdminMarca, isTrue);
      expect(conMarca.esAdmin, isFalse);
      expect(conMarca.copyWith(nombre: 'Ana').marcaId, 'm1');
      // marcaId no se escribe desde la app (lo pone la Cloud Function).
      expect(conMarca.toMap().containsKey('marcaId'), isFalse);
      expect(
        Usuaria.fromMap({'rol': Usuaria.rolMarca}, id: 'u2').esAdminMarca,
        isFalse,
      );
    });

    test('ProductoMaquillaje guarda y lee marcaId; vacío = sin marca', () {
      const p = ProductoMaquillaje(
        id: 'p1',
        marca: 'Glow',
        marcaId: 'm1',
        categoria: 'labial',
        tono: 'Rubí',
        acabado: 'Mate',
        precio: 0,
        imagenUrl: '',
      );
      expect(p.toMap()['marcaId'], 'm1');
      expect(ProductoMaquillaje.fromMap(p.toMap(), id: 'p1').marcaId, 'm1');
      expect(
        ProductoMaquillaje.fromMap({'marcaId': ''}, id: 'p2').marcaId,
        isNull,
      );
      expect(p.copyWith(marca: 'Otra').marcaId, 'm1');
    });

    test('Formatos del panel', () {
      expect(numeroCorto(950), '950');
      expect(numeroCorto(1200), '1,2 k');
      expect(numeroCorto(3400000), '3,4 M');
      expect(promedioTexto(0), '—');
      expect(promedioTexto(4.56), '4,6');
    });
  });

  group('MarcaRepository', () {
    late FakeFirebaseFirestore db;
    late MarcaRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = MarcaRepository(db: db);
    });

    test('crear, listar ordenado, activar y editar el perfil', () async {
      await repo.crear(const Marca(id: '', nombre: 'Zafiro'));
      final id = await repo.crear(const Marca(id: '', nombre: 'aurora', sitioWeb: 'https://a.co'));

      final lista = await repo.listar();
      expect(lista.map((m) => m.nombre), ['aurora', 'Zafiro']);
      final datos = (await db.collection(Marca.collection).doc(id).get()).data()!;
      expect(datos['admins'], isEmpty);
      expect(datos['activa'], isTrue);

      await repo.cambiarActiva(id, false);
      expect(await repo.activas(), hasLength(1));

      await repo.actualizarPerfil(id, descripcion: 'Hola', colorHex: '#000000');
      final m = (await repo.obtener(id))!;
      expect(m.descripcion, 'Hola');
      expect(m.nombre, 'aurora'); // El perfil no toca el nombre.
      expect(m.sitioWeb, isNull); // Se borró el sitio web.
    });
  });

  group('Me gusta ❤️', () {
    test('marcar y quitar guarda el formato que piden las reglas', () async {
      final db = FakeFirebaseFirestore();
      final repo = MeGustaRepository(db: db);
      await repo.marcar('u1', 'p1');
      final doc = await db.doc('usuarias/u1/meGusta/p1').get();
      expect(doc.data()!['uid'], 'u1');
      expect(doc.data()!['itemId'], 'p1');
      expect(doc.data()!['tipo'], 'producto');
      expect(await repo.productos('u1'), {'p1'});
      await repo.quitar('u1', 'p1');
      expect(await repo.productos('u1'), isEmpty);
    });

    test('el provider alterna, se carga al iniciar y se limpia al salir', () async {
      final db = FakeFirebaseFirestore();
      await db.doc('usuarias/u1/meGusta/p9').set({
        'uid': 'u1',
        'itemId': 'p9',
        'tipo': 'producto',
      });
      final p = MeGustaProvider(MeGustaRepository(db: db));
      p.sincronizarUsuaria('u1');
      await _esperar();
      expect(p.leGusta('p9'), isTrue);

      expect(await p.alternar('p1'), isNull);
      expect(p.leGusta('p1'), isTrue);
      expect((await db.doc('usuarias/u1/meGusta/p1').get()).exists, isTrue);
      expect(await p.alternar('p1'), isNull);
      expect(p.leGusta('p1'), isFalse);

      p.sincronizarUsuaria(null);
      await _esperar();
      expect(p.ids, isEmpty);
      p.dispose();
    });
  });

  group('Productos de una marca', () {
    late FakeFirebaseFirestore db;
    late CatalogoRepository repo;
    late _StorageFalso storage;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = CatalogoRepository(db: db);
      storage = _StorageFalso();
    });

    Future<FormularioProductoViewModel> llenar(FormularioProductoViewModel vm) async {
      await vm.cargar();
      vm
        ..cambiarNombre('Labial Glow')
        ..cambiarCategoria('labial')
        ..cambiarColor('#C2185B')
        ..alternarEstacion(EstacionColor.invierno)
        ..alternarSubtono(Subtono.frio);
      await vm.seleccionarImagen(_png());
      return vm;
    }

    test('desde el panel queda amarrado a la marca y su carpeta', () async {
      final vm = await llenar(
        FormularioProductoViewModel(
          repo,
          storage,
          marcaFija: const ArgumentosProductoMarca(marcaId: 'm1', marcaNombre: 'Glow'),
        ),
      );
      expect(vm.marcaBloqueada, isTrue);
      expect(vm.marca, 'Glow');
      expect(await vm.guardar(), isTrue);

      final lista = await repo.productosDeMarca('m1');
      expect(lista.single.marcaId, 'm1');
      expect(lista.single.marca, 'Glow');
      expect(lista.single.imagenRuta, startsWith('catalogo/marcas/m1/'));
      expect(await repo.productosDeMarca('otra'), isEmpty);
      vm.dispose();
    });

    test('el panel de una marca no abre productos de otra', () async {
      final id = await repo.guardarProducto(
        const ProductoMaquillaje(
          id: '',
          marca: 'Otra',
          marcaId: 'm2',
          categoria: 'labial',
          tono: 'x',
          acabado: '',
          precio: 0,
          imagenUrl: '',
        ),
      );
      final vm = FormularioProductoViewModel(
        repo,
        storage,
        marcaFija: ArgumentosProductoMarca(id: id, marcaId: 'm1', marcaNombre: 'Glow'),
      );
      await vm.cargar();
      expect(vm.noEncontrado, isTrue);
      vm.dispose();
    });

    test('la admin puede asociar un producto del catálogo a una marca', () async {
      final marcas = MarcaRepository(db: db);
      final idMarca = await marcas.crear(const Marca(id: '', nombre: 'Glow'));
      final vm = FormularioProductoViewModel(repo, storage, marcas: marcas);
      await llenar(vm);
      await vm.cargarMarcas();
      expect(vm.marcasDisponibles.single.nombre, 'Glow');
      vm.seleccionarMarca(vm.marcasDisponibles.single);
      expect(vm.marca, 'Glow');
      expect(await vm.guardar(), isTrue);
      expect((await repo.productosDeMarca(idMarca)), hasLength(1));
      vm.dispose();
    });
  });

  group('FormularioMarcaViewModel', () {
    late FakeFirebaseFirestore db;
    late MarcaRepository repo;
    late _StorageFalso storage;
    late _MarcasFalso funciones;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = MarcaRepository(db: db);
      storage = _StorageFalso();
      funciones = _MarcasFalso();
    });

    test('crear con logo, luego asignar y quitar una administradora', () async {
      final vm = FormularioMarcaViewModel(repo, storage, funciones);
      await vm.cargar();
      expect(vm.esNueva, isTrue);
      expect(await vm.asignarAdmin('a@b.co'), AppStrings.guardaMarcaPrimero);

      vm
        ..cambiarNombre('  Glow Studio ')
        ..cambiarColor('c2185b');
      await vm.seleccionarLogo(_png());
      expect(await vm.guardar(), isTrue);
      expect(vm.esNueva, isFalse);

      final m = (await repo.obtener(vm.id!))!;
      expect(m.nombre, 'Glow Studio');
      expect(m.colorHex, '#C2185B');
      expect(m.logoRuta, startsWith('catalogo/marcas/${vm.id}/logo/'));
      expect(storage.archivos.keys.single, m.logoRuta);

      expect(await vm.asignarAdmin('Ana@Marca.co'), isNull);
      expect(funciones.asignaciones.last, ('Ana@Marca.co', vm.id));
      expect(await vm.quitarAdmin('ana@marca.co'), isNull);
      expect(funciones.asignaciones.last.$2, isNull);
      vm.dispose();
    });

    test('el error de la función llega como mensaje', () async {
      final id = await repo.crear(const Marca(id: '', nombre: 'Glow'));
      funciones.error = const AppException(AppStrings.errorCuentaNoExiste);
      final vm = FormularioMarcaViewModel(repo, storage, funciones, idInicial: id);
      await vm.cargar();
      expect(await vm.asignarAdmin('nadie@x.co'), AppStrings.errorCuentaNoExiste);
      expect(vm.asignando, isFalse);
      vm.dispose();
    });

    test('el admin de la marca solo cambia su perfil', () async {
      final id = await repo.crear(const Marca(id: '', nombre: 'Glow'));
      final vm = FormularioMarcaViewModel(
        repo,
        storage,
        funciones,
        idInicial: id,
        soloPerfil: true,
      );
      await vm.cargar();
      vm
        ..cambiarNombre('Otro nombre') // La vista lo bloquea; no se guarda.
        ..cambiarDescripcion('Maquillaje vegano')
        ..cambiarSitioWeb('https://glow.co');
      expect(await vm.guardar(), isTrue);
      final m = (await repo.obtener(id))!;
      expect(m.nombre, 'Glow');
      expect(m.descripcion, 'Maquillaje vegano');
      expect(m.sitioWeb, 'https://glow.co');
      vm.dispose();
    });

    test('marca que no existe', () async {
      final vm = FormularioMarcaViewModel(repo, storage, funciones, idInicial: 'nope');
      await vm.cargar();
      expect(vm.noEncontrada, isTrue);
      vm.dispose();
    });
  });

  group('Paneles', () {
    test('MarcasAdminViewModel busca y revierte si falla activar', () async {
      final db = FakeFirebaseFirestore();
      final repo = MarcaRepository(db: db);
      await repo.crear(const Marca(id: '', nombre: 'Glow'));
      await repo.crear(const Marca(id: '', nombre: 'Aurora'));
      final vm = MarcasAdminViewModel(repo);
      await vm.cargar();
      expect(vm.total, 2);
      vm.buscar('glo');
      expect(vm.marcas.single.nombre, 'Glow');
      expect(await vm.cambiarActiva(vm.marcas.single, false), isNull);
      expect(vm.activas, 1);
      vm.dispose();
    });

    test('MiMarcaViewModel carga el resumen o muestra el error', () async {
      final funciones = _MarcasFalso()
        ..resumen = ResumenMarca.fromMap(_respuestaResumen());
      final vm = MiMarcaViewModel(funciones, marcaId: 'm1');
      await vm.cargar();
      expect(funciones.marcaPedida, 'm1');
      expect(vm.resumen!.totales.gusta, 12);
      expect(vm.sinDatos, isFalse);

      funciones.error = const AppException(AppStrings.errorSinMarca);
      await vm.cargar();
      expect(vm.error, AppStrings.errorSinMarca);
      vm.dispose();
    });
  });

  group('Importar productos', () {
    ResultadoImportacion analizar(String t) =>
        ImportadorProductos.analizar(t, marcaId: 'm1', marcaNombre: 'Glow');

    test('la plantilla se importa completa y sin errores', () {
      final r = analizar(ImportadorProductos.plantilla);
      expect(r.errorGeneral, isNull);
      expect(r.conErrores, isEmpty);
      expect(r.productos, hasLength(2));
      final p = r.productos.first;
      expect(p.marca, 'Glow');
      expect(p.marcaId, 'm1');
      expect(p.categoria, 'labial');
      expect(p.colorHex, '#9B111E');
      expect(p.estacionesCompatibles, [EstacionColor.verano, EstacionColor.invierno]);
      expect(p.subtonoCompatible, [Subtono.frio, Subtono.neutro]);
      expect(p.precio, 45900);
      expect(p.imagenUrl, 'https://ejemplo.com/rubi.jpg');
      expect(p.enlace, isNull);
      expect(r.productos.last.estacionesCompatibles,
          [EstacionColor.primavera, EstacionColor.otono]);
    });

    test('pegado desde Excel (tabulaciones), tildes y sinónimos', () {
      final r = analizar(
        'Producto\tTipo\tColor HEX\tEstación\tSubtono\tValor\tFoto\n'
        'Base Natural\tBases\tc9a37a\tTodas\tCálido y Neutro\t\$ 89.900\t\n'
        'Sombra Bronce\tSombras de ojos\t#9C6B3E\tOtoño / Primavera\tcálido\t62.500,50\t\n',
      );
      expect(r.conErrores, isEmpty);
      expect(r.productos.first.categoria, 'base');
      expect(r.productos.first.colorHex, '#C9A37A');
      expect(r.productos.first.estacionesCompatibles, EstacionColor.values);
      expect(r.productos.first.subtonoCompatible, [Subtono.calido, Subtono.neutro]);
      expect(r.productos.first.precio, 89900);
      expect(r.productos.last.categoria, 'sombra');
      expect(r.productos.last.precio, 62500.5);
    });

    test('CSV con comas y comillas', () {
      final r = analizar(
        'nombre,categoria,color,estaciones,subtonos,descripcion\n'
        '"Labial, edición especial",labial,#C8102E,invierno,frio,"Rojo ""clásico"""\n',
      );
      expect(r.productos.single.nombre, 'Labial, edición especial');
      expect(r.productos.single.descripcion, 'Rojo "clásico"');
      expect(r.productos.single.precio, 0);
    });

    test('marca los errores de cada fila y los repetidos', () {
      final r = analizar(
        'nombre;categoria;color;estaciones;subtonos;precio;imagen\n'
        ';pestañina;rojo;;;abc;foto.jpg\n'
        'Labial A;labial;#C8102E;invierno;frio;;\n'
        'labial a;labial;#C8102E;invierno;frio;;\n',
      );
      expect(r.validas, hasLength(1));
      final mala = r.conErrores.first;
      expect(mala.numero, 1);
      expect(mala.errores, hasLength(7));
      expect(r.conErrores.last.errores.single, contains('repetido'));
    });

    test('errores generales: vacío, sin datos o sin columnas obligatorias', () {
      expect(analizar('  ').errorGeneral, isNotNull);
      expect(analizar('nombre;categoria').errorGeneral, isNotNull);
      expect(
        analizar('nombre;categoria\nA;labial').errorGeneral,
        contains('color'),
      );
    });

    test('precios en formatos de Colombia', () {
      expect(ImportadorProductos.precioDesde('45.900'), 45900);
      expect(ImportadorProductos.precioDesde('\$ 1.250.000'), 1250000);
      expect(ImportadorProductos.precioDesde('45900'), 45900);
      expect(ImportadorProductos.precioDesde('12,5'), 12.5);
      expect(ImportadorProductos.precioDesde(''), 0);
      expect(ImportadorProductos.precioDesde('-3'), isNull);
    });

    test('el view model salta los que ya existen y sube el resto', () async {
      final db = FakeFirebaseFirestore();
      final repo = CatalogoRepository(db: db);
      await repo.guardarProducto(
        const ProductoMaquillaje(
          id: '',
          nombre: 'Labial Rubí Intenso',
          marca: 'Glow',
          marcaId: 'm1',
          categoria: 'labial',
          tono: 'Rubí',
          acabado: '',
          precio: 0,
          imagenUrl: '',
        ),
      );
      final vm = ImportarProductosViewModel(
        repo,
        const ArgumentosProductoMarca(marcaId: 'm1', marcaNombre: 'Glow'),
      );
      vm.cambiarTexto(ImportadorProductos.plantilla);
      await vm.revisar();
      expect(vm.resultado!.conErrores.single.errores.single, contains('Ya existe'));
      expect(vm.totalAImportar, 1);

      expect(await vm.importar(), isTrue);
      expect(vm.guardados, 1);
      final productos = await repo.productosDeMarca('m1');
      expect(productos.map((p) => p.nombre), ['Labial Rubí Intenso', 'Rubor Durazno']);
      expect(productos.last.marcaId, 'm1');

      // Cambiar el texto borra la revisión anterior.
      vm.cambiarTexto('otra cosa');
      expect(vm.resultado, isNull);
      vm.dispose();
    });
  });
}
