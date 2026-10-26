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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.superficie,
        border: Border(top: BorderSide(color: AppColors.borde)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
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
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              // Alinea el botón con el campo (el contador ocupa abajo).
              padding: const EdgeInsets.only(bottom: 22),
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
