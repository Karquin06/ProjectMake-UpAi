import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import 'home_view.dart';

class MainNavigationView extends StatefulWidget {
  const MainNavigationView({super.key});

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class _MainNavigationViewState extends State<MainNavigationView> {
  int _indiceActual = 0;

  static const List<Widget> _paginas = [
    HomeView(),
    _PantallaProvisional(
      icono: Icons.face_retouching_natural,
      titulo: AppStrings.colorimetriaTab,
    ),
    _PantallaProvisional(
      icono: Icons.smart_toy_outlined,
      titulo: AppStrings.asistenteTab,
    ),
    _PantallaPerfilProvisional(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _indiceActual, children: _paginas),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: (index) => setState(() => _indiceActual = index),
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
    );
  }
}

/// Placeholder visual para las pestañas aún no implementadas.
class _PantallaProvisional extends StatelessWidget {
  final IconData icono;
  final String titulo;

  const _PantallaProvisional({required this.icono, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: AppColors.textoSecundario),
            const SizedBox(height: 12),
            Text(
              '$titulo — próximamente',
              style: const TextStyle(color: AppColors.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}

class _PantallaPerfilProvisional extends StatelessWidget {
  const _PantallaPerfilProvisional();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_outline,
              size: 48,
              color: AppColors.textoSecundario,
            ),
            const SizedBox(height: 12),
            Text(
              '${AppStrings.perfilTab} — próximamente',
              style: const TextStyle(color: AppColors.textoSecundario),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () async {
                await AuthRepository().cerrarSesion();
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(AppRoutes.splash, (_) => false);
                }
              },
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text(
                'Cerrar sesión',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
