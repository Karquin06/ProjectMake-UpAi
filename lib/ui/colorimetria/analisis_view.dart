import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/boton_primario.dart';
import '../../core/widgets/boton_secundario.dart';
import '../../core/widgets/estado_vacio.dart';
import '../../core/widgets/logo_app.dart';
import '../../data/services/colorimetria_service.dart';
import '../../providers/colorimetria_provider.dart';
import 'analisis_view_model.dart';

/// Recibe la selfie (bytes JPEG) como argumento de la ruta, la analiza
/// (con el logo animado mientras tanto) y abre el resultado.
class AnalisisView extends StatelessWidget {
  const AnalisisView({super.key});

  @override
  Widget build(BuildContext context) {
    final selfie = context.argumentos<Uint8List>();
    final uid = context.read<ColorimetriaProvider>().uidSesion;
    if (selfie == null || uid == null) {
      // Se llegó sin foto (p. ej. al recargar en web): volver a tomarla.
      return Scaffold(
        body: EstadoVacio(
          icono: Icons.photo_camera_front_outlined,
          titulo: AppStrings.errorAnalisisTitulo,
          textoBoton: AppStrings.tomarOtraFoto,
          onPressed: () => context.reemplazarCon(AppRoutes.capturaSelfie),
        ),
      );
    }
    return ChangeNotifierProvider(
      create: (c) {
        final vm = AnalisisViewModel(
          colorimetria: c.read<ColorimetriaService>(),
          uid: uid,
          selfie: selfie,
        );
        // Diferido: `create` corre durante el build.
        Future.microtask(vm.analizar);
        return vm;
      },
      child: const _Analisis(),
    );
  }
}

class _Analisis extends StatefulWidget {
  const _Analisis();

  @override
  State<_Analisis> createState() => _AnalisisState();
}

class _AnalisisState extends State<_Analisis> {
  late final AnalisisViewModel _vm = context.read<AnalisisViewModel>();

  @override
  void initState() {
    super.initState();
    _vm.addListener(_alCambiar);
  }

  @override
  void dispose() {
    _vm.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    if (_vm.estado == EstadoAnalisis.listo && mounted) {
      _vm.removeListener(_alCambiar);
      context.reemplazarCon(AppRoutes.resultado, argumentos: _vm.perfil);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AnalisisViewModel>();
    return PopScope(
      // No se sale a mitad del análisis (la foto quedaría a medias).
      canPop: vm.estado == EstadoAnalisis.error,
      child: Scaffold(
        backgroundColor: AppColors.fondoClaro,
        appBar: AppBar(
          title: const Text(AppStrings.analisisTitulo),
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: vm.estado == EstadoAnalisis.error,
          elevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: vm.estado == EstadoAnalisis.error
                    ? _Error(vm: vm)
                    : _Progreso(vm: vm),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Progreso extends StatelessWidget {
  final AnalisisViewModel vm;

  const _Progreso({required this.vm});

  @override
  Widget build(BuildContext context) {
    final subiendo = vm.estado == EstadoAnalisis.subiendo;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _LogoAnalizando(),
        const SizedBox(height: 28),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            vm.mensaje,
            key: ValueKey(vm.mensaje),
            textAlign: TextAlign.center,
            style: AppTextStyles.tituloPantalla.copyWith(fontSize: 20),
          ),
        ),
        // Subida: progreso real en texto.
        if (subiendo) ...[
          const SizedBox(height: 8),
          Text(
            '${(vm.progreso * 100).round()} %',
            style: AppTextStyles.subtitulo.copyWith(
              color: AppColors.fucsia,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          AppStrings.analisisNoSeGuardaFoto,
          textAlign: TextAlign.center,
          style: AppTextStyles.subtitulo.copyWith(fontSize: 13),
        ),
      ],
    );
  }
}

/// El rostro del logo late con un resplandor rosado mientras una línea de
/// escaneo lo recorre de arriba abajo.
class _LogoAnalizando extends StatefulWidget {
  const _LogoAnalizando();

  @override
  State<_LogoAnalizando> createState() => _LogoAnalizandoState();
}

class _LogoAnalizandoState extends State<_LogoAnalizando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animacion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  static const double _alto = 190;

  @override
  void dispose() {
    _animacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: AnimatedBuilder(
        animation: _animacion,
        builder: (context, logo) {
          final t = _animacion.value;
          final latido = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
          // La línea baja en la primera parte del ciclo y descansa al final.
          final barrido = (t / 0.8).clamp(0.0, 1.0);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.fucsiaClaro.withValues(
                        alpha: 0.18 + 0.17 * latido,
                      ),
                      AppColors.fucsiaClaro.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              Transform.scale(scale: 0.97 + 0.05 * latido, child: logo),
              if (barrido < 1)
                Positioned(
                  top: 120 - _alto / 2 + _alto * barrido - 2,
                  left: 40,
                  right: 40,
                  child: Opacity(
                    opacity: math.sin(barrido * math.pi),
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.fucsia.withValues(alpha: 0),
                            AppColors.fucsia,
                            AppColors.fucsia.withValues(alpha: 0),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.fucsia.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        child: const LogoRostro(alto: _alto),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final AnalisisViewModel vm;

  const _Error({required this.vm});

  @override
  Widget build(BuildContext context) {
    void otraFoto() => context.reemplazarCon(AppRoutes.capturaSelfie);
    final reintentar = vm.puedeReintentar && !vm.sugiereOtraFoto;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          vm.sugiereOtraFoto ? Icons.no_photography_outlined : Icons.wifi_off,
          size: 64,
          color: AppColors.error,
        ),
        const SizedBox(height: 16),
        const Text(
          AppStrings.errorAnalisisTitulo,
          textAlign: TextAlign.center,
          style: AppTextStyles.tituloPantalla,
        ),
        const SizedBox(height: 8),
        Text(
          vm.error ?? AppStrings.errorInesperado,
          textAlign: TextAlign.center,
          style: AppTextStyles.subtitulo,
        ),
        const SizedBox(height: 32),
        // La acción recomendada va primero (botón principal).
        if (reintentar) ...[
          BotonPrimario(texto: AppStrings.reintentar, onPressed: vm.analizar),
          const SizedBox(height: 12),
          BotonSecundario(
            texto: AppStrings.tomarOtraFoto,
            icono: const Icon(
              Icons.photo_camera_front_outlined,
              color: AppColors.fucsia,
            ),
            onPressed: otraFoto,
          ),
        ] else
          BotonPrimario(
            texto: AppStrings.tomarOtraFoto,
            icono: Icons.photo_camera_front_outlined,
            onPressed: otraFoto,
          ),
      ],
    );
  }
}
