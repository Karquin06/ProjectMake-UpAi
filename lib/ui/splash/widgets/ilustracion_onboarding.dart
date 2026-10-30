import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/logo_app.dart';
import '../splash_view_model.dart';

/// Ilustraciones del onboarding armadas con piezas de la propia app (logo,
/// paleta, marco de escaneo, chat): no dependen de internet ni de fotos.
class IlustracionOnboardingView extends StatelessWidget {
  final IlustracionOnboarding tipo;

  const IlustracionOnboardingView({super.key, required this.tipo});

  static const double lado = 260;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: lado,
    height: lado,
    child: switch (tipo) {
      IlustracionOnboarding.colorimetria => const _Colorimetria(),
      IlustracionOnboarding.simulador => const _Simulador(),
      IlustracionOnboarding.asistente => const _Asistente(),
    },
  );
}

/// El logo rodeado por una paleta de colores (colorimetría personal).
class _Colorimetria extends StatelessWidget {
  const _Colorimetria();

  static const _paleta = [
    Color(0xFFE2725B), // terracota
    Color(0xFFFFB07C), // melocotón
    Color(0xFFD4AF37), // dorado
    Color(0xFF6B7B3A), // verde musgo
    Color(0xFF2747A8), // azul real
    Color(0xFFD6247A), // fucsia
    Color(0xFF8E6C8A), // ciruela
    Color(0xFFA8D5C8), // verde agua
  ];

  @override
  Widget build(BuildContext context) {
    const radio = 112.0, centro = IlustracionOnboardingView.lado / 2;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: radio * 2,
          height: radio * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: AppColors.violeta.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
        ),
        const LogoRostro(alto: 150),
        for (var i = 0; i < _paleta.length; i++)
          Positioned(
            left:
                centro +
                radio * .82 * math.cos(i * math.pi / 4 - math.pi / 2) -
                13,
            top:
                centro +
                radio * .82 * math.sin(i * math.pi / 4 - math.pi / 2) -
                13,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _paleta[i],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 4),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Celular con el rostro del logo, marco de escaneo y muestras de labial.
class _Simulador extends StatelessWidget {
  const _Simulador();

  static const _labiales = [
    Color(0xFFC8102E),
    Color(0xFFE35335),
    Color(0xFFD99AA5),
    Color(0xFF8E5A7A),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 150,
          height: 250,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.violetaOscuro,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.violeta.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFDF0F6), Color(0xFFF7D3E4)],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 30, 14, 64),
                  child: LogoRostro(alto: 150),
                ),
                // Marco de escaneo facial.
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 42, 18, 70),
                  child: CustomPaint(painter: _MarcoEscaneo()),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (var i = 0; i < _labiales.length; i++)
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _labiales[i],
                              shape: BoxShape.circle,
                              border: i == 0
                                  ? Border.all(
                                      color: AppColors.fucsia,
                                      width: 2.5,
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 18,
          top: 30,
          child: _Insignia(icono: Icons.view_in_ar, texto: AppStrings.arCorto),
        ),
      ],
    );
  }
}

class _MarcoEscaneo extends CustomPainter {
  const _MarcoEscaneo();

  @override
  void paint(Canvas canvas, Size size) {
    final pintura = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 18.0;
    final w = size.width, h = size.height;
    for (final (x, y, dx, dy) in [
      (0.0, 0.0, 1.0, 1.0),
      (w, 0.0, -1.0, 1.0),
      (0.0, h, 1.0, -1.0),
      (w, h, -1.0, -1.0),
    ]) {
      canvas
        ..drawLine(Offset(x, y), Offset(x + l * dx, y), pintura)
        ..drawLine(Offset(x, y), Offset(x, y + l * dy), pintura);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Conversación corta con el asistente sobre la paleta de la usuaria.
class _Asistente extends StatelessWidget {
  const _Asistente();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: IlustracionOnboardingView.lado,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: _Burbuja(
                texto: AppStrings.onboardingChatPregunta,
                propia: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const LogoRostro(alto: 34),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: _Burbuja(
                    texto: AppStrings.onboardingChatRespuesta,
                    propia: false,
                    pie: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final c in const [
                          Color(0xFFE2725B),
                          Color(0xFFB5653F),
                          Color(0xFF6E2C1F),
                        ])
                          Container(
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.only(right: 6, top: 8),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerRight,
              child: _Insignia(
                icono: Icons.auto_awesome,
                texto: AppStrings.onboardingChatEtiqueta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  final String texto;
  final bool propia;
  final Widget? pie;

  const _Burbuja({required this.texto, required this.propia, this.pie});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 210),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: propia ? AppColors.fucsia : Colors.white,
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: Radius.circular(propia ? 18 : 4),
        bottomRight: Radius.circular(propia ? 4 : 18),
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.violeta.withValues(alpha: 0.12),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          texto,
          style: TextStyle(
            color: propia ? Colors.white : AppColors.textoPrincipal,
            fontSize: 13,
            height: 1.3,
          ),
        ),
        ?pie,
      ],
    ),
  );
}

class _Insignia extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Insignia({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.fucsia, AppColors.violeta],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          texto,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
