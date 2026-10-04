import 'package:flutter/material.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_text_styles.dart';

/// Tarjeta que resume el resultado de colorimetría de la usuaria

class ResumenColorimetriaCard extends StatelessWidget {
  final bool tieneColorimetria;
  final String estacionColor;
  final VoidCallback onTap;

  const ResumenColorimetriaCard({
    super.key,
    required this.tieneColorimetria,
    required this.estacionColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap, // TODO: conectar navegación a colorimetria_view.
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppGradients.marca,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.palette_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tieneColorimetria
                          ? 'Tu estación de color'
                          : 'Aún no tienes un análisis',
                      style: AppTextStyles.subtitulo.copyWith(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tieneColorimetria
                          ? estacionColor
                          : 'Analiza tu colorimetría ahora',
                      style: AppTextStyles.botonPrimario,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
