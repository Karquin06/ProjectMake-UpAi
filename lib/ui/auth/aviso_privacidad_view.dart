import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/boton_primario.dart';
import '../../core/widgets/tarjeta_base.dart';

/// Aviso de privacidad con scroll y botón "Acepto".
///
/// Al tocar "Acepto" cierra la pantalla devolviendo `true`:
/// ```dart
/// final acepto = await context.irA<bool>(AppRoutes.avisoPrivacidad);
/// ```
/// Para solo consultarlo (p. ej. desde Perfil) pasa `false` como argumento
/// y no se muestra el botón.
class AvisoPrivacidadView extends StatelessWidget {
  const AvisoPrivacidadView({super.key});

  @override
  Widget build(BuildContext context) {
    final mostrarAceptar = context.argumentos<bool>() ?? true;

    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(title: const Text(AppStrings.avisoPrivacidadTitulo)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Scrollbar(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    Text(
                      AppStrings.avisoPrivacidadVersion(
                        AppConstants.versionConsentimiento,
                      ),
                      style: AppTextStyles.subtitulo.copyWith(fontSize: 12.5),
                    ),
                    const SizedBox(height: 14),
                    for (final (titulo, texto)
                        in AppStrings.avisoPrivacidadSecciones) ...[
                      TarjetaBase(
                        conSombra: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(titulo, style: AppTextStyles.botonSecundario),
                            const SizedBox(height: 6),
                            Text(texto, style: AppTextStyles.subtitulo),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            if (mostrarAceptar)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: BotonPrimario(
                  texto: AppStrings.botonAcepto,
                  onPressed: () => context.volver(true),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
