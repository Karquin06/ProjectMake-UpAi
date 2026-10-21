import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/tarjeta_base.dart';

/// Calificar la recomendación de 1 a 5 estrellas. Se guarda con
/// `recomendacion_repository` y mejora el orden de las siguientes.
class CalificacionRecomendacion extends StatelessWidget {
  final int? valor;
  final bool guardando;
  final ValueChanged<int> onCalificar;

  const CalificacionRecomendacion({
    super.key,
    required this.valor,
    required this.onCalificar,
    this.guardando = false,
  });

  static const colorEstrella = Color(0xFFF5A623);

  @override
  Widget build(BuildContext context) {
    final estilos = context.estilosTexto;
    final actual = valor ?? 0;
    return TarjetaBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.califica,
            style: estilos.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            AppStrings.calificaAyuda,
            style: estilos.bodySmall?.copyWith(
              color: AppColors.textoSecundario,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: AppStrings.estrellas(i),
                  iconSize: 34,
                  onPressed: guardando ? null : () => onCalificar(i),
                  icon: Icon(
                    i <= actual
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: i <= actual ? colorEstrella : AppColors.borde,
                  ),
                ),
            ],
          ),
          if (guardando)
            const LinearProgressIndicator(color: AppColors.fucsia),
        ],
      ),
    );
  }
}
