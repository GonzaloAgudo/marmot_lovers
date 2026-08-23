import 'dart:async';

import 'package:flutter/material.dart';

import '../models/carta.dart';
import '../models/jugador.dart';
import '../models/sala.dart';
import '../theme/app_theme.dart';
import '../widgets/carta_widget.dart';

/// Repaso de la ronda antes de ver el marcador.
///
/// Va pasando jugada a jugada enseñando **la carta** que bajó cada uno y qué
/// provocó, y termina destapando las manos con las que se decidió la ronda.
/// Se puede saltar en cualquier momento.
class ResumenRondaScreen extends StatefulWidget {
  final Sala sala;
  final List<Jugador> jugadores;
  final String miUid;

  /// Ir al marcador.
  final VoidCallback onTerminar;

  final void Function(int valor) onVerCarta;

  /// Cuánto dura cada jugada antes de pasar sola a la siguiente.
  final Duration ritmo;

  const ResumenRondaScreen({
    super.key,
    required this.sala,
    required this.jugadores,
    required this.miUid,
    required this.onTerminar,
    required this.onVerCarta,
    this.ritmo = const Duration(milliseconds: 2200),
  });

  @override
  State<ResumenRondaScreen> createState() => _ResumenRondaScreenState();
}

class _ResumenRondaScreenState extends State<ResumenRondaScreen> {
  /// Jugada que se está enseñando. Cuando llega al total, toca la
  /// revelación final de las manos.
  int _paso = 0;

  Timer? _reloj;
  final ScrollController _tira = ScrollController();

  List<UltimaJugada> get _jugadas => widget.sala.historial;

  bool get _esRevelacion => _paso >= _jugadas.length;

  @override
  void initState() {
    super.initState();
    _programar();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _tira.dispose();
    super.dispose();
  }

  void _programar() {
    _reloj?.cancel();
    if (_esRevelacion) return;
    _reloj = Timer(widget.ritmo, _avanzar);
  }

  void _avanzar() {
    if (!mounted) return;
    if (_esRevelacion) {
      widget.onTerminar();
      return;
    }
    setState(() => _paso++);
    _programar();
    _llevarTiraAlFinal();
  }

  void _llevarTiraAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tira.hasClients) return;
      _tira.animateTo(
        _tira.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  Color _colorDe(String uid) {
    for (final j in widget.jugadores) {
      if (j.uid == uid) return AppColors.asiento(j.orden);
    }
    return AppColors.textoSuave;
  }

  @override
  Widget build(BuildContext context) {
    // Sin jugadas apuntadas (ronda de una sola carta, o partida vieja) no
    // hay nada que repasar.
    if (_jugadas.isEmpty && !_esRevelacion) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => widget.onTerminar());
    }

    return Scaffold(
      body: MesaFondo(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              // Tocar en cualquier sitio adelanta.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _avanzar,
                child: LayoutBuilder(
                  builder: (context, restricciones) {
                    final alto = restricciones.maxHeight;
                    final apretado = alto < 620;
                    final hCabecera = apretado ? 38.0 : 44.0;
                    const hProgreso = 24.0;
                    final hTira = apretado ? 52.0 : 64.0;
                    final hAccion = apretado ? 52.0 : 60.0;
                    final hCentro =
                        alto - hCabecera - hProgreso - hTira - hAccion;

                    return Column(
                      children: [
                        SizedBox(height: hCabecera, child: _cabecera()),
                        SizedBox(height: hProgreso, child: _progreso()),
                        SizedBox(
                          height: hCentro > 80 ? hCentro : 80,
                          child: _esRevelacion
                              ? _revelacionFinal(hCentro)
                              : _jugadaActual(hCentro),
                        ),
                        SizedBox(height: hTira, child: _tiraDeJugadas(hTira)),
                        SizedBox(height: hAccion, child: _barraAccion()),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cabecera() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Etiqueta('como ha ido la ronda'),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: widget.onTerminar,
            child: const Text('SALTAR', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _progreso() {
    final total = _jugadas.length;
    final hechas = _esRevelacion ? total : _paso;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                    begin: 0,
                    end: total == 0 ? 1 : (hechas + 1) / (total + 1)),
                duration: const Duration(milliseconds: 300),
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: AppColors.superficieAlta,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.acento),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _esRevelacion ? 'final' : '${_paso + 1} de $total',
            style: const TextStyle(fontSize: 11, color: AppColors.textoTenue),
          ),
        ],
      ),
    );
  }

  /// La jugada que toca, con su carta en grande.
  Widget _jugadaActual(double alto) {
    if (_jugadas.isEmpty) return const SizedBox.shrink();
    final jugada = _jugadas[_paso.clamp(0, _jugadas.length - 1)];
    final color = _colorDe(jugada.uid);
    final altoCarta = (alto * 0.66).clamp(90.0, 340.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (hijo, animacion) => FadeTransition(
          opacity: animacion,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.82, end: 1).animate(animacion),
            child: hijo,
          ),
        ),
        child: Column(
          key: ValueKey(_paso),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: color),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    jugada.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('juega',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textoSuave)),
              ],
            ),
            const SizedBox(height: 10),
            CartaWidget(
              valor: jugada.carta,
              altura: altoCarta,
              onTap: () => widget.onVerCarta(jugada.carta),
            ),
            const SizedBox(height: 7),
            Text(
              '${jugada.carta}  ${Cartas.nombreCorto(jugada.carta)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.acentoSuave,
              ),
            ),
            if (jugada.resultado.isNotEmpty) ...[
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  jugada.resultado,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, height: 1.3, color: AppColors.textoSuave),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Las manos con las que se decidió la ronda, destapadas.
  Widget _revelacionFinal(double alto) {
    final ganadores = widget.sala.ganadoresRonda;
    final conCarta =
        widget.jugadores.where((j) => j.mano.isNotEmpty).toList();
    final altoCarta = (alto * 0.62).clamp(70.0, 250.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.sala.motivoFinal == 'ultimo_en_pie'
                ? 'Solo queda uno en pie'
                : 'Se agota el mazo y se destapan las manos',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textoSuave),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: conCarta.map((j) {
                  final gano = ganadores.contains(j.nombre);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (gano)
                          const Icon(Icons.emoji_events,
                              size: 18, color: AppColors.acento)
                        else
                          const SizedBox(height: 18),
                        const SizedBox(height: 4),
                        CartaWidget(
                          valor: j.mano.first,
                          altura: altoCarta,
                          seleccionada: gano,
                          onTap: () => widget.onVerCarta(j.mano.first),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: altoCarta * CartaWidget.ratio + 12,
                          child: Text(
                            j.nombre,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight:
                                  gano ? FontWeight.w900 : FontWeight.w600,
                              color: gano
                                  ? AppColors.acento
                                  : AppColors.textoSuave,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Todas las cartas que han salido, en orden, para verlo de un vistazo.
  Widget _tiraDeJugadas(double alto) {
    final hasta = _esRevelacion ? _jugadas.length : _paso + 1;
    final altoMini = (alto - 12).clamp(28.0, 52.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListView.builder(
        controller: _tira,
        scrollDirection: Axis.horizontal,
        itemCount: hasta.clamp(0, _jugadas.length),
        itemBuilder: (context, i) {
          final jugada = _jugadas[i];
          final actual = !_esRevelacion && i == _paso;
          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: actual
                      ? AppColors.acento
                      : _colorDe(jugada.uid).withValues(alpha: 0.55),
                  width: actual ? 2 : 1.4,
                ),
              ),
              child: CartaWidget(
                valor: jugada.carta,
                altura: altoMini,
                compacta: true,
                onTap: () => widget.onVerCarta(jugada.carta),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _barraAccion() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: SizedBox(
        width: double.infinity,
        child: _esRevelacion
            ? ElevatedButton.icon(
                icon: const Icon(Icons.emoji_events, size: 19),
                label: const Text('VER QUIEN GANA'),
                onPressed: widget.onTerminar,
              )
            : OutlinedButton.icon(
                icon: const Icon(Icons.skip_next, size: 18),
                label: const Text('Siguiente jugada'),
                onPressed: _avanzar,
              ),
      ),
    );
  }
}
