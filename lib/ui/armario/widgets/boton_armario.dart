import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../models/elemento_armario.dart';
import '../../../providers/armario_provider.dart';

/// Acción reutilizable en los detalles del catálogo y las recomendaciones.
class BotonArmario extends StatelessWidget {
  const BotonArmario({super.key, required this.elemento});
  final ElementoArmario elemento;
  @override
  Widget build(BuildContext context) {
    final armario = context.watch<ArmarioProvider>();
    final guardado = armario.contiene(elemento);
    return OutlinedButton.icon(
      onPressed: armario.cargando || armario.guardando
          ? null
          : () async {
              final ok = await (guardado
                  ? armario.quitar(elemento)
                  : armario.agregar(elemento));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? guardado
                              ? AppStrings.armarioQuitado
                              : AppStrings.armarioGuardado
                        : armario.error ?? AppStrings.armarioErrorGuardado,
                  ),
                ),
              );
            },
      icon: Icon(guardado ? Icons.bookmark : Icons.bookmark_add_outlined),
      label: Text(
        guardado ? AppStrings.armarioQuitar : AppStrings.armarioAgregar,
      ),
    );
  }
}
