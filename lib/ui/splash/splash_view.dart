import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_router.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/boton_primario.dart';
import '../../core/widgets/gradiente_fondo.dart';
import '../../core/widgets/logo_app.dart';
import '../../providers/sesion_provider.dart';
import 'splash_view_model.dart';
import 'widgets/ilustracion_onboarding.dart';
import 'widgets/logo_animado.dart';

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
  static const Duration _duracion = Duration(milliseconds: 6000);

  /// Fundido del splash a la siguiente pantalla.
  static const Duration _salida = Duration(milliseconds: 1200);

  final SplashViewModel _vm = SplashViewModel();
  late final AnimationController _controlador;
  Timer? _limiteSesion;
  bool _tiempoCumplido = false;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(vsync: this, duration: _duracion);
    _controlador.addStatusListener((estado) {
      if (estado == AnimationStatus.completed) {
        _tiempoCumplido = true;
        // Terminada la animación, se espera a Firebase como mucho este tiempo.
        _limiteSesion = Timer(
          AppConstants.esperaMaximaSesion,
          _alAgotarseElTiempo,
        );
        _intentarNavegar();
      }
    });
  }

  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    _iniciarAnimacion();
  }

  /// Carga las imágenes del splash, quita el arranque nativo y empieza la
  /// animación: el primer cuadro visible es idéntico al arranque nativo.
  /// Si las imágenes tardan, arranca igual al segundo.
  Future<void> _iniciarAnimacion() async {
    try {
      await Future.any([
        Future.wait([
          precacheImage(const AssetImage(AppAssets.splash), context),
          precacheImage(const AssetImage(AppAssets.logoArranque), context),
        ]),
        Future<void>.delayed(const Duration(seconds: 1)),
      ]);
    } catch (_) {
      // Si una imagen falla, el splash igual debe avanzar.
    }
    FlutterNativeSplash.remove();
    if (!mounted) return;
    _controlador.forward();
  }

  @override
  void dispose() {
    _limiteSesion?.cancel();
    _controlador.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _intentarNavegar() async {
    if (!mounted || !_tiempoCumplido || _vm.decidido) return;
    final destino = await _vm.decidir(context.read<SesionProvider>());
    if (!mounted) return;
    _navegar(destino);
  }

  /// Firebase no respondió a tiempo: se sale a login con un aviso.
  void _alAgotarseElTiempo() {
    if (!mounted) return;
    _navegar(_vm.tiempoAgotado());
  }

  void _navegar(String? destino) {
    if (destino != null) {
      _limiteSesion?.cancel();
      final error = _vm.mensajeError;
      if (error != null) SnackbarHelper.error(context, error);
      Navigator.of(context).pushReplacement(
        AppRouter.onGenerateRoute(
          RouteSettings(name: destino),
          duracion: _salida,
        ),
      );
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
      return _SplashLogo(animacion: _controlador);
    }
    return ChangeNotifierProvider.value(
      value: _vm,
      child: const _OnboardingView(),
    );
  }
}

/// Splash puro: la imagen de marca a pantalla completa, animada (ver
/// [LogoAnimado]).
class _SplashLogo extends StatelessWidget {
  final Animation<double> animacion;

  const _SplashLogo({required this.animacion});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LogoAnimado.fondo,
      body: LogoAnimado(animacion: animacion),
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
      ilustracion: IlustracionOnboarding.colorimetria,
    ),
    OnboardingPagina(
      titulo: AppStrings.onboardingTitulo2,
      descripcion: AppStrings.onboardingDescripcion2,
      ilustracion: IlustracionOnboarding.simulador,
    ),
    OnboardingPagina(
      titulo: AppStrings.onboardingTitulo3,
      descripcion: AppStrings.onboardingDescripcion3,
      ilustracion: IlustracionOnboarding.asistente,
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
                const LogoRostro(alto: 84),
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
        // Se encoge en pantallas bajas para que el texto siempre quepa.
        Flexible(
          child: FittedBox(
            child: IlustracionOnboardingView(tipo: pagina.ilustracion),
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
