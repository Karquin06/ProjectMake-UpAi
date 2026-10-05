import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/credencial_repository.dart';
import '../data/repositories/sesion_repository.dart';
import '../core/constants/app_constants.dart';
import '../data/repositories/usuaria_repository.dart';
import '../data/services/notificaciones_service.dart';
import '../data/services/subidor_foto_perfil.dart';
import 'auth_provider.dart';
import 'notificaciones_provider.dart';
import 'sesion_provider.dart';
import 'usuaria_provider.dart';

/// Punto ÚNICO donde se registran los providers globales de la app.
///
/// Envuelve al `MaterialApp` (ver `app.dart`), de modo que todo provider
/// registrado aquí está disponible en cualquier ruta.
///
/// Reglas para evitar conflictos de merge:
/// - Cada integrante agrega sus providers SOLO en su propia lista.
/// - Los repositorios y servicios se registran con `Provider` (sin estado)
///   antes de los `ChangeNotifierProvider` que los usan, para que estos
///   puedan obtenerlos con `context.read<...>()`.
class AppProviders extends StatelessWidget {
  final Widget child;

  const AppProviders({super.key, required this.child});

  /// Core, Auth, Home y Perfil — dueño: Karlos Quintero.
  static List<SingleChildWidget> get _core => [
    Provider<AuthRepository>(create: (_) => AuthRepository()),
    Provider<UsuariaRepository>(create: (_) => UsuariaRepository()),
    Provider<SesionRepository>(create: (_) => SesionRepository()),
    Provider<CredencialRepository>(create: (_) => CredencialRepository()),
    Provider<NotificacionesService>(create: (_) => NotificacionesService()),
    Provider<SubidorFotoPerfil>(
      create: (_) {
        // PUNTO DE CAMBIO (Jaider): cuando exista StorageService, devolver
        // un adaptador que implemente SubidorFotoPerfil con él y poner
        // AppConstants.usarMockStorage en false.
        assert(
          AppConstants.usarMockStorage,
          'Conecta StorageService aquí antes de apagar usarMockStorage.',
        );
        return SubidorFotoPerfilMock();
      },
    ),
    ChangeNotifierProvider<AuthProvider>(
      create: (c) => AuthProvider(c.read<AuthRepository>()),
    ),
    ChangeNotifierProvider<UsuariaProvider>(
      create: (c) => UsuariaProvider(
        usuariaRepository: c.read<UsuariaRepository>(),
        authRepository: c.read<AuthRepository>(),
        subidorFoto: c.read<SubidorFotoPerfil>(),
      ),
    ),
    // Vista unificada de la sesión; se recrea cuando cambian los dos
    // providers anteriores. Úsalo con context.watch<SesionProvider>().
    ProxyProvider2<AuthProvider, UsuariaProvider, SesionProvider>(
      update: (c, auth, usuaria, _) => SesionProvider(
        auth: auth,
        usuaria: usuaria,
        preferencias: c.read<SesionRepository>(),
        credenciales: c.read<CredencialRepository>(),
      ),
    ),
    // Se limpia al cerrar sesión (LimpiezaPorSesion).
    ChangeNotifierProxyProvider<SesionProvider, NotificacionesProvider>(
      create: (c) => NotificacionesProvider(
        servicio: c.read<NotificacionesService>(),
        usuarias: c.read<UsuariaProvider>(),
      ),
      update: (_, sesion, notificaciones) =>
          notificaciones!..sincronizarUsuaria(sesion.uidActiva),
    ),
  ];

  // IMPORTANTE para todos: si tu provider guarda datos de la usuaria, usa
  // el mixin LimpiezaPorSesion (providers/limpieza_sesion.dart) y regístralo
  // con ChangeNotifierProxyProvider<SesionProvider, TuProvider> llamando a
  // sincronizarUsuaria(sesion.uidActiva). Así se limpia al cerrar sesión.

  /// Colorimetría, paleta y servicios compartidos — dueño: Jaider Monrroy.
  static List<SingleChildWidget> get _colorimetria => [
    // Ej.: ChangeNotifierProvider(create: (c) => ColorimetriaProvider(...)),
  ];

  /// IA, recomendaciones y catálogo — dueña: Ana Cuellar.
  static List<SingleChildWidget> get _inteligenciaArtificial => [
    // Ej.: ChangeNotifierProvider(create: (c) => RecomendacionProvider(...)),
  ];

  /// AR, escáner y armario — dueño: Mauricio Parra.
  static List<SingleChildWidget> get _realidadAumentada => [
    // Ej.: ChangeNotifierProvider(create: (c) => ArmarioProvider(...)),
  ];

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ..._core,
        ..._colorimetria,
        ..._inteligenciaArtificial,
        ..._realidadAumentada,
      ],
      child: child,
    );
  }
}
