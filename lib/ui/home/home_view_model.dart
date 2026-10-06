import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/firebase_error_mapper.dart';
import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/paleta.dart';
import '../../models/perfil_colorimetria.dart';
import '../../providers/sesion_provider.dart';
import 'home_datos_mock.dart';

/// Recomendación lista para mostrarse en la tarjeta del carrusel de Home.
class RecomendacionDestacada {
  final String id;
  final String titulo;
  final String subtitulo;
  final TipoRecomendacion tipo;

  /// Uno de los dos apunta al detalle (producto de maquillaje o prenda).
  final String? productoId;
  final String? prendaId;

  const RecomendacionDestacada({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.tipo,
    this.productoId,
    this.prendaId,
  });
}

/// Accesos directos de Home. Armario depende de su bandera.
enum AccesoHome {
  colorimetria,
  paleta,
  outfits,
  maquillaje,
  asistente,
  simuladorAr,
  armario,
}

typedef CargarPerfil = Future<PerfilColorimetria?> Function(String uid);
typedef CargarPaleta = Future<List<ColorPaleta>> Function(String uid);
typedef CargarRecomendaciones =
    Future<List<RecomendacionDestacada>> Function(String uid);

/// Junta en Home: nombre de la usuaria, perfil de colorimetría (con su
/// paleta) y recomendaciones destacadas.
///
/// Mientras no existan `ColorimetriaProvider` (Jaider) y
/// `RecomendacionProvider` (Ana) se usan datos de ejemplo según las
/// banderas de [AppConstants]. Busca "PUNTO DE CAMBIO" para conectarlos.
class HomeViewModel extends ChangeNotifier {
  final CargarPerfil _cargarPerfil;
  final CargarPaleta _cargarPaleta;
  final CargarRecomendaciones _cargarRecomendaciones;

  /// Los parámetros permiten inyectar fuentes en pruebas; en la app se usan
  /// las fuentes por defecto (mock o real según las banderas).
  HomeViewModel({
    CargarPerfil? cargarPerfil,
    CargarPaleta? cargarPaleta,
    CargarRecomendaciones? cargarRecomendaciones,
  }) : _cargarPerfil = cargarPerfil ?? _perfilPorDefecto,
       _cargarPaleta = cargarPaleta ?? _paletaPorDefecto,
       _cargarRecomendaciones =
           cargarRecomendaciones ?? _recomendacionesPorDefecto;

  String? _uid;
  bool _desechado = false;
  String _nombre = '';
  bool _cargando = false;
  String? _error;
  PerfilColorimetria? _perfil;
  List<ColorPaleta> _paleta = const [];
  List<RecomendacionDestacada> _recomendaciones = const [];

  /// Primer nombre para el saludo (vacío si aún no se conoce).
  String get nombre => _nombre;
  bool get cargando => _cargando;
  String? get error => _error;
  PerfilColorimetria? get perfil => _perfil;
  bool get tieneColorimetria => _perfil?.estacionColor != null;
  List<ColorPaleta> get paleta => _paleta;
  List<RecomendacionDestacada> get recomendaciones => _recomendaciones;

  /// Accesos en el orden en que se muestran.
  List<AccesoHome> get accesos => AccesoHome.values;

  bool estaHabilitado(AccesoHome acceso) => switch (acceso) {
    AccesoHome.armario => AppConstants.armarioHabilitado,
    _ => true,
  };

  /// Se llama cada vez que cambia la sesión (ver `HomeView`). Actualiza el
  /// nombre y carga los datos la primera vez que se conoce la usuaria.
  void actualizarSesion(SesionProvider sesion) {
    final nombre = Formateadores.primerNombre(sesion.nombreVisible);
    final uid = sesion.uid;
    final cambioUsuaria = uid != _uid;
    if (nombre == _nombre && !cambioUsuaria) return;
    _nombre = nombre;
    _uid = uid;
    if (cambioUsuaria && uid != null) {
      // Se difiere para no notificar durante el build del árbol.
      Future.microtask(cargar);
    } else {
      Future.microtask(_notificar);
    }
  }

  void _notificar() {
    if (!_desechado) notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    super.dispose();
  }

  /// Carga (o recarga, p. ej. con "Reintentar" o al deslizar hacia abajo)
  /// el perfil, la paleta y las recomendaciones.
  Future<void> cargar() async {
    final uid = _uid;
    if (uid == null || _cargando || _desechado) return;
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      final resultados = await Future.wait([
        _cargarPerfil(uid),
        _cargarPaleta(uid),
        _cargarRecomendaciones(uid),
      ]);
      _perfil = resultados[0] as PerfilColorimetria?;
      _paleta = resultados[1] as List<ColorPaleta>;
      _recomendaciones = resultados[2] as List<RecomendacionDestacada>;
    } catch (e) {
      _error = FirebaseErrorMapper.mensaje(e);
    }
    _cargando = false;
    _notificar();
  }

  // -----------------------------------------------------------------------
  // Fuentes por defecto
  // -----------------------------------------------------------------------

  static const _esperaMock = Duration(milliseconds: 400);

  static Future<PerfilColorimetria?> _perfilPorDefecto(String uid) async {
    if (AppConstants.usarMockColorimetria) {
      await Future<void>.delayed(_esperaMock);
      return HomeDatosMock.perfil(uid);
    }
    // PUNTO DE CAMBIO (Jaider): devolver el perfil real, p. ej.
    //   return colorimetriaProvider.perfil;
    // (inyectando ColorimetriaProvider en el constructor desde HomeView).
    return null;
  }

  static Future<List<ColorPaleta>> _paletaPorDefecto(String uid) async {
    if (AppConstants.usarMockColorimetria) return HomeDatosMock.paleta;
    // PUNTO DE CAMBIO (Jaider): devolver los colores de la paleta real, p. ej.
    //   return colorimetriaProvider.paleta?.colores ?? const [];
    return const [];
  }

  static Future<List<RecomendacionDestacada>> _recomendacionesPorDefecto(
    String uid,
  ) async {
    if (AppConstants.usarMockRecomendaciones) {
      await Future<void>.delayed(_esperaMock);
      return HomeDatosMock.recomendaciones;
    }
    // PUNTO DE CAMBIO (Ana): convertir las recomendaciones reales a
    // RecomendacionDestacada (título y subtítulo del producto/prenda), p. ej.
    //   return recomendacionProvider.destacadas.map((r) => RecomendacionDestacada(...)).toList();
    return const [];
  }
}
