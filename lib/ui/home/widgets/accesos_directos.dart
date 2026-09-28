import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class _AccesoDirectoData {
  final IconData icono;
  final String etiqueta;

  /// `false` para funcionalidades de fases futuras (ver capítulo 8.5)
  /// que aún no forman parte del alcance del MVP, como el Armario
  /// inteligente (Fase 4). Estos accesos se muestran deshabilitados
  /// con la etiqueta "Próximamente".
  final bool disponible;

  const _AccesoDirectoData(this.icono, this.etiqueta, {this.disponible = true});
}

/// Grilla de accesos directos a las funciones del alcance funcional
/// (capítulo 8.1: colorimetría, paleta, recomendaciones, asistente y
/// simulador AR) más las funcionalidades de fases futuras (capítulo 8.5:
/// Escáner OCR — Fase 3 — y Armario inteligente — Fase 4), estas
/// últimas mostradas como "Próximamente".
class AccesosDirectos extends StatelessWidget {
  const AccesosDirectos({super.key});

  static const List<_AccesoDirectoData> _accesos = [
    _AccesoDirectoData(Icons.face_retouching_natural, 'Colorimetría'),
    _AccesoDirectoData(Icons.color_lens_outlined, 'Mi paleta'),
    _AccesoDirectoData(Icons.checkroom_outlined, 'Outfits'),
    _AccesoDirectoData(Icons.brush_outlined, 'Maquillaje'),
    _AccesoDirectoData(Icons.smart_toy_outlined, 'Asistente IA'),
    _AccesoDirectoData(Icons.camera_alt_outlined, 'Simulador AR'),
    _AccesoDirectoData(Icons.qr_code_scanner, 'Escáner', disponible: false),
    _AccesoDirectoData(Icons.checkroom, 'Armario', disponible: false),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _accesos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final acceso = _accesos[index];
        return _BotonAcceso(
          icono: acceso.icono,
          etiqueta: acceso.etiqueta,
          disponible: acceso.disponible,
        );
      },
    );
  }
}

class _BotonAcceso extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final bool disponible;

  const _BotonAcceso({
    required this.icono,
    required this.etiqueta,
    this.disponible = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: disponible
            ? () {
                // TODO: conectar navegación según la funcionalidad seleccionada.
              }
            : () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        '$etiqueta estará disponible en una fase futura '
                        'del proyecto.',
                      ),
                    ),
                  );
              },
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
                  'Próximamente',
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
