import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../constants/app_strings.dart';
import 'app_routes.dart';
import 'guardia_ruta.dart';
import 'pantalla_en_construccion.dart';
import '../../ui/splash/splash_view.dart';
import '../../ui/auth/aviso_privacidad_view.dart';
import '../../ui/auth/login_view.dart';
import '../../ui/auth/recuperar_contrasena_view.dart';
import '../../ui/auth/registro_view.dart';
import '../../ui/auth/verificar_correo_view.dart';
import '../../ui/home/main_navigation_view.dart';
import '../../ui/perfil/editar_perfil_view.dart';
import '../../ui/perfil/perfil_view.dart';

/// Tabla de rutas de la app: qué vista abre cada ruta y quién puede verla.
///
/// CÓMO CONECTAR TU VISTA REAL (cuando exista el archivo):
/// 1. Importa tu vista arriba (p. ej. `import '../../ui/paleta/...';`).
/// 2. En tu ruta, reemplaza `_enConstruccion(...)` por tu vista, como
///    indica el comentario `CONECTAR` de esa línea.
/// 3. Para recibir argumentos usa `context.argumentos<T>()` en tu vista.
/// Este archivo es de Karlos: haz el cambio en tu PR y menciónalo, o
/// pídeselo a él.
class AppRouter {
  AppRouter._();

  static final Map<String, _Destino> _destinos = {
    // -------------------------------------------------------------------
    // Splash, Auth, Home y Perfil — Karlos
    // -------------------------------------------------------------------
    AppRoutes.splash: _Destino.publica(() => const SplashView()),
    // El onboarding vive dentro de SplashView (se muestra tras el logo).
    AppRoutes.onboarding: _Destino.publica(() => const SplashView()),
    AppRoutes.login: _Destino.publica(() => const LoginView()),
    AppRoutes.registro: _Destino.publica(() => const RegistroView()),
    AppRoutes.avisoPrivacidad: _Destino.publica(
      () => const AvisoPrivacidadView(),
    ),
    AppRoutes.recuperarContrasena: _Destino.publica(
      () => const RecuperarContrasenaView(),
    ),
    AppRoutes.verificarCorreo: _Destino(
      NivelAcceso.verificacionPendiente,
      () => const VerificarCorreoView(),
    ),
    AppRoutes.home: _Destino.autenticada(() => const MainNavigationView()),
    AppRoutes.perfil: _Destino.autenticada(() => const PerfilView()),
    AppRoutes.editarPerfil: _Destino.autenticada(
      () => const EditarPerfilView(),
    ),

    // -------------------------------------------------------------------
    // Colorimetría y paleta — Jaider
    // -------------------------------------------------------------------
    // CONECTAR (Jaider): import '../../ui/colorimetria/colorimetria_view.dart'; → const ColorimetriaView()
    AppRoutes.colorimetria: _Destino.autenticada(
      () => _enConstruccion('colorimetria_view', 'Jaider'),
    ),
    // CONECTAR (Jaider): import '../../ui/colorimetria/captura_selfie_view.dart'; → const CapturaSelfieView()
    AppRoutes.capturaSelfie: _Destino.autenticada(
      () => _enConstruccion('captura_selfie_view', 'Jaider'),
    ),
    // CONECTAR (Jaider): import '../../ui/colorimetria/analisis_view.dart'; → const AnalisisView()
    AppRoutes.analisis: _Destino.autenticada(
      () => _enConstruccion('analisis_view', 'Jaider'),
    ),
    // CONECTAR (Jaider): import '../../ui/colorimetria/resultado_view.dart'; → const ResultadoView()
    AppRoutes.resultado: _Destino.autenticada(
      () => _enConstruccion('resultado_view', 'Jaider'),
    ),
    // CONECTAR (Jaider): import '../../ui/colorimetria/paleta_view.dart'; → const PaletaView()
    AppRoutes.paleta: _Destino.autenticada(
      () => _enConstruccion('paleta_view', 'Jaider'),
    ),

    // -------------------------------------------------------------------
    // Simulador AR, escáner y armario — Mauricio
    // -------------------------------------------------------------------
    // CONECTAR (Mauricio): import '../../ui/simulador_ar/simulador_ar_view.dart'; → const SimuladorArView()
    AppRoutes.simuladorAr: _Destino.autenticada(
      () => _enConstruccion('simulador_ar_view', 'Mauricio'),
    ),
    // CONECTAR (Mauricio): import '../../ui/escaner/escaner_view.dart'; → const EscanerView()
    // Mientras AppConstants.escanerHabilitado sea false se muestra "Próximamente".
    AppRoutes.escaner: _Destino.autenticada(
      () => _enConstruccion(
        'escaner_view',
        'Mauricio',
        deshabilitada: !AppConstants.escanerHabilitado,
      ),
    ),
    // CONECTAR (Mauricio): import '../../ui/escaner/analisis_prenda_view.dart'; → const AnalisisPrendaView()
    AppRoutes.analisisPrenda: _Destino.autenticada(
      () => _enConstruccion(
        'analisis_prenda_view',
        'Mauricio',
        deshabilitada: !AppConstants.escanerHabilitado,
      ),
    ),
    // CONECTAR (Mauricio): import '../../ui/armario/armario_view.dart'; → const ArmarioView()
    // Mientras AppConstants.armarioHabilitado sea false se muestra "Próximamente".
    AppRoutes.armario: _Destino.autenticada(
      () => _enConstruccion(
        'armario_view',
        'Mauricio',
        deshabilitada: !AppConstants.armarioHabilitado,
      ),
    ),

    // -------------------------------------------------------------------
    // Recomendaciones, asistente y catálogo — Ana
    // -------------------------------------------------------------------
    // CONECTAR (Ana): import '../../ui/recomendaciones/recomendaciones_view.dart'; → const RecomendacionesView()
    AppRoutes.recomendaciones: _Destino.autenticada(
      () => _enConstruccion('recomendaciones_view', 'Ana'),
    ),
    // CONECTAR (Ana): import '../../ui/recomendaciones/detalle_prenda_view.dart'; → const DetallePrendaView()
    AppRoutes.detallePrenda: _Destino.autenticada(
      () => _enConstruccion('detalle_prenda_view', 'Ana'),
    ),
    // CONECTAR (Ana): import '../../ui/recomendaciones/detalle_producto_view.dart'; → const DetalleProductoView()
    AppRoutes.detalleProducto: _Destino.autenticada(
      () => _enConstruccion('detalle_producto_view', 'Ana'),
    ),
    // CONECTAR (Ana): import '../../ui/asistente/asistente_view.dart'; → const AsistenteView()
    AppRoutes.asistente: _Destino.autenticada(
      () => _enConstruccion('asistente_view', 'Ana'),
    ),
    // CONECTAR (Ana): import '../../ui/admin/catalogo_admin_view.dart'; → const CatalogoAdminView()
    AppRoutes.catalogoAdmin: _Destino.admin(
      () => _enConstruccion('catalogo_admin_view', 'Ana'),
    ),
    // CONECTAR (Ana): import '../../ui/admin/formulario_prenda_view.dart'; → const FormularioPrendaView()
    AppRoutes.formularioPrenda: _Destino.admin(
      () => _enConstruccion('formulario_prenda_view', 'Ana'),
    ),
    // CONECTAR (Ana): import '../../ui/admin/formulario_producto_view.dart'; → const FormularioProductoView()
    AppRoutes.formularioProducto: _Destino.admin(
      () => _enConstruccion('formulario_producto_view', 'Ana'),
    ),
  };

  /// Todas las rutas registradas (útil para pruebas).
  static Iterable<String> get rutasRegistradas => _destinos.keys;

  /// Nivel de acceso de [ruta], o `null` si no está registrada.
  static NivelAcceso? nivelDe(String ruta) => _destinos[ruta]?.nivel;

  /// Vista de [ruta] SIN guardia, para incrustarla como pestaña dentro de
  /// una pantalla ya protegida (p. ej. la barra inferior de Home). Así la
  /// pestaña muestra automáticamente la vista real cuando se conecta aquí.
  static Widget paginaDe(String ruta) {
    final destino = _destinos[ruta];
    assert(destino != null, 'Ruta no registrada: $ruta');
    return destino?.constructor() ?? _enConstruccion(ruta, '-');
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final destino = _destinos[settings.name];
    if (destino == null) {
      return _transicion(
        settings,
        _enConstruccion(
          settings.name ?? '',
          '-',
          titulo: AppStrings.rutaNoEncontrada,
        ),
      );
    }
    final pagina = destino.constructor();
    return _transicion(
      settings,
      destino.nivel == NivelAcceso.publica
          ? pagina
          : GuardiaRuta(nivel: destino.nivel, child: pagina),
    );
  }

  static Widget _enConstruccion(
    String pantalla,
    String responsable, {
    bool deshabilitada = false,
    String? titulo,
  }) {
    return PantallaEnConstruccion(
      pantalla: pantalla,
      responsable: responsable,
      titulo:
          titulo ??
          (deshabilitada ? AppStrings.proximamente : AppStrings.enConstruccion),
    );
  }

  /// Transición de desvanecido. Pasa [settings] para que las vistas
  /// puedan leer los argumentos de la ruta.
  static PageRoute<dynamic> _transicion(RouteSettings settings, Widget child) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, _, _) => child,
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }
}

class _Destino {
  final NivelAcceso nivel;
  final Widget Function() constructor;

  const _Destino(this.nivel, this.constructor);
  const _Destino.publica(this.constructor) : nivel = NivelAcceso.publica;
  const _Destino.autenticada(this.constructor)
    : nivel = NivelAcceso.autenticada;
  const _Destino.admin(this.constructor) : nivel = NivelAcceso.admin;
}
