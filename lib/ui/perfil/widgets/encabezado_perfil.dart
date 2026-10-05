import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/avatar_usuaria.dart';

/// Avatar, nombre y correo de la usuaria en la parte superior del perfil.
class EncabezadoPerfil extends StatelessWidget {
  final String nombre;
  final String correo;
  final String? fotoUrl;
  final VoidCallback? onTapAvatar;

  const EncabezadoPerfil({
    super.key,
    required this.nombre,
    required this.correo,
    this.fotoUrl,
    this.onTapAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AvatarUsuaria(
          nombre: nombre,
          fotoUrl: fotoUrl,
          radio: 46,
          onTap: onTapAvatar,
          mostrarEditar: onTapAvatar != null,
        ),
        const SizedBox(height: 14),
        Text(
          nombre,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.tituloPantalla.copyWith(fontSize: 21),
        ),
        const SizedBox(height: 4),
        Text(
          correo,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.subtitulo,
        ),
      ],
    );
  }
}
