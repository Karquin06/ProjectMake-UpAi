import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

/// Campo para escribir al asistente, con límite de caracteres. El botón de
/// enviar se deshabilita mientras el asistente responde o si está vacío.
class CampoMensaje extends StatefulWidget {
  final bool habilitado;
  final int largoMaximo;
  final ValueChanged<String> onEnviar;

  const CampoMensaje({
    super.key,
    required this.habilitado,
    required this.largoMaximo,
    required this.onEnviar,
  });

  @override
  State<CampoMensaje> createState() => _CampoMensajeState();
}

class _CampoMensajeState extends State<CampoMensaje> {
  final _controlador = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Para activar o desactivar el botón según haya texto.
    _controlador.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  bool get _puedeEnviar =>
      widget.habilitado && _controlador.text.trim().isNotEmpty;

  void _enviar() {
    if (!_puedeEnviar) return;
    final texto = _controlador.text.trim();
    _controlador.clear();
    widget.onEnviar(texto);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.violeta.withValues(alpha: 0.1),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controlador,
                maxLength: widget.largoMaximo,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _enviar(),
                decoration: InputDecoration(
                  hintText: AppStrings.escribeTuPregunta,
                  filled: true,
                  fillColor: AppColors.fondoClaro,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.fucsia),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox.square(
              dimension: 50,
              child: IconButton.filled(
                tooltip: AppStrings.enviar,
                onPressed: _puedeEnviar ? _enviar : null,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.fucsia,
                  disabledBackgroundColor: AppColors.borde,
                ),
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
