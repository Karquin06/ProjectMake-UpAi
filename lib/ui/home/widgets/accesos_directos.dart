import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../home_view_model.dart';

/// Grilla de accesos directos a las funciones de la app (capítulo 8.1).
/// Los accesos deshabilitados (Escáner y Armario mientras sus banderas en
/// `AppConstants` estén apagadas) se muestran con "Próximamente".
class AccesosDirectos extends StatelessWidget {
  final List<AccesoHome> accesos;
  final bool Function(AccesoHome) estaHabilitado;
  final ValueChanged<AccesoHome> onSeleccionar;

  const AccesosDirectos({
    super.key,
    required this.accesos,
    required this.estaHabilitado,
    required this.onSeleccionar,
  });

  static IconData icono(AccesoHome acceso) => switch (acceso) {
    AccesoHome.colorimetria => Icons.face_retouching_natural,
    AccesoHome.paleta => Icons.color_lens_outlined,
    AccesoHome.outfits => Icons.checkroom_outlined,
    AccesoHome.maquillaje => Icons.brush_outlined,
    AccesoHome.asistente => Icons.smart_toy_outlined,
    AccesoHome.simuladorAr => Icons.camera_alt_outlined,
    AccesoHome.escaner => Icons.qr_code_scanner,
    AccesoHome.armario => Icons.checkroom,
  };

  static String etiqueta(AccesoHome acceso) => switch (acceso) {
    AccesoHome.colorimetria => AppStrings.accesoColorimetria,
    AccesoHome.paleta => AppStrings.accesoPaleta,
    AccesoHome.outfits => AppStrings.accesoOutfits,
    AccesoHome.maquillaje => AppStrings.accesoMaquillaje,
    AccesoHome.asistente => AppStrings.accesoAsistente,
    AccesoHome.simuladorAr => AppStrings.accesoSimulador,
    AccesoHome.escaner => AppStrings.accesoEscaner,
    AccesoHome.armario => AppStrings.accesoArmario,
  };

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: accesos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        final acceso = accesos[index];
        return _BotonAcceso(
          icono: icono(acceso),
          etiqueta: etiqueta(acceso),
          disponible: estaHabilitado(acceso),
          onTap: () => onSeleccionar(acceso),
        );
      },
    );
  }
}

class _BotonAcceso extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final bool disponible;
  final VoidCallback onTap;

  const _BotonAcceso({
    required this.icono,
    required this.etiqueta,
    required this.disponible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Opacity(
          opacity: disponible ? 1 : 0.55,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: disponible
                          ? AppColors.fondoRosaSuave
                          : AppColors.borde,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      icono,
                      color: disponible
                          ? AppColors.fucsia
                          : AppColors.textoSecundario,
                      size: 24,
                    ),
                  ),
                  if (!disponible)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.textoSecundario,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_clock,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                etiqueta,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.subtitulo.copyWith(fontSize: 11.5),
              ),
              if (!disponible)
                Text(
                  AppStrings.proximamente,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitulo.copyWith(
                    fontSize: 9.5,
                    color: AppColors.textoSecundario,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
