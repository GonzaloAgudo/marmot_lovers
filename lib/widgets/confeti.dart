import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lluvia de confeti para celebrar la victoria.
///
/// Está pintado a mano con un [CustomPainter] para no meter una dependencia
/// solo por esto. Se para solo al terminar, así no gasta batería de fondo.
class Confeti extends StatefulWidget {
  final int cantidad;
  final Duration duracion;

  const Confeti({
    super.key,
    this.cantidad = 60,
    this.duracion = const Duration(seconds: 5),
  });

  @override
  State<Confeti> createState() => _ConfetiState();
}

class _ConfetiState extends State<Confeti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: widget.duracion,
  )..forward();

  late final List<_Trozo> _trozos = _crear();

  List<_Trozo> _crear() {
    final rnd = Random(7);
    const colores = [
      AppColors.acento,
      AppColors.acentoSuave,
      AppColors.escudo,
      AppColors.secreto,
      Color(0xFF67C27C),
      Color(0xFFE8833A),
    ];
    return List.generate(widget.cantidad, (i) {
      return _Trozo(
        x: rnd.nextDouble(),
        retraso: rnd.nextDouble() * 0.35,
        duracion: 0.55 + rnd.nextDouble() * 0.45,
        deriva: (rnd.nextDouble() - 0.5) * 0.35,
        giro: (rnd.nextDouble() - 0.5) * 12,
        tamano: 5 + rnd.nextDouble() * 7,
        color: colores[i % colores.length],
        redondo: rnd.nextBool(),
      );
    });
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _control,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _PintorConfeti(_trozos, _control.value),
        ),
      ),
    );
  }
}

class _Trozo {
  final double x;
  final double retraso;
  final double duracion;
  final double deriva;
  final double giro;
  final double tamano;
  final Color color;
  final bool redondo;

  const _Trozo({
    required this.x,
    required this.retraso,
    required this.duracion,
    required this.deriva,
    required this.giro,
    required this.tamano,
    required this.color,
    required this.redondo,
  });
}

class _PintorConfeti extends CustomPainter {
  final List<_Trozo> trozos;
  final double t;

  _PintorConfeti(this.trozos, this.t);

  @override
  void paint(Canvas lienzo, Size medida) {
    final pincel = Paint();

    for (final trozo in trozos) {
      final avance = (t - trozo.retraso) / trozo.duracion;
      if (avance <= 0 || avance >= 1) continue;

      final x = (trozo.x + trozo.deriva * avance) * medida.width;
      // Cae acelerando, como algo que pesa.
      final y = (avance * avance * 0.85 + avance * 0.15) * medida.height;

      // Se desvanece al final para que no desaparezca de golpe.
      pincel.color = trozo.color
          .withValues(alpha: avance > 0.75 ? (1 - avance) * 4 : 1.0);

      lienzo.save();
      lienzo.translate(x, y);
      lienzo.rotate(trozo.giro * avance);
      if (trozo.redondo) {
        lienzo.drawCircle(Offset.zero, trozo.tamano / 2, pincel);
      } else {
        lienzo.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: trozo.tamano,
            height: trozo.tamano * 0.55,
          ),
          pincel,
        );
      }
      lienzo.restore();
    }
  }

  @override
  bool shouldRepaint(_PintorConfeti anterior) => anterior.t != t;
}
