import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/datetime_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/asistente_provider.dart';

/// Burbuja de un mensaje del chat: la usuaria a la derecha (fucsia) y el
/// asistente a la izquierda (blanca), con la hora. Si no se pudo enviar,
/// se marca en rojo y al tocarla se reintenta.
class BurbujaMensaje extends StatelessWidget {
  final MensajeChat mensaje;
  final VoidCallback? onReintentar;

  const BurbujaMensaje({super.key, required this.mensaje, this.onReintentar});

  /// Quita el formato Markdown que a veces manda la IA (`**negrita**`,
  /// `# títulos`, `* viñetas`) para mostrar texto limpio.
  static String textoLimpio(String texto) => texto
      .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1]!)
      .replaceAllMapped(RegExp(r'^#{1,6}\s*', multiLine: true), (_) => '')
      .replaceAllMapped(RegExp(r'^\s*[\*\-]\s+', multiLine: true), (_) => '• ')
      .trim();

  @override
  Widget build(BuildContext context) {
    final esUsuaria = mensaje.esUsuaria;
    final conError = mensaje.estado == EstadoMensaje.error;
    final estilos = context.estilosTexto;
    final colorTexto = esUsuaria ? Colors.white : AppColors.textoPrincipal;
    const radio = Radius.circular(18);

    final burbuja = Container(
      constraints: BoxConstraints(maxWidth: context.anchoPantalla * 0.78),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: esUsuaria ? AppColors.fucsia : AppColors.superficie,
        borderRadius: BorderRadius.only(
          topLeft: radio,
          topRight: radio,
          bottomLeft: esUsuaria ? radio : const Radius.circular(4),
          bottomRight: esUsuaria ? const Radius.circular(4) : radio,
        ),
        border: conError
            ? Border.all(color: AppColors.error, width: 1.5)
            : (esUsuaria ? null : Border.all(color: AppColors.borde)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            esUsuaria ? mensaje.contenido : textoLimpio(mensaje.contenido),
            style: estilos.bodyMedium?.copyWith(
              color: colorTexto,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mensaje.fecha.hora,
                style: estilos.labelSmall?.copyWith(
                  color: esUsuaria
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppColors.textoSecundario,
                ),
              ),
              if (esUsuaria && mensaje.estado == EstadoMensaje.enviando) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.schedule,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: esUsuaria
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: conError ? onReintentar : null,
            child: burbuja,
          ),
          if (conError)
            InkWell(
              onTap: onReintentar,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh, size: 14, color: AppColors.error),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.mensajeNoEnviado,
                      style: estilos.labelSmall?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Burbuja "Escribiendo..." mientras el asistente responde.
class IndicadorEscribiendo extends StatelessWidget {
  const IndicadorEscribiendo({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borde),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.fucsia,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppStrings.asistenteEscribiendo,
              style: context.estilosTexto.bodySmall?.copyWith(
                color: AppColors.textoSecundario,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
