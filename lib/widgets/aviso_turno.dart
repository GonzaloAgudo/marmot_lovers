import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Destello ámbar por los bordes de la pantalla cuando te toca a ti.
///
/// Da un par de pulsos y se apaga: es para que levantes la vista del móvil,
/// no para quedarse parpadeando.
class DestelloTurno extends StatelessWidget {
  final Animation<double> animacion;

  const DestelloTurno({super.key, required this.animacion});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animacion,
        builder: (context, _) {
          final t = animacion.value;
          if (t <= 0 || t >= 1) return const SizedBox.shrink();

          // Dos pulsos que se van apagando.
          final pulso = (sin(t * pi * 4).abs()) * (1 - t);
          final intensidad = pulso.clamp(0.0, 1.0);

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.95,
                colors: [
                  Colors.transparent,
                  AppColors.acento.withValues(alpha: 0.42 * intensidad),
                ],
                stops: const [0.45, 1.0],
              ),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}
