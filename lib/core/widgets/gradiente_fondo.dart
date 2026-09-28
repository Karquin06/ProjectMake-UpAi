import 'package:flutter/material.dart';

class GradienteFondo extends StatelessWidget {
  final Gradient gradient;
  final Widget child;

  const GradienteFondo({
    super.key,
    required this.gradient,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(gradient: gradient),
      child: child,
    );
  }
}
