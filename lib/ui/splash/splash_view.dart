import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/boton_primario.dart';
import '../../core/widgets/gradiente_fondo.dart';
import '../../providers/sesion_provider.dart';
import 'splash_view_model.dart';

/// Anima el logo (fade y escala) y, cuando la animación termina, redirige
/// según la sesión (ver [SplashViewModel.decidir]): onboarding, login,
/// verificar_correo o home.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  /// Tiempo mínimo que se ve el splash: lo que dura la animación.
  static const Duration _duracion = Duration(milliseconds: 1800);

  final SplashViewModel _vm = SplashViewModel();
  late final AnimationController _controlador;
  late final Animation<double> _opacidad;
  late final Animation<double> _escala;
  bool _tiempoCumplido = false;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(vsync: this, duration: _duracion);
    _opacidad = CurvedAnimation(
      parent: _controlador,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
    );
    _escala = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(
        parent: _controlador,
        curve: const Interval(0, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _controlador.addStatusListener((estado) {
      if (estado == AnimationStatus.completed) {
        _tiempoCumplido = true;
        _intentarNavegar();
      }
    });
    _controlador.forward();
  }

  @override
  void dispose() {
    _controlador.dispose();
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
      return _SplashLogo(opacidad: _opacidad, escala: _escala);
    }
    return ChangeNotifierProvider.value(
      value: _vm,
      child: const _OnboardingView(),
    );
  }
}

/// Splash puro: el logo (que ya incluye nombre y eslogan) aparece con fade
/// y escala. El JPEG no es transparente, así que va dentro de una tarjeta
/// blanca redondeada sobre el degradado de marca.
class _SplashLogo extends StatelessWidget {
  final Animation<double> opacidad;
  final Animation<double> escala;

  const _SplashLogo({required this.opacidad, required this.escala});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradienteFondo(
        gradient: AppGradients.splash,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: opacidad,
                child: ScaleTransition(
                  scale: escala,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.violetaOscuro.withValues(
                            alpha: 0.35,
                          ),
                          blurRadius: 32,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: Image.asset(
                        AppAssets.logo,
                        fit: BoxFit.cover,
                        semanticLabel: AppStrings.nombreApp,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              FadeTransition(
                opacity: opacidad,
                child: const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white70,
                  ),
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
