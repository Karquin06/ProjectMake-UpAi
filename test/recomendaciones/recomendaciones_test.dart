import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/core/constants/app_strings.dart';
import 'package:mackeupai/core/errors/app_exception.dart';
import 'package:mackeupai/data/datos/catalogo_ejemplo.dart';
import 'package:mackeupai/data/repositories/catalogo_repository.dart';
import 'package:mackeupai/data/repositories/perfil_colorimetria_repository.dart';
import 'package:mackeupai/data/repositories/recomendacion_repository.dart';
import 'package:mackeupai/data/services/colorimetria_mock_service.dart';
import 'package:mackeupai/data/services/funciones_ia_service.dart';
import 'package:mackeupai/models/models.dart';
import 'package:mackeupai/providers/colorimetria_provider.dart';
import 'package:mackeupai/providers/recomendacion_provider.dart';
import 'package:mackeupai/ui/recomendaciones/detalle_recomendacion_view_model.dart';
import 'package:mackeupai/ui/recomendaciones/esperar_perfil.dart';
import 'package:mackeupai/ui/recomendaciones/recomendaciones_view.dart';
import 'package:mackeupai/ui/recomendaciones/recomendaciones_view_model.dart';
import 'package:mackeupai/ui/recomendaciones/widgets/etiqueta_compatibilidad.dart';
import 'package:provider/provider.dart';

/// Cloud Functions sin desplegar (como hoy, sin plan Blaze): la app
/// calcula las recomendaciones en el teléfono.
class _FuncionesSinDesplegar extends Fake implements FuncionesIaService {
  final String codigo;

  _FuncionesSinDesplegar([this.codigo = CodigosFuncionesIa.noDesplegada]);

  @override
  Future<List<RecomendacionGenerada>> generarRecomendaciones({
    required TipoRecomendacion tipo,
    String? ocasion,
    int limite = 20,
  }) async =>
      throw AppException('Sin servidor', codigo: codigo);
}

class _Entorno {
  final db = FakeFirebaseFirestore();
  late final catalogo = CatalogoRepository(db: db);
  late final perfiles = PerfilColorimetriaRepository(db: db);
  late final guardadas = RecomendacionRepository(db: db);
  late final ColorimetriaProvider colorimetria;
  late final RecomendacionProvider recomendaciones;

  _Entorno({FuncionesIaService? funciones}) {
    colorimetria = ColorimetriaProvider(perfiles);
    recomendaciones = RecomendacionProvider(
      funciones: funciones ?? _FuncionesSinDesplegar(),
      catalogo: catalogo,
      recomendaciones: guardadas,
    );
  }

  /// Inicia la sesión de 'u1' (después de guardar sus datos) y espera a
  /// que cargue su colorimetría, como pasa en la app.
  Future<void> iniciarSesion() async {
    colorimetria.sincronizarUsuaria('u1');
    recomendaciones.sincronizarUsuaria('u1');
    await esperarPerfil(colorimetria);
  }

  /// Catálogo de ejemplo sin fotos (las pruebas no tienen internet).
  Future<void> sembrar({bool conPerfil = true}) async {
    await catalogo.guardarLote(
      prendas: [
        for (final p in CatalogoEjemplo.prendas) p.copyWith(imagenUrl: ''),
      ],
      productos: [
        for (final p in CatalogoEjemplo.productos) p.copyWith(imagenUrl: ''),
      ],
    );
    if (conPerfil) {
      // Invierno, subtono frío.
      await perfiles.guardarPerfil(ColorimetriaMockService.perfilEjemplo('u1'));
    }
    await iniciarSesion();
  }

  RecomendacionesViewModel vm({TipoRecomendacion? tipo}) =>
      RecomendacionesViewModel(colorimetria, recomendaciones, tipoInicial: tipo);
}

bool _ordenadas(List<RecomendacionItem> items) {
  for (var i = 1; i < items.length; i++) {
    if (items[i].puntaje > items[i - 1].puntaje) return false;
  }
  return true;
}

void main() {
  group('RecomendacionesViewModel', () {
    test('sin análisis invita a hacer la colorimetría', () async {
      final e = _Entorno();
      await e.sembrar(conPerfil: false);
      final vm = e.vm();
      await vm.cargar();
      expect(vm.estado, EstadoRecomendaciones.sinPerfil);
      expect(vm.items, isEmpty);
      vm.dispose();
    });

    test('maquillaje: lista ordenada por compatibilidad con el catálogo directo',
        () async {
      final e = _Entorno();
      await e.sembrar();
      final vm = e.vm();
      await vm.cargar();
      expect(vm.estado, EstadoRecomendaciones.conDatos);
      expect(vm.tipo, TipoRecomendacion.maquillaje);
      expect(vm.items, isNotEmpty);
      expect(vm.items.every((i) => !i.esPrenda), isTrue);
      expect(_ordenadas(vm.items), isTrue);
      expect(vm.usandoRespaldo, isTrue);
      // La primera es de su estación (Invierno).
      expect(
        vm.items.first.producto!.estacionesCompatibles,
        contains(EstacionColor.invierno),
      );
      expect(vm.items.first.motivo, isNotEmpty);
      vm.dispose();
    });

    test('ropa con filtro de ocasión', () async {
      final e = _Entorno();
      await e.sembrar();
      final vm = e.vm(tipo: TipoRecomendacion.outfit);
      await vm.cargar();
      expect(vm.esRopa, isTrue);
      expect(vm.items.every((i) => i.esPrenda), isTrue);

      vm.cambiarOcasion('fiesta');
      await vm.cargar();
      expect(vm.ocasion, 'fiesta');
      expect(vm.estado, EstadoRecomendaciones.conDatos);
      expect(_ordenadas(vm.items), isTrue);

      // En deporte solo salen prendas de deporte (nada de blazers).
      vm.cambiarOcasion('deporte');
      await vm.cargar();
      expect(vm.items, isNotEmpty);
      expect(
        vm.items.every((i) => i.prenda!.ocasiones.contains('deporte')),
        isTrue,
      );

      vm.cambiarTipo(TipoRecomendacion.maquillaje);
      await vm.cargar();
      expect(vm.items.every((i) => !i.esPrenda), isTrue);
      vm.dispose();
    });

    test('catálogo vacío muestra el estado vacío', () async {
      final e = _Entorno();
      await e.perfiles
          .guardarPerfil(ColorimetriaMockService.perfilEjemplo('u1'));
      await e.iniciarSesion();
      final vm = e.vm();
      await vm.cargar();
      expect(vm.estado, EstadoRecomendaciones.vacio);
      vm.dispose();
    });

    test('error del servidor (no de despliegue) muestra el error', () async {
      final e = _Entorno(funciones: _FuncionesSinDesplegar('otro-error'));
      await e.sembrar();
      final vm = e.vm();
      await vm.cargar();
      expect(vm.estado, EstadoRecomendaciones.error);
      expect(vm.error, 'Sin servidor');
      vm.dispose();
    });
  });

  group('DetalleRecomendacionViewModel', () {
    test('abre un producto directo y guarda la calificación', () async {
      final e = _Entorno();
      await e.sembrar();
      final id = CatalogoEjemplo.productos.first.id;
      final vm = DetalleRecomendacionViewModel(
        recomendaciones: e.recomendaciones,
        catalogo: e.catalogo,
        colorimetria: e.colorimetria,
        id: id,
        esPrenda: false,
      );
      await vm.cargar();
      expect(vm.estado, EstadoDetalle.listo);
      expect(vm.item!.producto!.id, id);
      expect(vm.item!.calificacion, isNull);

      expect(await vm.calificar(5), isNull);
      expect(vm.item!.calificacion, 5);
      final guardadas = await e.guardadas.obtenerCalificaciones('u1');
      expect(guardadas[id], 5);
      final doc = await e.db
          .collection('usuarias')
          .doc('u1')
          .collection(Recomendacion.coleccion)
          .doc(id)
          .get();
      // Las reglas exigen productoId XOR prendaId y el uid.
      expect(doc.data()!['productoId'], id);
      expect(doc.data()!['prendaId'], isNull);
      expect(doc.data()!['uid'], 'u1');
      vm.dispose();
    });

    test('la calificación sube el puntaje en la siguiente carga', () async {
      final e = _Entorno();
      await e.sembrar();
      final lista = e.vm();
      await lista.cargar();
      final item = lista.items.last;
      final antes = item.puntaje;
      await e.recomendaciones.calificar(item, 5);
      await lista.refrescar();
      final despues = lista.items.firstWhere((i) => i.id == item.id);
      expect(despues.calificacion, 5);
      expect(despues.puntaje, greaterThanOrEqualTo(antes));
      lista.dispose();
    });

    test('ítem inexistente o sin id: no disponible', () async {
      final e = _Entorno();
      await e.sembrar();
      for (final id in ['no-existe', null]) {
        final vm = DetalleRecomendacionViewModel(
          recomendaciones: e.recomendaciones,
          catalogo: e.catalogo,
          colorimetria: e.colorimetria,
          id: id,
          esPrenda: true,
        );
        await vm.cargar();
        expect(vm.estado, EstadoDetalle.noDisponible);
        vm.dispose();
      }
    });
  });

  test('niveles de compatibilidad', () {
    expect(EtiquetaCompatibilidad.nivel(90), AppStrings.compatibilidadAlta);
    expect(EtiquetaCompatibilidad.nivel(60), AppStrings.compatibilidadMedia);
    expect(EtiquetaCompatibilidad.nivel(20), AppStrings.compatibilidadBaja);
  });

  testWidgets('la pantalla muestra tarjetas y cambia a ropa', (tester) async {
    final e = _Entorno();
    await tester.runAsync(e.sembrar);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: e.colorimetria),
        ChangeNotifierProvider.value(value: e.recomendaciones),
      ],
      child: const MaterialApp(home: RecomendacionesView()),
    ));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.tipoRopa), findsOneWidget);
    final primerProducto = e.recomendaciones
        .enCache(TipoRecomendacion.maquillaje, null)!
        .first;
    expect(find.text(primerProducto.nombre), findsOneWidget);
    expect(find.text(AppStrings.recomendacionesCalculoLocal), findsOneWidget);

    await tester.tap(find.text(AppStrings.tipoRopa));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.filtroTodasOcasiones), findsOneWidget);
    final primeraPrenda =
        e.recomendaciones.enCache(TipoRecomendacion.outfit, null)!.first;
    expect(find.text(primeraPrenda.nombre), findsOneWidget);
  });

  testWidgets('sin análisis muestra el botón para hacerlo', (tester) async {
    final e = _Entorno();
    await tester.runAsync(() => e.sembrar(conPerfil: false));
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: e.colorimetria),
        ChangeNotifierProvider.value(value: e.recomendaciones),
      ],
      child: const MaterialApp(home: RecomendacionesView()),
    ));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.recomendacionesSinPerfilMensaje), findsOneWidget);
    expect(find.text(AppStrings.iniciarAnalisis), findsOneWidget);
  });
}
