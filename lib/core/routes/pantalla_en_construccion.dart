import 'package:flutter/material.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../widgets/estado_vacio.dart';

/// Pantalla temporal que muestra el router mientras la vista real de una
/// ruta no existe. Indica qué pantalla es y quién es su responsable.
class PantallaEnConstruccion extends StatelessWidget {
  final String pantalla;
  final String responsable;
  final String titulo;

  const PantallaEnConstruccion({
    super.key,
    required this.pantalla,
    required this.responsable,
    this.titulo = AppStrings.enConstruccion,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(),
      body: EstadoVacio(
        icono: Icons.construction_outlined,
        titulo: titulo,
        mensaje:
            '${AppStrings.enConstruccionDescripcion}\n\n'
            '${AppStrings.pantallaResponsable(pantalla, responsable)}',
        textoBoton: Navigator.of(context).canPop() ? AppStrings.volver : null,
        onPressed: Navigator.of(context).canPop()
            ? () => Navigator.of(context).pop()
            : null,
      ),
    );
  }
}
