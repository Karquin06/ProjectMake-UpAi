import 'package:flutter/material.dart';
import '../../../models/perfil_colorimetria_model.dart';
import 'detalle_subtono.dart';
import 'tarjeta_resultado.dart';

/// Medidas para que las pantallas de colorimetría se adapten al ancho:
/// en teléfono todo va en una columna; en pantallas anchas (web en PC,
/// tabletas) el contenido usa dos columnas y no pasa de [anchoMaximo].
class DisenoResponsivo {
  DisenoResponsivo._();

  static const anchoMaximo = 1100.0;
  static const anchoDosColumnas = 840.0;

  static bool dosColumnas(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= anchoDosColumnas;
}

/// Centra [child] y limita su ancho a [maxAncho].
class ContenidoCentrado extends StatelessWidget {
  final Widget child;
  final double maxAncho;

  const ContenidoCentrado({
    super.key,
    required this.child,
    this.maxAncho = DisenoResponsivo.anchoMaximo,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxAncho),
        child: child,
      ),
    );
  }
}

/// Coloca [a] y [b] lado a lado en pantallas anchas o uno debajo del otro
/// en el teléfono.
class FilaOColumna extends StatelessWidget {
  final Widget a;
  final Widget b;
  final double espacio;

  const FilaOColumna({
    super.key,
    required this.a,
    required this.b,
    this.espacio = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (!DisenoResponsivo.dosColumnas(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [a, SizedBox(height: espacio), b],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          SizedBox(width: espacio),
          Expanded(child: b),
        ],
      ),
    );
  }
}

/// Resultado + explicación del subtono, responsivo.
class ResumenPerfil extends StatelessWidget {
  final PerfilColorimetria perfil;

  const ResumenPerfil({super.key, required this.perfil});

  @override
  Widget build(BuildContext context) => FilaOColumna(
        a: TarjetaResultado(perfil: perfil),
        b: DetalleSubtono(subtono: perfil.subtono),
      );
}
