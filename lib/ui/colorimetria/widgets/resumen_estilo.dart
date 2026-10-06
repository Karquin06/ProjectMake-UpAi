import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/paleta_provider.dart';
import '../../../models/perfil_colorimetria_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/widgets/paleta_chips.dart';
import '../../../core/widgets/tarjeta_base.dart';
import '../../../models/enums.dart';
import '../../../models/paleta_model.dart';
import 'detalle_subtono.dart';
import 'diseno_responsivo.dart';

/// [ResumenEstilo] con la paleta de [PaletaProvider] para [perfil]. No
/// muestra nada mientras la paleta carga (o si no hay provider).
class ResumenEstiloDePerfil extends StatelessWidget {
  final PerfilColorimetria perfil;

  const ResumenEstiloDePerfil({super.key, required this.perfil});

  @override
  Widget build(BuildContext context) {
    final paleta = context.watch<PaletaProvider?>()?.paleta;
    if (paleta == null || paleta.estacion != perfil.estacionColor) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ResumenEstilo(paleta: paleta, subtono: perfil.subtono),
    );
  }
}

/// Adelanto del resultado aplicado a ropa y maquillaje (el detalle completo
/// está en la paleta).
class ResumenEstilo extends StatelessWidget {
  final Paleta paleta;
  final Subtono subtono;

  const ResumenEstilo({super.key, required this.paleta, required this.subtono});

  @override
  Widget build(BuildContext context) {
    final m = paleta.maquillaje;
    return FilaOColumna(
      a: _Tarjeta(
        icono: Icons.checkroom_outlined,
        titulo: AppStrings.paraTuRopa,
        colores: [...paleta.coloresRecomendados.take(5), ...paleta.neutros.take(3)],
      ),
      b: _Tarjeta(
        icono: Icons.brush_outlined,
        titulo: AppStrings.paraTuMaquillaje,
        colores: [...m.labiales.take(3), ...m.rubores.take(2), ...m.sombras.take(3)],
        nota: DetalleSubtono.consejoBase(subtono),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final List<ColorPaleta> colores;
  final String? nota;

  const _Tarjeta({
    required this.icono,
    required this.titulo,
    required this.colores,
    this.nota,
  });

  @override
  Widget build(BuildContext context) {
    return TarjetaBase(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: AppColors.fucsia),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: AppTextStyles.subtitulo.copyWith(
                  color: AppColors.textoPrincipal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PaletaChips(
            colores: [for (final c in colores) ColorUtils.desdeHex(c.hex)],
            nombres: [for (final c in colores) c.nombre],
            tamano: 30,
          ),
          if (nota != null) ...[
            const SizedBox(height: 12),
            Text(nota!, style: AppTextStyles.subtitulo.copyWith(fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
