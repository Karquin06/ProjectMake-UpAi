import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_router.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../data/services/notificaciones_service.dart';
import '../../providers/notificaciones_provider.dart';
import 'home_view.dart';

/// Contenedor principal tras iniciar sesión: barra inferior con Inicio,
/// Colorimetría, Asistente y Perfil. Usa `IndexedStack` para conservar el
/// estado (scroll, formularios...) de cada pestaña al cambiar entre ellas.
///
/// También muestra como aviso las notificaciones push que llegan con la
/// app abierta.
class MainNavigationView extends StatefulWidget {
  const MainNavigationView({super.key});

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class _MainNavigationViewState extends State<MainNavigationView> {
  int _indiceActual = 0;
  StreamSubscription<NotificacionEntrante>? _subNotificaciones;

  /// Se crean una sola vez para que cada pestaña conserve su estado.
  /// Colorimetría, Asistente y Perfil muestran la misma vista que su ruta:
  /// cuando Jaider y Ana la conecten en `app_router.dart`, aparecerá aquí.
  late final List<Widget> _paginas = [
    HomeView(onIrAPestana: _cambiarPestana),
    AppRouter.paginaDe(AppRoutes.colorimetria),
    AppRouter.paginaDe(AppRoutes.asistente),
    AppRouter.paginaDe(AppRoutes.perfil),
  ];

  @override
  void initState() {
    super.initState();
    // Leerlo también lo inicializa (pide permiso y registra el token).
    _subNotificaciones = context
        .read<NotificacionesProvider>()
        .entrantes
        .listen(_mostrarNotificacion);
  }

  @override
  void dispose() {
    _subNotificaciones?.cancel();
    super.dispose();
  }

  void _mostrarNotificacion(NotificacionEntrante n) {
    if (!mounted) return;
    final titulo = n.titulo ?? AppStrings.notificacionNueva;
    SnackbarHelper.info(
      context,
      n.cuerpo == null ? titulo : '$titulo: ${n.cuerpo}',
    );
  }

  void _cambiarPestana(int indice) => setState(() => _indiceActual = indice);

  @override
  Widget build(BuildContext context) {
    // "Atrás" en Android vuelve primero a Inicio antes de salir de la app.
    return PopScope(
      canPop: _indiceActual == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cambiarPestana(0);
      },
      child: Scaffold(
        body: IndexedStack(index: _indiceActual, children: _paginas),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _indiceActual,
          onTap: _cambiarPestana,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: AppStrings.inicio,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.face_retouching_natural_outlined),
              activeIcon: Icon(Icons.face_retouching_natural),
              label: AppStrings.colorimetriaTab,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy_outlined),
              activeIcon: Icon(Icons.smart_toy),
              label: AppStrings.asistenteTab,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: AppStrings.perfilTab,
            ),
          ],
        ),
      ),
    );
  }
}
