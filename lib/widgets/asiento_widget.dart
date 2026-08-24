import 'dart:math';

import 'package:flutter/material.dart';

import '../models/jugador.dart';
import '../theme/app_theme.dart';
import 'animacion_jugada.dart';
import 'carta_widget.dart';

/// El "sitio en la mesa" de un rival: avatar, estado, fichas y lo que ha jugado.
class AsientoWidget extends StatefulWidget {
  final Jugador jugador;
  final bool esSuTurno;
  final bool seleccionable;
  final int fichasParaGanar;
  final double altura;
  final VoidCallback? onTap;

  /// Se llama al tocar una de las cartas que el rival ha jugado, para
  /// poder verla en grande.
  final void Function(int valor)? onVerCarta;

  /// Lo que le acaba de pasar a este jugador, para que su sitio reaccione
  /// (una sacudida al caer, un destello de escudo...).
  final ReaccionAsiento reaccion;

  const AsientoWidget({
    super.key,
    required this.jugador,
    required this.esSuTurno,
    required this.seleccionable,
    required this.fichasParaGanar,
    required this.altura,
    this.onTap,
    this.onVerCarta,
    this.reaccion = ReaccionAsiento.ninguna,
  });

  @override
  State<AsientoWidget> createState() => _AsientoWidgetState();
}

// Dos animaciones: el pulso de "apuntame" y la reaccion al recibir algo.
class _AsientoWidgetState extends State<AsientoWidget>
    with TickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// Sacudida / destello cuando a este jugador le pasa algo.
  late final AnimationController _reaccion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    if (widget.seleccionable) _pulso.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AsientoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seleccionable && !_pulso.isAnimating) {
      _pulso.repeat(reverse: true);
    } else if (!widget.seleccionable && _pulso.isAnimating) {
      _pulso.stop();
      _pulso.value = 0;
    }
    if (widget.reaccion != oldWidget.reaccion &&
        widget.reaccion != ReaccionAsiento.ninguna) {
      _reaccion.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    _reaccion.dispose();
    super.dispose();
  }

  /// Envuelve el asiento con la reaccion: temblor y un halo de color.
  Widget _conReaccion(Widget hijo) {
    if (widget.reaccion == ReaccionAsiento.ninguna) return hijo;

    final color = switch (widget.reaccion) {
      ReaccionAsiento.golpe => AppColors.peligro,
      ReaccionAsiento.escudo => AppColors.escudo,
      ReaccionAsiento.cambio => AppColors.secreto,
      ReaccionAsiento.ninguna => AppColors.borde,
    };

    return AnimatedBuilder(
      animation: _reaccion,
      builder: (context, _) {
        final t = _reaccion.value;
        if (t == 0 || t == 1) return hijo;

        // Temblor que se va apagando (solo al ser golpeado).
        final temblor = widget.reaccion == ReaccionAsiento.golpe
            ? sin(t * pi * 6) * 6 * (1 - t)
            : 0.0;

        return Transform.translate(
          offset: Offset(temblor, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.55 * (1 - t)),
                  blurRadius: 20 * (1 - t) + 4,
                  spreadRadius: 3 * (1 - t),
                ),
              ],
            ),
            child: hijo,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.jugador;
    final color = AppColors.asiento(j.orden);

    final Color colorBorde;
    if (widget.seleccionable) {
      colorBorde = AppColors.acento;
    } else if (!j.vivo) {
      colorBorde = AppColors.peligro.withValues(alpha: 0.4);
    } else if (j.protegido) {
      colorBorde = AppColors.escudo;
    } else if (widget.esSuTurno) {
      colorBorde = AppColors.acento;
    } else {
      colorBorde = AppColors.borde;
    }

    return AnimatedBuilder(
      animation: _pulso,
      builder: (context, child) {
        final brillo = widget.seleccionable ? _pulso.value : 0.0;
        return Transform.scale(
          scale: 1 + brillo * 0.03,
          child: _conReaccion(
            Container(
              width: 118,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              decoration: BoxDecoration(
                color: j.vivo
                    ? AppColors.superficie.withValues(alpha: 0.8)
                    : AppColors.fondo.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorBorde,
                  width: widget.seleccionable || widget.esSuTurno || j.protegido
                      ? 2
                      : 1,
                ),
                boxShadow: widget.seleccionable
                    ? [
                        BoxShadow(
                          color: AppColors.acento.withValues(
                            alpha: 0.25 + brillo * 0.35,
                          ),
                          blurRadius: 14 + brillo * 8,
                        ),
                      ]
                    : null,
              ),
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.seleccionable ? widget.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: LayoutBuilder(
          builder: (context, r) {
            // En huecos bajos se recorta lo accesorio antes que desbordar.
            final alto = r.maxHeight;
            final hayPips = alto >= 84;
            final hayChip = alto >= 70;
            final avatar = alto < 76 ? 24.0 : 30.0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _avatar(j, color, avatar),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            j.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: j.vivo
                                  ? AppColors.texto
                                  : AppColors.textoTenue,
                              decoration: j.vivo
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                          if (hayPips) ...[
                            const SizedBox(height: 3),
                            FichasPips(
                              ganadas: j.fichasVictoria,
                              total: widget.fichasParaGanar,
                              tamano: 7,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (hayChip) ...[const SizedBox(height: 4), _estado(j)],
                const SizedBox(height: 4),
                // Las cartas jugadas ocupan lo que sobre: así el asiento encaja
                // en el alto que le den, sin desbordar ni dejar hueco muerto.
                Expanded(
                  child: j.cartasJugadas.isEmpty
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: Etiqueta('sin jugadas'),
                        )
                      : LayoutBuilder(
                          builder: (context, restricciones) => ListView(
                            scrollDirection: Axis.horizontal,
                            children: j.cartasJugadas
                                .map(
                                  (c) => CartaMini(
                                    valor: c,
                                    altura: restricciones.maxHeight,
                                    onTap: widget.onVerCarta == null
                                        ? null
                                        : () => widget.onVerCarta!(c),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _avatar(Jugador j, Color color, double lado) {
    final inicial = j.nombre.isEmpty ? '?' : j.nombre[0].toUpperCase();
    return Container(
      width: lado,
      height: lado,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: j.vivo ? color : AppColors.superficieAlta,
        border: Border.all(
          color: j.protegido ? AppColors.escudo : Colors.white24,
          width: j.protegido ? 2 : 1,
        ),
      ),
      child: Center(
        child: j.vivo
            ? Text(
                inicial,
                style: TextStyle(
                  fontSize: lado * 0.47,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              )
            : Icon(Icons.close, size: lado * 0.53, color: AppColors.peligro),
      ),
    );
  }

  Widget _estado(Jugador j) {
    if (widget.seleccionable) {
      return _chip('APUNTAR', AppColors.acento, Icons.gps_fixed);
    }
    if (!j.vivo) {
      return _chip('ELIMINADO', AppColors.peligro, Icons.block);
    }
    if (j.protegido) {
      return _chip('PROTEGIDO', AppColors.escudo, Icons.shield);
    }
    if (widget.esSuTurno) {
      return _chip('SU TURNO', AppColors.acento, Icons.play_arrow);
    }
    return _chip('en juego', AppColors.textoTenue, Icons.circle, tenue: true);
  }

  Widget _chip(
    String texto,
    Color color,
    IconData icono, {
    bool tenue = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tenue ? Colors.transparent : color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tenue ? AppColors.borde : color.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 9, color: color),
          const SizedBox(width: 3),
          // Flexible + ellipsis: el chip nunca desborda el asiento, ni con
          // el texto mas largo ni con la fuente del sistema agrandada.
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
