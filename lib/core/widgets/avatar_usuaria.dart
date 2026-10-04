import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../utils/formatters.dart';

/// Avatar circular de la usuaria: muestra la foto si hay [fotoUrl] (y
/// carga bien) o, si no, sus iniciales sobre el degradado de marca.
/// Con [mostrarEditar] aparece un botón de cámara (editar perfil).
class AvatarUsuaria extends StatelessWidget {
  final String? fotoUrl;
  final String nombre;
  final double radio;
  final VoidCallback? onTap;
  final bool mostrarEditar;

  const AvatarUsuaria({
    super.key,
    required this.nombre,
    this.fotoUrl,
    this.radio = 28,
    this.onTap,
    this.mostrarEditar = false,
  });

  @override
  Widget build(BuildContext context) {
    final diametro = radio * 2;
    final iniciales = _Iniciales(
      texto: Formateadores.iniciales(nombre),
      tamano: radio * 0.75,
    );
    final tieneFoto = fotoUrl != null && fotoUrl!.trim().isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: diametro,
        height: diametro,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: diametro,
              height: diametro,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.marca,
              ),
              child: ClipOval(
                child: tieneFoto
                    ? Image.network(
                        fotoUrl!,
                        width: diametro,
                        height: diametro,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => iniciales,
                        loadingBuilder: (_, child, progreso) =>
                            progreso == null ? child : iniciales,
                      )
                    : iniciales,
              ),
            ),
            if (mostrarEditar)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.all(radio * 0.12),
                  decoration: BoxDecoration(
                    color: AppColors.fucsia,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.superficie, width: 2),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: radio * 0.4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Iniciales extends StatelessWidget {
  final String texto;
  final double tamano;

  const _Iniciales({required this.texto, required this.tamano});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        texto,
        style: TextStyle(
          color: AppColors.textoSobreGradiente,
          fontSize: tamano,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
