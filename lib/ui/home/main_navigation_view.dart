import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_router.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/estado_vacio.dart';
import '../../providers/sesion_provider.dart';
import 'home_view.dart';

/// Contenedor principal tras iniciar sesión: barra inferior con Inicio,
/// Colorimetría, Asistente y Perfil. Usa `IndexedStack` para conservar el
/// estado (scroll, formularios...) de cada pestaña al cambiar entre ellas.
class MainNavigationView extends StatefulWidget {
  const MainNavigationView({super.key});

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class _MainNavigationViewState extends State<MainNavigationView> {
  int _indiceActual = 0;

  /// Se crean una sola vez para que cada pestaña conserve su estado.
  /// Colorimetría y Asistente muestran la misma vista que su ruta: cuando
  /// Jaider y Ana la conecten en `app_router.dart`, aparecerá aquí sola.
  late final List<Widget> _paginas = [
    HomeView(onIrAPestana: _cambiarPestana),
    AppRouter.paginaDe(AppRoutes.colorimetria),
    AppRouter.paginaDe(AppRoutes.asistente),
    // FASE 5: reemplazar por AppRouter.paginaDe(AppRoutes.perfil).
    const _PantallaPerfilProvisional(),
  ];

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

/// Perfil provisional hasta la FASE 5 (solo permite cerrar sesión).
class _PantallaPerfilProvisional extends StatelessWidget {
  const _PantallaPerfilProvisional();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      body: EstadoVacio(
        icono: Icons.person_outline,
        titulo: AppStrings.enConstruccion,
        textoBoton: AppStrings.cerrarSesion,
        onPressed: () async {
          final navigator = Navigator.of(context);
          await context.read<SesionProvider>().cerrarSesion();
          navigator.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
        },
      ),
    );
  }
}
