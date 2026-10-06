import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/errors/firebase_error_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/boton_primario.dart';

/// Hoja inferior con el consentimiento biométrico: qué se captura, para qué,
/// que se borra y cómo pedir la eliminación. La casilla es obligatoria y
/// "Continuar" queda deshabilitado hasta marcarla.
///
/// Solo muestra; guardar la aceptación (fecha y versión) y saltarla si ya
/// se aceptó la versión vigente lo hace `ColorimetriaViewModel`.
class HojaConsentimientoBiometrico extends StatefulWidget {
  /// Se llama al tocar "Continuar" (p. ej. para guardar la aceptación).
  /// Si lanza error la hoja sigue abierta.
  final Future<void> Function() onAceptar;

  const HojaConsentimientoBiometrico({super.key, required this.onAceptar});

  /// Abre la hoja. Devuelve `true` si la usuaria aceptó.
  static Future<bool> mostrar(
    BuildContext context, {
    required Future<void> Function() onAceptar,
  }) async {
    final aceptado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => HojaConsentimientoBiometrico(onAceptar: onAceptar),
    );
    return aceptado ?? false;
  }

  @override
  State<HojaConsentimientoBiometrico> createState() =>
      _HojaConsentimientoBiometricoState();
}

class _HojaConsentimientoBiometricoState
    extends State<HojaConsentimientoBiometrico> {
  bool _aceptado = false;
  bool _guardando = false;

  Future<void> _continuar() async {
    setState(() => _guardando = true);
    try {
      await widget.onAceptar();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      SnackbarHelper.error(context, FirebaseErrorMapper.mensaje(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.privacy_tip_outlined,
                color: AppColors.fucsia, size: 32),
            const SizedBox(height: 12),
            const Text(AppStrings.consentimientoTitulo,
                style: AppTextStyles.tituloPantalla),
            const SizedBox(height: 16),
            for (final texto in const [
              AppStrings.consentimientoQueCapturamos,
              AppStrings.consentimientoParaQue,
              AppStrings.consentimientoBorrado,
              AppStrings.consentimientoEliminacion,
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(texto, style: AppTextStyles.subtitulo),
              ),
            const SizedBox(height: 4),
            CheckboxListTile(
              value: _aceptado,
              onChanged: _guardando
                  ? null
                  : (v) => setState(() => _aceptado = v ?? false),
              activeColor: AppColors.fucsia,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                AppStrings.consentimientoCasilla,
                style: TextStyle(color: AppColors.textoPrincipal),
              ),
            ),
            const SizedBox(height: 12),
            BotonPrimario(
              texto: AppStrings.continuar,
              cargando: _guardando,
              onPressed: _aceptado ? _continuar : null,
            ),
          ],
        ),
      ),
    );
  }
}
