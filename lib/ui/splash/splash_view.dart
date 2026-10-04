import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/boton_primario.dart';
import '../../core/widgets/gradiente_fondo.dart';
import '../../providers/sesion_provider.dart';
import 'splash_view_model.dart';

/// Muestra el logo al menos 1,8 s y luego redirige según la sesión
/// (ver [SplashViewModel.decidir]): onboarding, login, verificar_correo
/// o home.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  final SplashViewModel _vm = SplashViewModel();
  Timer? _temporizador;
  bool _tiempoCumplido = false;

  @override
  void initState() {
    super.initState();
    _temporizador = Timer(const Duration(milliseconds: 1800), () {
      _tiempoCumplido = true;
      _intentarNavegar();
    });
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _intentarNavegar() async {
    if (!mounted || !_tiempoCumplido || _vm.decidido) return;
    final destino = await _vm.decidir(context.read<SesionProvider>());
    if (!mounted) return;
    if (destino != null) {
      Navigator.of(context).pushReplacementNamed(destino);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si Firebase aún no respondía cuando terminó el temporizador, se
    // vuelve a intentar cuando cambie la sesión.
    context.watch<SesionProvider>();
    if (_tiempoCumplido && !_vm.decidido) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _intentarNavegar());
    }
    if (!_vm.mostrarOnboarding) {
      return const _SplashLogo();
    }
    return ChangeNotifierProvider.value(
      value: _vm,
      child: const _OnboardingView(),
    );
  }
}

/// Splash puro: logo, nombre de marca y eslogan.
class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradienteFondo(
        gradient: AppGradients.splash,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Marcador del isotipo del logo. Reemplazar por
              // Image.asset(AppAssets.logo) cuando el asset esté disponible.
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white24, width: 1.4),
                ),
                child: const Icon(
                  Icons.face_retouching_natural,
                  color: Colors.white,
                  size: 46,
                ),
              ),
              const SizedBox(height: 22),
              Text(AppStrings.nombreApp, style: AppTextStyles.logo),
              const SizedBox(height: 6),
              Text(
                AppStrings.eslogan,
                style: AppTextStyles.subtitulo.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 36),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Introducción de 3 páginas (carrusel) que presenta las funciones
/// principales de Make Up AI antes de llegar al login.
class _OnboardingView extends StatelessWidget {
  const _OnboardingView();

  static const List<OnboardingPagina> _paginas = [
    OnboardingPagina(
      titulo: AppStrings.onboardingTitulo1,
      descripcion: AppStrings.onboardingDescripcion1,
    ),
    OnboardingPagina(
      titulo: AppStrings.onboardingTitulo2,
      descripcion: AppStrings.onboardingDescripcion2,
    ),
    OnboardingPagina(
      titulo: AppStrings.onboardingTitulo3,
      descripcion: AppStrings.onboardingDescripcion3,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SplashViewModel>();

    return Scaffold(
      body: GradienteFondo(
        gradient: AppGradients.fondoSuave,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppGradients.marca,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.tituloPantalla.copyWith(fontSize: 20),
                    children: const [
                      TextSpan(text: 'MAKE UP '),
                      TextSpan(
                        text: 'AI',
                        style: TextStyle(color: AppColors.fucsia),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    itemCount: _paginas.length,
                    onPageChanged: vm.actualizarPagina,
                    itemBuilder: (context, index) {
                      final pagina = _paginas[index];
                      return _PaginaOnboarding(pagina: pagina);
                    },
                  ),
                ),
                _IndicadorPaginas(
                  total: _paginas.length,
                  actual: vm.paginaActual,
                ),
                const SizedBox(height: 24),
                BotonPrimario(
                  texto: AppStrings.botonComenzar,
                  icono: Icons.arrow_forward,
                  onPressed: () => _irALogin(context, vm),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _irALogin(context, vm),
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.subtitulo,
                      children: [
                        const TextSpan(text: AppStrings.yaTienesCuenta),
                        TextSpan(
                          text: AppStrings.iniciaSesion,
                          style: AppTextStyles.enlace,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Marca el onboarding como visto (no se repite) y abre el login.
Future<void> _irALogin(BuildContext context, SplashViewModel vm) async {
  final navigator = Navigator.of(context);
  await vm.terminarOnboarding(context.read<SesionProvider>());
  navigator.pushReplacementNamed(AppRoutes.login);
}

class _PaginaOnboarding extends StatelessWidget {
  final OnboardingPagina pagina;

  const _PaginaOnboarding({required this.pagina});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.superficie, width: 6),
            boxShadow: [
              BoxShadow(
                color: AppColors.violeta.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.face_retouching_natural,
            size: 96,
            color: AppColors.fucsia,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          pagina.titulo,
          textAlign: TextAlign.center,
          style: AppTextStyles.tituloPantalla.copyWith(fontSize: 21),
        ),
        const SizedBox(height: 10),
        Text(
          pagina.descripcion,
          textAlign: TextAlign.center,
          style: AppTextStyles.subtitulo,
        ),
      ],
    );
  }
}

class _IndicadorPaginas extends StatelessWidget {
  final int total;
  final int actual;

  const _IndicadorPaginas({required this.total, required this.actual});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final activo = index == actual;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: activo ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: activo ? AppColors.fucsia : AppColors.borde,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
