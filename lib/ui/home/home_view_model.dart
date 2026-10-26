import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/firebase_error_mapper.dart';
import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/paleta_model.dart';
import '../../models/perfil_colorimetria_model.dart';
import '../../providers/sesion_provider.dart';

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
/// `HomeView` inyecta el perfil y la paleta reales (`colorimetria_home.dart`)
/// y las recomendaciones reales (`destacadas_home.dart`).
class HomeViewModel extends ChangeNotifier {
  final CargarPerfil _cargarPerfil;
  final CargarPaleta _cargarPaleta;
  final CargarRecomendaciones _cargarRecomendaciones;

  /// Las pruebas inyectan sus propias fuentes; si falta una, esa sección
  /// de Home queda vacía.
  HomeViewModel({
    CargarPerfil? cargarPerfil,
    CargarPaleta? cargarPaleta,
    CargarRecomendaciones? cargarRecomendaciones,
  }) : _cargarPerfil = cargarPerfil ?? ((_) async => null),
       _cargarPaleta = cargarPaleta ?? ((_) async => const []),
       _cargarRecomendaciones =
           cargarRecomendaciones ?? ((_) async => const []);

  String? _uid;
  bool _desechado = false;
  bool _recargaPendiente = false;

  /// Estación y fecha del último perfil de colorimetría visto; `null` hasta
  /// la primera sincronización.
  (EstacionColor?, DateTime?)? _huellaPerfil;
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

  /// Se llama cada vez que cambia `ColorimetriaProvider`. Si la usuaria hizo
  /// un análisis nuevo, recarga Home para mostrar su estación y su paleta.
  void actualizarColorimetria(PerfilColorimetria? perfil) {
    final huella = (perfil?.estacionColor, perfil?.fechaAnalisis);
    final anterior = _huellaPerfil;
    _huellaPerfil = huella;
    if (anterior == null || anterior == huella || _uid == null) return;
    Future.microtask(cargar);
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
    if (uid == null || _desechado) return;
    if (_cargando) {
      // Cambió el perfil mientras cargaba: se repite al terminar.
      _recargaPendiente = true;
      return;
    }
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
    if (_recargaPendiente && !_desechado) {
      _recargaPendiente = false;
      await cargar();
    }
  }
}
