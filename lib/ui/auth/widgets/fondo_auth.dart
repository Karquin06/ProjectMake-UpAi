import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

/// Fondo de las pantallas de acceso: rosado suave con ondas en las
/// esquinas y destellos de marca.
class FondoAuth extends StatelessWidget {
  final Widget child;

  const FondoAuth({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDF0F6), Color(0xFFFBE6F0)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _Ondas())),
          ),
          const Positioned(top: 70, right: 28, child: _Destello(30)),
          const Positioned(top: 112, right: 70, child: _Destello(18)),
          const Positioned(bottom: 90, left: 22, child: _Destello(26)),
          const Positioned(bottom: 62, left: 54, child: _Destello(14)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// Ondas rosadas en la esquina superior izquierda y la inferior derecha.
class _Ondas extends CustomPainter {
  const _Ondas();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final suave = Paint()..color = AppColors.fucsiaClaro.withValues(alpha: .12);
    final fuerte = Paint()..color = AppColors.fucsiaClaro.withValues(alpha: .2);

    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(w * .42, 0)
        ..quadraticBezierTo(w * .18, h * .05, w * .08, h * .16)
        ..quadraticBezierTo(w * .03, h * .22, 0, h * .24)
        ..close(),
      suave,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(w * .2, 0)
        ..quadraticBezierTo(w * .06, h * .05, 0, h * .12)
        ..close(),
      fuerte,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w, h)
        ..lineTo(w * .5, h)
        ..quadraticBezierTo(w * .78, h * .96, w * .9, h * .86)
        ..quadraticBezierTo(w * .97, h * .8, w, h * .78)
        ..close(),
      suave,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w, h)
        ..lineTo(w * .74, h)
        ..quadraticBezierTo(w * .92, h * .96, w, h * .89)
        ..close(),
      fuerte,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Destello extends StatelessWidget {
  final double tamano;

  const _Destello(this.tamano);

  @override
  Widget build(BuildContext context) => Icon(
    Icons.auto_awesome,
    size: tamano,
    color: AppColors.fucsiaClaro.withValues(alpha: .55),
  );
}

/// Marca arriba de los formularios de acceso: el rostro del logo, el
/// nombre y el eslogan.
class EncabezadoAuth extends StatelessWidget {
  const EncabezadoAuth({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          AppAssets.logoRostro,
          height: 130,
          semanticLabel: AppStrings.nombreApp,
        ),
        const SizedBox(height: 10),
        const NombreApp(tamano: 34),
        const SizedBox(height: 4),
        Text(
          AppStrings.eslogan,
          style: TextStyle(
            fontSize: 12.5,
            letterSpacing: 2,
            color: AppColors.textoPrincipal.withValues(alpha: .85),
          ),
        ),
      ],
    );
  }
}

/// "MAKE UP AI" con "AI" en fucsia.
class NombreApp extends StatelessWidget {
  final double tamano;

  const NombreApp({super.key, required this.tamano});

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: tamano,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: AppColors.violetaOscuro,
      height: 1.1,
    );
    return RichText(
      text: TextSpan(
        style: estilo,
        children: const [
          TextSpan(text: 'MAKE UP '),
          TextSpan(
            text: 'AI',
            style: TextStyle(color: AppColors.fucsia),
          ),
        ],
      ),
    );
  }
}

/// Estilo de los campos en las pantallas de acceso: borde rosado suave y
/// relleno blanco (login) o rosado muy claro (registro).
ThemeData temaCamposAuth(BuildContext context, {Color? relleno}) {
  final tema = Theme.of(context);
  OutlineInputBorder borde(Color color, [double ancho = 1.2]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: ancho),
      );
  return tema.copyWith(
    inputDecorationTheme: tema.inputDecorationTheme.copyWith(
      fillColor: relleno ?? Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: borde(AppColors.borde),
      enabledBorder: borde(AppColors.borde),
      focusedBorder: borde(AppColors.fucsia, 1.6),
      errorBorder: borde(AppColors.error),
      focusedErrorBorder: borde(AppColors.error, 1.6),
      hintStyle: TextStyle(
        color: AppColors.textoSecundario.withValues(alpha: .7),
      ),
    ),
  );
}
