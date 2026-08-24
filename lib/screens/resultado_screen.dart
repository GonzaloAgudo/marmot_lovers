import 'package:flutter/material.dart';

import '../models/carta.dart';
import '../models/jugador.dart';
import '../models/sala.dart';
import '../theme/app_theme.dart';
import '../widgets/carta_widget.dart';
import '../widgets/confeti.dart';
import '../widgets/medalla_puesto.dart';

/// Pantalla de fin de ronda / fin de partida.
///
/// Entra por partes (trofeo, ganador, cómo ha ganado, y luego cada jugador)
/// para que se vea quién gana en vez de saltar de golpe al marcador.
class PantallaResultado extends StatefulWidget {
  final Sala sala;
  final List<Jugador> jugadores;
  final String miUid;
  final bool procesando;
  final VoidCallback onContinuar;
  final VoidCallback onVolverAlLobby;
  final VoidCallback onHistorial;
  final void Function(int valor) onVerCarta;

  const PantallaResultado({
    super.key,
    required this.sala,
    required this.jugadores,
    required this.miUid,
    required this.procesando,
    required this.onContinuar,
    required this.onVolverAlLobby,
    required this.onHistorial,
    required this.onVerCarta,
  });

  @override
  State<PantallaResultado> createState() => _PantallaResultadoState();
}

class _PantallaResultadoState extends State<PantallaResultado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..forward();

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  /// Animación recortada a un tramo, para que las cosas entren en orden.
  Animation<double> _tramo(double desde, double hasta) => CurvedAnimation(
        parent: _entrada,
        curve: Interval(desde, hasta, curve: Curves.easeOutCubic),
      );

  Widget _apareciendo(Animation<double> a, Widget hijo, {double desde = 18}) {
    return AnimatedBuilder(
      animation: a,
      builder: (context, _) => Opacity(
        opacity: a.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, desde * (1 - a.value)),
          child: hijo,
        ),
      ),
    );
  }

  bool get _finPartida => widget.sala.estado == EstadoSala.finPartida;

  List<String> get _ganadores =>
      _finPartida ? widget.sala.ganadoresPartida : widget.sala.ganadoresRonda;

  /// Explica en una frase por qué ha ganado quien ha ganado.
  String get _comoHaGanado {
    final sala = widget.sala;
    final carta = sala.cartaGanadora;
    final empate = sala.ganadoresRonda.length > 1;

    if (sala.motivoFinal == 'ultimo_en_pie') {
      return 'Ultimo en pie: todos los demas quedaron eliminados.';
    }
    if (sala.motivoFinal == 'mazo_agotado') {
      if (carta == 0) {
        return 'Se agoto el mazo y El Capo de la Colonia (0) le robo la '
            'victoria al Rey del Trono de Peluche (10).';
      }
      final conQue = carta == null
          ? 'la carta mas alta'
          : 'un $carta ${Cartas.nombreCorto(carta)}';
      if (empate) {
        return 'Se agoto el mazo. Empate a ${carta ?? "?"}: desempata la '
            'carta mas alta ya jugada.';
      }
      return 'Se agoto el mazo y se quedo con $conQue, la carta mas alta.';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final sala = widget.sala;
    final soyHost = sala.hostUid == widget.miUid;
    final ganadores = _ganadores;

    final ordenados = [...widget.jugadores]..sort((a, b) {
        final porFichas = b.fichasVictoria.compareTo(a.fichasVictoria);
        if (porFichas != 0) return porFichas;
        // A igualdad de fichas, delante quien acaba de ganar la ronda.
        final ga = ganadores.contains(a.nombre) ? 0 : 1;
        final gb = ganadores.contains(b.nombre) ? 0 : 1;
        return ga - gb;
      });

    // Puesto de cada uno: con las mismas fichas se comparte puesto, y el
    // siguiente salta (1, 2, 2, 4...), como en cualquier clasificacion.
    final puestos = <String, int>{};
    for (var i = 0; i < ordenados.length; i++) {
      final j = ordenados[i];
      if (i > 0 && ordenados[i - 1].fichasVictoria == j.fichasVictoria) {
        puestos[j.uid] = puestos[ordenados[i - 1].uid]!;
      } else {
        puestos[j.uid] = i + 1;
      }
    }

    return Scaffold(
      body: MesaFondo(
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
                          children: [
                            _trofeo(),
                            const SizedBox(height: 12),
                            _apareciendo(
                              _tramo(0.20, 0.45),
                              Column(
                                children: [
                                  Text(
                                    _finPartida
                                        ? 'FIN DE LA PARTIDA'
                                        : 'FIN DE LA RONDA',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 3,
                                      color: AppColors.textoSuave,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    ganadores.isEmpty
                                        ? 'Nadie'
                                        : ganadores.join(' y '),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: _finPartida ? 32 : 27,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.acento,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _finPartida
                                        ? 'gana la partida con '
                                            '${sala.fichasParaGanar} fichas'
                                        : 'se lleva la ficha de esta ronda',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textoSuave),
                                  ),
                                ],
                              ),
                            ),
                            if (_comoHaGanado.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _apareciendo(
                                _tramo(0.40, 0.65),
                                Panel(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 11),
                                  borde:
                                      AppColors.acento.withValues(alpha: 0.35),
                                  child: Row(
                                    children: [
                                      if (sala.cartaGanadora != null &&
                                          sala.motivoFinal ==
                                              'mazo_agotado') ...[
                                        CartaWidget(
                                          valor: sala.cartaGanadora,
                                          altura: 62,
                                          onTap: () => widget
                                              .onVerCarta(sala.cartaGanadora!),
                                        ),
                                        const SizedBox(width: 12),
                                      ] else ...[
                                        const Icon(Icons.emoji_events,
                                            size: 22, color: AppColors.acento),
                                        const SizedBox(width: 12),
                                      ],
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Etiqueta('como ha ganado'),
                                            const SizedBox(height: 5),
                                            Text(
                                              _comoHaGanado,
                                              style: const TextStyle(
                                                  fontSize: 12.5,
                                                  height: 1.35),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            // Cada jugador entra un poco después del anterior.
                            ...List.generate(ordenados.length, (i) {
                              final desde =
                                  (0.55 + i * 0.09).clamp(0.0, 0.94);
                              return _apareciendo(
                                _tramo(desde, (desde + 0.14).clamp(0.0, 1.0)),
                                _filaResultado(ordenados[i], ganadores,
                                    puestos[ordenados[i].uid] ?? i + 1),
                              );
                            }),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton.icon(
                                icon: const Icon(Icons.receipt_long, size: 17),
                                label: const Text('Ver como ha ido la ronda'),
                                onPressed: widget.onHistorial,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _apareciendo(
                        _tramo(0.75, 1.0),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                          child: soyHost
                              ? Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: Icon(
                                            _finPartida
                                                ? Icons.refresh
                                                : Icons.play_arrow,
                                            size: 19),
                                        label: Text(_finPartida
                                            ? 'NUEVA PARTIDA'
                                            : 'SIGUIENTE RONDA'),
                                        onPressed: widget.procesando
                                            ? null
                                            : widget.onContinuar,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: widget.procesando
                                          ? null
                                          : widget.onVolverAlLobby,
                                      child: const Text('Volver al lobby'),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Esperando a que el anfitrion continue...',
                                  style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textoSuave),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // El confeti solo cuando se gana la partida entera.
            if (_finPartida) const Positioned.fill(child: Confeti()),
          ],
        ),
      ),
    );
  }

  /// Trofeo que entra creciendo, con un halo detrás.
  Widget _trofeo() {
    final a = _tramo(0.0, 0.35);
    return AnimatedBuilder(
      animation: a,
      builder: (context, _) {
        final v = Curves.easeOutBack.transform(a.value.clamp(0.0, 1.0));
        return Center(
          child: Transform.scale(
            scale: 0.4 + 0.6 * v,
            child: Opacity(
              opacity: a.value.clamp(0.0, 1.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.acento.withValues(alpha: 0.10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.acento.withValues(alpha: 0.28 * v),
                      blurRadius: 34 * v,
                      spreadRadius: 4 * v,
                    ),
                  ],
                ),
                child: Icon(
                  _finPartida ? Icons.workspace_premium : Icons.emoji_events,
                  size: _finPartida ? 62 : 52,
                  color: AppColors.acento,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _filaResultado(Jugador j, List<String> ganadores, int puesto) {
    final gano = ganadores.contains(j.nombre);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: gano
            ? AppColors.acento.withValues(alpha: 0.12)
            : AppColors.superficie.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: gano ? AppColors.acento : AppColors.borde,
          width: gano ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          if (j.mano.isNotEmpty)
            CartaWidget(
              valor: j.mano.first,
              altura: 66,
              onTap: () => widget.onVerCarta(j.mano.first),
            )
          else
            SizedBox(
              width: 66 * CartaWidget.ratio,
              height: 66,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.borde),
                ),
                child: const Center(
                  child: Icon(Icons.block, color: AppColors.peligro, size: 20),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.asiento(j.orden),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        j.nombre,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  j.mano.isNotEmpty
                      ? 'Se queda con ${j.mano.first} '
                          '${Cartas.nombreCorto(j.mano.first)}'
                      : 'Eliminado durante la ronda',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textoSuave),
                ),
                const SizedBox(height: 6),
                FichasPips(
                  ganadas: j.fichasVictoria,
                  total: widget.sala.fichasParaGanar,
                ),
              ],
            ),
          ),
          MedallaPuesto(puesto: puesto, altura: gano ? 62 : 50),
        ],
      ),
    );
  }
}
