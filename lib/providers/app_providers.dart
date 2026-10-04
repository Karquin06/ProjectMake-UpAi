import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/usuaria_repository.dart';

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
    // FASE 2: AuthProvider, UsuariaProvider y SesionProvider.
  ];

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
