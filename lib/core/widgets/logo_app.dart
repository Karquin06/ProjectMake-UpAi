import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../constants/app_strings.dart';

/// Rostro del logo de Make Up AI (PNG transparente) a la altura indicada.
class LogoRostro extends StatelessWidget {
  final double alto;

  const LogoRostro({super.key, required this.alto});

  @override
  Widget build(BuildContext context) => Image.asset(
    AppAssets.logoRostro,
    height: alto,
    fit: BoxFit.contain,
    semanticLabel: AppStrings.nombreApp,
  );
}
