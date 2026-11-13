import 'dart:async';
import 'package:flutter/widgets.dart';
import '../utils/pantalla_segura.dart';

/// Protege a [child] con `FLAG_SECURE` mientras está en pantalla
/// (ver [PantallaSegura]). Úsalo en pantallas que muestran el rostro.
class PantallaProtegida extends StatefulWidget {
  const PantallaProtegida({super.key, required this.child});

  final Widget child;

  @override
  State<PantallaProtegida> createState() => _PantallaProtegidaState();
}

class _PantallaProtegidaState extends State<PantallaProtegida> {
  @override
  void initState() {
    super.initState();
    unawaited(PantallaSegura.activar());
  }

  @override
  void dispose() {
    unawaited(PantallaSegura.desactivar());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
