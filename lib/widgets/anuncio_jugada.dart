import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/carta.dart';
import '../models/sala.dart';
import '../theme/app_theme.dart';
import 'carta_widget.dart';

/// Anuncio temporal de una jugada: cubre la mesa un momento para que todos
/// vean qué ha pasado.
///
/// Es el overlay que aporto el PR de ricardo-ha. Convive con
/// [AnimacionJugada] (el sello dentro del panel de la mesa) y con las
/// reacciones de los asientos: se llamaba igual, y por eso se renombro.
///
/// Enseña primero la carta jugada (volteándose) y después, de una en una,
/// las cartas que el efecto ha revelado en público. Avanza sola y se puede
/// saltar tocando en cualquier sitio.
class AnuncioJugada extends StatefulWidget {
  final UltimaJugada jugada;

  /// Color del asiento de cada jugador, para el punto de su nombre.
  final Color Function(String uid) colorDe;

  /// Se llama cuando la secuencia termina (sola o por un toque).
  final VoidCallback onTerminar;

  /// Cuánto se queda cada carta en pantalla antes de pasar a la siguiente.
  final Duration ritmo;

  const AnuncioJugada({
    super.key,
    required this.jugada,
    required this.colorDe,
    required this.onTerminar,
    this.ritmo = const Duration(milliseconds: 1900),
  });

  @override
  State<AnuncioJugada> createState() => _AnuncioJugadaState();
}

class _AnuncioJugadaState extends State<AnuncioJugada> {
  /// Paso de la secuencia: 0 = la carta jugada; el resto, cada revelada.
  int _paso = 0;
  Timer? _reloj;

  int get _totalPasos => 1 + widget.jugada.reveladas.length;

  @override
  void initState() {
    super.initState();
    _programar();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  void _programar() {
    _reloj?.cancel();
    _reloj = Timer(widget.ritmo, () {
      if (!mounted) return;
      if (_paso + 1 >= _totalPasos) {
        widget.onTerminar();
        return;
      }
      setState(() => _paso++);
      _programar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTerminar,
        child: Container(
          color: Colors.black.withValues(alpha: 0.66),
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, restricciones) {
              final altoCarta =
                  (restricciones.maxHeight * 0.36).clamp(110.0, 240.0);

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 340),
                      switchInCurve: Curves.easeOutBack,
                      transitionBuilder: (hijo, animacion) => FadeTransition(
                        opacity: animacion,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.86, end: 1)
                              .animate(animacion),
                          child: hijo,
                        ),
                      ),
                      child: _paso == 0
                          ? _cartaJugada(altoCarta)
                          : _cartaRevelada(
                              widget.jugada.reveladas[_paso - 1], altoCarta),
                    ),
                  ),
                  if (widget.jugada.resultado.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Text(
                        widget.jugada.resultado,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.texto,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text(
                    'toca para saltar',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textoTenue,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _cabecera(String nombre, String verbo, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '$nombre $verbo',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _rotuloCarta(int valor) => Text(
        '$valor  ${Cartas.nombreCorto(valor)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: AppColors.acentoSuave,
        ),
      );

  Widget _cartaJugada(double altoCarta) {
    final jugada = widget.jugada;
    return Column(
      key: const ValueKey('jugada'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _cabecera(jugada.nombre, 'juega', widget.colorDe(jugada.uid)),
        const SizedBox(height: 14),
        _CartaVolteada(valor: jugada.carta, altura: altoCarta),
        const SizedBox(height: 10),
        _rotuloCarta(jugada.carta),
      ],
    );
  }

  Widget _cartaRevelada(CartaRevelada revelada, double altoCarta) {
    final forzada = revelada.motivo == 'forzada';
    return Column(
      key: ValueKey('revelada-$_paso'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Etiqueta(
          forzada ? 'baja su carta sin efecto' : 'queda eliminado',
          color: forzada ? AppColors.acento : AppColors.peligro,
        ),
        const SizedBox(height: 10),
        _cabecera(
          revelada.nombre,
          forzada ? 'revela' : 'revela su carta',
          widget.colorDe(revelada.uid),
        ),
        const SizedBox(height: 14),
        _CartaVolteada(valor: revelada.carta, altura: altoCarta),
        const SizedBox(height: 10),
        _rotuloCarta(revelada.carta),
      ],
    );
  }
}

/// Carta que entra volteándose: enseña el dorso y acaba mostrando el valor.
class _CartaVolteada extends StatefulWidget {
  final int valor;
  final double altura;

  const _CartaVolteada({required this.valor, required this.altura});

  @override
  State<_CartaVolteada> createState() => _CartaVolteadaState();
}

class _CartaVolteadaState extends State<_CartaVolteada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _giro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  )..forward();

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _giro,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_giro.value);
        // Primera mitad: el dorso gira hasta quedarse de canto; segunda
        // mitad: el valor termina de girar hasta quedar plano.
        final mostrandoDorso = t < 0.5;
        final angulo = (mostrandoDorso ? t : 1 - t) * math.pi;

        return Transform.scale(
          scale: 0.94 + 0.06 * t,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0016)
              ..rotateY(angulo),
            child: CartaWidget(
              valor: mostrandoDorso ? null : widget.valor,
              altura: widget.altura,
            ),
          ),
        );
      },
    );
  }
}
