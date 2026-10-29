import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/boton_primario.dart';
import '../../../models/maquillaje_ar.dart';
import '../../../models/producto_maquillaje.dart';

/// Todos los accesos consultan las mismas capacidades que el motor de capas.
class BotonProbarAr extends StatelessWidget {
  const BotonProbarAr({
    super.key,
    required this.producto,
    this.compacto = false,
  });
  final ProductoMaquillaje producto;
  final bool compacto;
  @override
  Widget build(BuildContext context) {
    final registro = RegistroEfectosAr();
    if (!producto.activo) return const SizedBox.shrink();
    if (!registro.admite(producto)) {
      return Text(
        registro.paraProducto(producto)?.disponible == true
            ? AppStrings.arProductoSinTono
            : AppStrings.arNoImplementado,
      );
    }
    void abrir() => Navigator.of(
      context,
    ).pushNamed(AppRoutes.simuladorAr, arguments: producto.id);
    return compacto
        ? TextButton.icon(
            onPressed: abrir,
            icon: const Icon(Icons.face_retouching_natural),
            label: const Text(AppStrings.probarEnAr),
          )
        : BotonPrimario(
            texto: AppStrings.probarEnAr,
            icono: Icons.camera_alt_outlined,
            onPressed: abrir,
          );
  }
}
