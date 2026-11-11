import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../providers/me_gusta_provider.dart';

/// Corazón ❤️ de un producto, en una burbuja blanca sobre la imagen — Ana.
/// Late al marcarlo. Cuenta (anónimo) en el panel de la marca.
class BotonMeGusta extends StatefulWidget {
  final String productoId;

  const BotonMeGusta({super.key, required this.productoId});

  @override
  State<BotonMeGusta> createState() => _BotonMeGustaState();
}

class _BotonMeGustaState extends State<BotonMeGusta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _latido = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _escala = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.35), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.92), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.92, end: 1), weight: 30),
  ]).animate(CurvedAnimation(parent: _latido, curve: Curves.easeOut));

  Future<void> _alternar() async {
    final meGusta = context.read<MeGustaProvider>();
    if (!meGusta.leGusta(widget.productoId)) _latido.forward(from: 0);
    final error = await meGusta.alternar(widget.productoId);
    if (error != null && mounted) SnackbarHelper.error(context, error);
  }

  @override
  void dispose() {
    _latido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leGusta = context.select<MeGustaProvider, bool>(
      (p) => p.leGusta(widget.productoId),
    );
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: AppColors.violeta.withValues(alpha: 0.3),
        child: IconButton(
          tooltip: leGusta ? AppStrings.quitarMeGusta : AppStrings.meGusta,
          onPressed: _alternar,
          icon: ScaleTransition(
            scale: _escala,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: Icon(
                leGusta ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey(leGusta),
                color: leGusta ? AppColors.fucsia : AppColors.textoPrincipal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
