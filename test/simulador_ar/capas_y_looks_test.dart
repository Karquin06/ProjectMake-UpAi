import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mackeupai/data/repositories/armario_repository.dart';
import 'package:mackeupai/data/repositories/catalogo_repository.dart';
import 'package:mackeupai/data/services/compositor_looks_ar.dart';
import 'package:mackeupai/models/enums.dart';
import 'package:mackeupai/models/maquillaje_ar.dart';
import 'package:mackeupai/models/perfil_colorimetria_model.dart';
import 'package:mackeupai/models/producto_maquillaje.dart';
import 'package:mackeupai/models/recomendacion.dart';
import 'package:mackeupai/providers/armario_provider.dart';
import 'package:mackeupai/providers/producto_provider.dart';
import 'package:mackeupai/providers/recomendacion_provider.dart';
import 'package:mackeupai/ui/simulador_ar/maquillaje_ar_view_model.dart';

ProductoMaquillaje p(
  String id,
  String categoria, {
  EstacionColor estacion = EstacionColor.invierno,
  String hex = '#B04080',
  bool activo = true,
}) => ProductoMaquillaje(
  id: id,
  nombre: id,
  marca: 'Catálogo de prueba',
  categoria: categoria,
  tono: id,
  colorHex: hex,
  acabado: 'mate',
  precio: 1000,
  imagenUrl: '',
  activo: activo,
  estacionesCompatibles: [estacion],
  subtonoCompatible: [Subtono.neutro],
);
PerfilColorimetria crearPerfilAr() => PerfilColorimetria(
  uid: 'u1',
  estacionColor: EstacionColor.invierno,
  subtono: Subtono.frio,
  contraste: Contraste.medio,
  intensidad: Intensidad.media,
  confianza: .8,
  fechaAnalisis: DateTime(2026),
);
RecomendacionItem r(ProductoMaquillaje p) => RecomendacionItem(
  producto: p,
  recomendacion: Recomendacion(
    id: p.id,
    uid: 'u1',
    productoId: p.id,
    tipo: TipoRecomendacion.maquillaje,
    fecha: DateTime(2026),
    puntaje: 90,
    motivo: 'Del proveedor de recomendaciones',
  ),
);

class RecomendacionesPrueba extends Fake implements RecomendacionProvider {
  RecomendacionesPrueba(this.items);
  final List<RecomendacionItem> items;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  void actualizarPerfil(PerfilColorimetria? perfil) {}
  int llamadas = 0;
  @override
  PerfilColorimetria? get perfil => crearPerfilAr();
  @override
  Future<List<RecomendacionItem>> obtener({
    required TipoRecomendacion tipo,
    String? ocasion,
    bool forzar = false,
  }) async {
    llamadas++;
    return items;
  }
}

class RecomendacionesCambiantes extends RecomendacionesPrueba {
  RecomendacionesCambiantes(super.items);
  PerfilColorimetria? actual = crearPerfilAr();
  final iniciada = Completer<void>();
  final pendiente = Completer<List<RecomendacionItem>>();
  int pedidos = 0;
  @override
  PerfilColorimetria? get perfil => actual;
  @override
  Future<List<RecomendacionItem>> obtener({
    required TipoRecomendacion tipo,
    String? ocasion,
    bool forzar = false,
  }) async {
    pedidos++;
    if (pedidos == 1) {
      iniciada.complete();
      return pendiente.future;
    }
    return items;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'los looks proceden solo de recomendaciones reales y filtran incompatibles',
    () {
      final registros = RegistroEfectosAr(),
          productos = [
            p('labial', 'labial'),
            p('rubor', 'rubor'),
            p('sombra', 'sombra'),
            p('ajeno', 'labial', estacion: EstacionColor.otono),
            p('sin-color', 'sombra', hex: ''),
            p('inactivo', 'rubor', activo: false),
          ];
      final looks = const CompositorLooksAr().crear(
        productos.map((p) => CandidatoLookAr(p, 90)).toList(),
        crearPerfilAr(),
        registros,
      );
      expect(looks, hasLength(1));
      expect(looks.single.productos.map((p) => p.id).toSet(), {
        'labial',
        'rubor',
        'sombra',
      });
      expect(looks.single.parcial, isTrue);
      expect(looks.single.categoriasFaltantes, ['base']);
      expect(
        const CompositorLooksAr().crear([], crearPerfilAr(), registros),
        isEmpty,
      );
    },
  );
  test('no se rellena un look con categorías inexistentes', () {
    final looks = const CompositorLooksAr().crear(
      [CandidatoLookAr(p('unico', 'labial'), 90)],
      crearPerfilAr(),
      RegistroEfectosAr(),
    );
    expect(looks.single.parcial, isTrue);
    expect(looks.single.productos.single.id, 'unico');
  });
  test('el registro admite extensión y declara los efectos pendientes', () {
    final registro = RegistroEfectosAr(
      adicionales: [
        const DefinicionEfectoAr('nuevo', 'Nuevo', FamiliaEfectoAr.labios, 12),
      ],
    );
    expect(registro.tipos, hasLength(12));
    expect(registro.buscar('pestañina')?.disponible, isFalse);
    expect(registro.buscar('nuevo')?.disponible, isTrue);
  });
  test(
    'aplica tres capas, modifica y quita una, y prueba productos no recomendados',
    () async {
      final catalogo = CatalogoRepository(db: FakeFirebaseFirestore());
      final labial = p('l', 'labial'),
          rubor = p('r', 'rubor'),
          sombra = p('s', 'sombra'),
          libre = p('otra', 'labial', estacion: EstacionColor.otono);
      for (final item in [labial, rubor, sombra, libre]) {
        await catalogo.guardarProducto(item);
      }
      final productos = ProductoProvider(catalogo),
          armario = ArmarioProvider(ArmarioRepository())
            ..sincronizarUsuaria('u1');
      await Future<void>.delayed(Duration.zero);
      final recomendaciones = RecomendacionesPrueba([
        r(labial),
        r(rubor),
        r(sombra),
      ]);
      final vm = MaquillajeArViewModel(
        productos,
        armario,
        recomendaciones: recomendaciones,
      );
      addTearDown(() {
        vm.dispose();
        productos.dispose();
        armario.dispose();
      });
      await vm.cargar();
      expect(recomendaciones.llamadas, 1);
      expect(vm.looks, hasLength(1));
      vm.aplicarLook(vm.looks.single.id);
      expect(vm.capas, hasLength(3));
      vm.enfocar('rubor');
      vm.ajustarIntensidad(.2);
      expect(
        vm.capas.firstWhere((c) => c.efecto.categoria == 'rubor').intensidad,
        .2,
      );
      expect(
        vm.capas.firstWhere((c) => c.efecto.categoria == 'labial').producto.id,
        'l',
      );
      vm.quitar('sombra');
      expect(vm.capas, hasLength(2));
      vm.cambiarModo(ModoMaquillajeAr.libre);
      expect(vm.productos.map((p) => p.id), contains('otra'));
      vm.seleccionar('otra');
      expect(vm.capas, hasLength(2));
      expect(
        vm.capas.firstWhere((c) => c.efecto.categoria == 'rubor').producto.id,
        'r',
      );
      vm.comparar();
      expect(vm.original, isTrue);
      expect(vm.capas, hasLength(2));
      vm.limpiar();
      expect(vm.capas, isEmpty);
    },
  );
  test(
    'cambiar de cuenta borra todas las capas inmediatamente y no deja capturas ajenas',
    () async {
      final catalogo = CatalogoRepository(db: FakeFirebaseFirestore());
      await catalogo.guardarProducto(p('l', 'labial'));
      final productos = ProductoProvider(catalogo),
          armario = ArmarioProvider(ArmarioRepository())
            ..sincronizarUsuaria('u1');
      await Future<void>.delayed(Duration.zero);
      final vm = MaquillajeArViewModel(productos, armario);
      addTearDown(() {
        vm.dispose();
        productos.dispose();
        armario.dispose();
      });
      await vm.cargar();
      vm.seleccionar('l');
      expect(vm.capas, hasLength(1));
      armario.sincronizarUsuaria('u2');
      await Future<void>.delayed(Duration.zero);
      expect(vm.capas, isEmpty);
      expect(vm.ultimaCaptura, isNull);
    },
  );
  test(
    'un perfil nuevo descarta la respuesta anterior y recarga los looks compatibles',
    () async {
      final catalogo = CatalogoRepository(db: FakeFirebaseFirestore());
      final invierno = p('invierno', 'labial'),
          otono = p('otono', 'labial', estacion: EstacionColor.otono);
      for (final producto in [invierno, otono]) {
        await catalogo.guardarProducto(producto);
      }
      final productos = ProductoProvider(catalogo)
        ..sincronizarEstacion(EstacionColor.invierno);
      final armario = ArmarioProvider(ArmarioRepository())
        ..sincronizarUsuaria('u1');
      await Future<void>.delayed(Duration.zero);
      final recos = RecomendacionesCambiantes([r(invierno), r(otono)]);
      final vm = MaquillajeArViewModel(
        productos,
        armario,
        recomendaciones: recos,
      );
      addTearDown(() {
        vm.dispose();
        productos.dispose();
        armario.dispose();
      });
      final carga = vm.cargar();
      await recos.iniciada.future;
      recos.actual = crearPerfilAr().copyWith(
        estacionColor: EstacionColor.otono,
      );
      productos.sincronizarEstacion(EstacionColor.otono);
      await Future<void>.delayed(Duration.zero);
      recos.pendiente.complete([r(invierno)]);
      await carga;
      await Future<void>.delayed(Duration.zero);
      expect(recos.pedidos, 2);
      expect(vm.looks.single.productos.single.id, 'otono');
    },
  );
  test(
    'un producto recomendado que ya no existe no se inventa en el look',
    () async {
      final catalogo = CatalogoRepository(db: FakeFirebaseFirestore());
      await catalogo.guardarProducto(p('real', 'labial'));
      final productos = ProductoProvider(catalogo),
          armario = ArmarioProvider(ArmarioRepository())
            ..sincronizarUsuaria('u1');
      await Future<void>.delayed(Duration.zero);
      final vm = MaquillajeArViewModel(
        productos,
        armario,
        recomendaciones: RecomendacionesPrueba([r(p('ajeno', 'rubor'))]),
      );
      addTearDown(() {
        vm.dispose();
        productos.dispose();
        armario.dispose();
      });
      await vm.cargar();
      expect(vm.looks, isEmpty);
      expect(vm.catalogoVisible, isEmpty);
      vm.cambiarModo(ModoMaquillajeAr.libre);
      expect(vm.catalogoVisible.single.id, 'real');
    },
  );
}
