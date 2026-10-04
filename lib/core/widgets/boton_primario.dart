import 'package:flutter/material.dart';
import '../theme/app_gradients.dart';
import '../theme/app_text_styles.dart';

/// Botón principal de la app: fondo en degradado de marca, esquinas
/// redondeadas y estado de carga opcional. Si [onPressed] es `null` se
/// muestra deshabilitado (atenuado y sin respuesta al toque).
class BotonPrimario extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final IconData? icono;
  final bool cargando;

  const BotonPrimario({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    final deshabilitado = onPressed == null && !cargando;
    return Opacity(
      opacity: deshabilitado ? 0.5 : 1,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppGradients.marca,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: cargando ? null : onPressed,
              child: Center(
                child: cargando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              texto,
                              style: AppTextStyles.botonPrimario,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (icono != null) ...[
                            const SizedBox(width: 8),
                            Icon(icono, color: Colors.white, size: 18),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
