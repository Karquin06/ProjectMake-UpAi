import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Poppins';

  static const TextStyle logo = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: AppColors.textoSobreGradiente,
    letterSpacing: 1.1,
  );

  static const TextStyle tituloPantalla = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textoPrincipal,
  );

  static const TextStyle subtitulo = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textoSecundario,
    height: 1.4,
  );

  static const TextStyle etiquetaCampo = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textoSecundario,
    letterSpacing: 0.6,
  );

  static const TextStyle botonPrimario = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textoSobreGradiente,
  );

  static const TextStyle botonSecundario = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textoPrincipal,
  );

  static const TextStyle enlace = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.fucsia,
  );
}
