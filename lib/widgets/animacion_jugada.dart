import 'package:flutter/material.dart';

import '../models/carta.dart';
import '../models/sala.dart';
import '../theme/app_theme.dart';
import 'carta_widget.dart';

/// Cómo se dibuja cada efecto: icono, color y frase corta.
class _Pinta {
  final IconData icono;
  final Color color;
  final String Function(UltimaJugada) texto;
  const _Pinta(this.icono, this.color, this.texto);
}

final Map<String, _Pinta> _pintas = {
  Efecto.eliminado: _Pinta(
    Icons.dangerous,
    AppColors.peligro,
    (j) => '${j.objetivoNombre ?? "Alguien"} fuera',
  ),
  Efecto.autoEliminado: _Pinta(
    Icons.dangerous,
    AppColors.peligro,
    (j) => '${j.nombre} se elimina',
  ),
  Efecto.protegido: _Pinta(
    Icons.shield,
    AppColors.escudo,
    (j) => '${j.nombre} se protege',
  ),
  Efecto.intercambio: _Pinta(
    Icons.swap_horiz,
    AppColors.secreto,
    (j) => 'Cartas cambiadas',
  ),
  Efecto.fallo: _Pinta(
    Icons.block,
    AppColors.textoSuave,
    (j) => 'Falla',
  ),
  Efecto.mirada: _Pinta(
    Icons.visibility,
    AppColors.secreto,
    (j) => 'Mira en secreto',
  ),
  Efecto.rebarajado: _Pinta(
    Icons.shuffle,
    AppColors.acentoSuave,
    (j) => 'Se reparte de nuevo',
  ),
  Efecto.forzado: _Pinta(
    Icons.pan_tool,
    AppColors.acento,
    (j) => '${j.objetivoNombre ?? "Alguien"} baja su carta',
  ),
};

/// Anima la jugada que acaba de pasar en el centro de la mesa.
///
/// La carta entra girando, y si la jugada le hace algo a alguien sale
/// después el efecto (calavera, escudo, intercambio...) hacia ese jugador.
/// La idea es que se entienda de un vistazo, sin leer.
class AnimacionJugada extends StatelessWidget {
  final UltimaJugada jugada;
  final Animation<double> animacion;
  final Color colorJugador;
  final double altoCarta;
  final VoidCallback? onVerCarta;

  /// Cuantas lineas de explicacion caben al lado de la carta. 0 = ninguna.
  final int lineasTexto;

  const AnimacionJugada({
    super.key,
    required this.jugada,
    required this.animacion,
    required this.colorJugador,
    required this.altoCarta,
    this.onVerCarta,
    this.lineasTexto = 2,
  });

  @override
  Widget build(BuildContext context) {
    final pinta = _pintas[jugada.efecto];

    return AnimatedBuilder(
      animation: animacion,
      builder: (context, _) {
        final t = animacion.value;

        // La carta entra en el primer tercio; el efecto sale después.
        final entrada = Curves.easeOutBack.transform((t / 0.35).clamp(0.0, 1.0));
        final salida = ((t - 0.4) / 0.6).clamp(0.0, 1.0);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Transform.translate(
              offset: Offset(-40 * (1 - entrada), 0),
              child: Transform.rotate(
                angle: -0.35 * (1 - entrada),
                child: Opacity(
                  opacity: entrada.clamp(0.0, 1.0),
                  child: CartaWidget(
                    valor: jugada.carta,
                    altura: altoCarta,
                    onTap: onVerCarta,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _quien(entrada),
                  const SizedBox(height: 4),
                  Text(
                    '${jugada.carta}  ${Cartas.nombreCorto(jugada.carta)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.acentoSuave,
                    ),
                  ),
                  if (pinta != null) ...[
                    const SizedBox(height: 8),
                    _sello(pinta, salida),
                  ],
                  // El sello se ve de un vistazo, pero el texto tambien se
                  // puede leer: no todo el mundo quiere adivinar iconos.
                  if (jugada.resultado.isNotEmpty && lineasTexto > 0) ...[
                    const SizedBox(height: 6),
                    Opacity(
                      opacity: salida.clamp(0.0, 1.0),
                      child: Text(
                        jugada.resultado,
                        maxLines: lineasTexto,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.28,
                          color: AppColors.textoSuave,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _quien(double entrada) {
    return Opacity(
      opacity: entrada.clamp(0.0, 1.0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: colorJugador),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              jugada.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  /// El efecto: entra desde la carta, da un golpe y se queda.
  Widget _sello(_Pinta pinta, double t) {
    if (t <= 0) return const SizedBox(height: 26);

    // Rebote: se pasa de tamaño y vuelve.
    final escala = t < 0.35
        ? 0.4 + (t / 0.35) * 0.85
        : 1.25 - ((t - 0.35) / 0.65) * 0.25;

    return Opacity(
      opacity: (t * 2.5).clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(-26 * (1 - t.clamp(0.0, 1.0)), 0),
        child: Transform.scale(
          scale: escala.clamp(0.4, 1.3),
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: pinta.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: pinta.color.withValues(alpha: 0.7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(pinta.icono, size: 14, color: pinta.color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    pinta.texto(jugada),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: pinta.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El sello de un efecto, quieto. Para sitios donde no hace falta animarlo,
/// como el repaso de la ronda.
class SelloEfecto extends StatelessWidget {
  final UltimaJugada jugada;
  final double escala;

  const SelloEfecto({super.key, required this.jugada, this.escala = 1});

  /// `true` si esta jugada tiene algo que enseñar.
  static bool tieneSello(UltimaJugada jugada) =>
      _pintas.containsKey(jugada.efecto);

  @override
  Widget build(BuildContext context) {
    final pinta = _pintas[jugada.efecto];
    if (pinta == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: 11 * escala, vertical: 6 * escala),
      decoration: BoxDecoration(
        color: pinta.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pinta.color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pinta.icono, size: 15 * escala, color: pinta.color),
          SizedBox(width: 6 * escala),
          Flexible(
            child: Text(
              pinta.texto(jugada),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12 * escala,
                fontWeight: FontWeight.w800,
                color: pinta.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reacción del asiento del jugador al que le acaba de pasar algo.
enum ReaccionAsiento { ninguna, golpe, escudo, cambio }

extension ReaccionDeEfecto on String {
  ReaccionAsiento get reaccion => switch (this) {
        Efecto.eliminado || Efecto.autoEliminado => ReaccionAsiento.golpe,
        Efecto.protegido => ReaccionAsiento.escudo,
        Efecto.intercambio => ReaccionAsiento.cambio,
        _ => ReaccionAsiento.ninguna,
      };
}
