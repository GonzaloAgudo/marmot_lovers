import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/carta.dart';
import '../models/jugador.dart';
import '../models/sala.dart';
import '../repositories/game_repository.dart';
import '../repositories/preferencias.dart';
import '../repositories/voz_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/asiento_widget.dart';
import '../widgets/animacion_jugada.dart';
import '../widgets/aviso_turno.dart';
import '../widgets/carta_widget.dart';
import 'resultado_screen.dart';
import 'resumen_ronda_screen.dart';

class GameScreen extends StatefulWidget {
  final String idSala;
  final String miUid;

  /// Solo se pasa en los tests para poder dibujar la mesa sin Firebase.
  final GameRepository? repositorio;

  const GameScreen({
    super.key,
    required this.idSala,
    required this.miUid,
    this.repositorio,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

// Dos animaciones a la vez (el destello del turno y la jugada), asi que
// hace falta el mixin que admite varias.
class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final GameRepository _repo = widget.repositorio ?? GameRepository();

  /// Destello de los bordes cuando te toca. Se crea en [initState] y no con
  /// un inicializador `late`: si no, al cerrar la pantalla sin haberlo usado
  /// se intentaria crear durante el dispose.
  late final AnimationController _destello;

  /// De quién era el turno la última vez que se dibujó, para saber cuándo
  /// acaba de pasar a ser el tuyo.
  String? _turnoAnterior;

  /// Animación de la jugada que acaba de ocurrir en la mesa.
  late final AnimationController _animJugada;

  /// Identifica la jugada ya animada, para no repetir la animación en cada
  /// reconstrucción.
  String? _jugadaAnimada;

  // --- Micrófono al caer eliminado ---
  final VozRepository _voz = VozRepository();
  StreamSubscription<List<Reaccion>>? _escuchaVoz;

  /// Reacciones ya sonadas, para no repetirlas en cada actualización.
  final Set<String> _reaccionesOidas = {};

  bool _microActivado = true;
  bool _grabando = false;

  /// Si yo seguía vivo la última vez, para detectar el momento de caer.
  bool _seguiaVivo = true;

  bool _avisoActivado = true;

  /// Si ya se ha visto (o saltado) el repaso de esta ronda. Se pone a false
  /// en cuanto se vuelve a jugar, para que salga en cada ronda.
  bool _repasoHecho = false;

  /// Los streams se crean UNA vez. Si se llamara al repositorio dentro de
  /// build(), cada cambio de la sala abriria una suscripcion nueva a
  /// Firestore y la lista de jugadores volveria a "cargando" un instante.
  late final Stream<Sala> _salaStream;
  late final Stream<List<Jugador>> _jugadoresStream;

  @override
  void initState() {
    super.initState();
    _salaStream = _repo.streamSala(widget.idSala);
    _jugadoresStream = _repo.streamJugadores(widget.idSala);
    _destello = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animJugada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      value: 1,
    );
    Preferencias.avisoTurno().then((activo) {
      if (mounted) setState(() => _avisoActivado = activo);
    });
    Preferencias.microAlCaer().then((activo) {
      if (mounted) setState(() => _microActivado = activo);
    });

    // Las reacciones de voz de los demas suenan segun llegan.
    _escuchaVoz = _voz.escuchar(widget.idSala).listen((reacciones) {
      for (final reaccion in reacciones) {
        if (_reaccionesOidas.contains(reaccion.id)) continue;
        _reaccionesOidas.add(reaccion.id);
        // La tuya no te la reproducimos: ya te has oido.
        if (reaccion.uid == widget.miUid) continue;
        _voz.reproducir(reaccion);
      }
    });
  }

  @override
  void dispose() {
    _destello.dispose();
    _animJugada.dispose();
    _escuchaVoz?.cancel();
    _voz.soltar();
    super.dispose();
  }

  /// Cuando caes eliminado se abre tu micro unos segundos y la sala oye lo
  /// que sueltas. Solo graba el movil del que cae.
  void _vigilarEliminacion(Jugador yo) {
    final acaboDeCaer = _seguiaVivo && !yo.vivo;
    _seguiaVivo = yo.vivo;
    if (!acaboDeCaer || !_microActivado || _grabando) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _grabando = true);
      await _voz.grabarYEnviar(
        idSala: widget.idSala,
        uid: widget.miUid,
        nombre: yo.nombre,
      );
      if (mounted) setState(() => _grabando = false);
    });
  }

  Future<void> _cambiarMicro() async {
    final nuevo = !_microActivado;
    setState(() => _microActivado = nuevo);
    await Preferencias.guardarMicroAlCaer(nuevo);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nuevo
              ? 'Al caer eliminado se abrira tu micro 5 segundos'
              : 'Tu micro no se abrira al caer',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Lanza la animación cuando alguien acaba de jugar algo nuevo.
  void _vigilarJugada(Sala sala) {
    final jugada = sala.ultimaJugada;
    if (jugada == null) return;
    final clave = '${jugada.uid}-${jugada.carta}-${sala.registro.length}';
    if (clave == _jugadaAnimada) return;
    _jugadaAnimada = clave;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animJugada.forward(from: 0);
    });
  }

  /// Vibra y da un destello cuando el turno pasa a ser tuyo.
  void _vigilarTurno(Sala sala, Jugador yo) {
    final esMio = sala.turnoActual == widget.miUid && yo.vivo;
    final acabaDeTocarme = esMio && _turnoAnterior != widget.miUid;
    _turnoAnterior = sala.turnoActual;

    if (!acabaDeTocarme || !_avisoActivado) return;

    // No se puede animar ni vibrar mientras se construye la pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _destello.forward(from: 0);
      // Dos toques cortos: se nota aunque el movil este en la mesa.
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 140));
      await HapticFeedback.heavyImpact();
    });
  }

  Future<void> _cambiarAviso() async {
    final nuevo = !_avisoActivado;
    setState(() => _avisoActivado = nuevo);
    await Preferencias.guardarAvisoTurno(nuevo);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nuevo
              ? 'Te avisaremos cuando te toque'
              : 'Aviso de turno desactivado',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _procesando = false;

  /// Indice (en la mano) de la carta que tengo elegida.
  int? _seleccion;

  /// True mientras espero a que toques al rival al que apuntas.
  bool _eligiendoObjetivo = false;

  /// Las cartas de la mano empiezan tapadas: así se puede jugar en persona
  /// con el móvil sobre la mesa sin que nadie te vea la carta. Además, al
  /// estar tapadas ocupan menos y el tablero se ve más grande.
  bool _manoVisible = false;

  // ==========================================================
  // ACCIONES
  // ==========================================================

  Future<void> _ejecutar(
    Future<String?> accion, {
    bool taparMano = false,
  }) async {
    if (_procesando) return;
    setState(() => _procesando = true);
    final error = await accion;
    if (!mounted) return;
    setState(() {
      _procesando = false;
      if (error == null) {
        _seleccion = null;
        _eligiendoObjetivo = false;
        // Al acabar tu jugada las cartas vuelven a taparse, que es cuando se
        // pasa el movil al siguiente.
        if (taparMano) _manoVisible = false;
      }
    });
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.peligro,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(error)),
            ],
          ),
        ),
      );
    }
  }

  void _pulsarCartaMano(int indice) {
    setState(() {
      if (_seleccion == indice) {
        _seleccion = null;
      } else {
        _seleccion = indice;
      }
      _eligiendoObjetivo = false;
    });
  }

  void _confirmarJugada(int valor, List<Jugador> rivales) {
    final atacables = rivales.where((r) => r.vivo && !r.protegido).toList();

    if (!Cartas.requiereObjetivo(valor) || atacables.isEmpty) {
      // Sin objetivo posible la carta se juega igual, pero sin efecto.
      _ejecutar(
        _repo.jugarCarta(widget.idSala, widget.miUid, valor),
        taparMano: true,
      );
      return;
    }
    setState(() => _eligiendoObjetivo = true);
  }

  void _apuntarA(Jugador rival, int valor) {
    if (Cartas.requiereAdivinanza(valor)) {
      _hojaAdivinar(rival, valor);
    } else {
      _ejecutar(
        _repo.jugarCarta(
          widget.idSala,
          widget.miUid,
          valor,
          targetUid: rival.uid,
        ),
        taparMano: true,
      );
    }
  }

  // ==========================================================
  // HOJAS Y DIALOGOS
  // ==========================================================

  void _hojaAdivinar(Jugador rival, int valor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tirador(),
              const SizedBox(height: 12),
              Text(
                'Que carta tiene ${rival.nombre}?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Si aciertas, queda eliminado. Si fallas, no revela nada.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textoSuave),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: List.generate(10, (i) {
                  final numero = i + 1;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _ejecutar(
                        _repo.jugarCarta(
                          widget.idSala,
                          widget.miUid,
                          valor,
                          targetUid: rival.uid,
                          adivinanza: numero,
                        ),
                        taparMano: true,
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CartaWidget(valor: numero, altura: 74, compacta: true),
                        const SizedBox(height: 3),
                        SizedBox(
                          width: 56,
                          child: Text(
                            Cartas.nombreCorto(numero),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 8.5,
                              color: AppColors.textoSuave,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _hojaHistorial(Sala sala) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controlador) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: ListView(
              controller: controlador,
              children: [
                const SizedBox(height: 12),
                Center(child: _tirador()),
                const SizedBox(height: 14),
                const Text(
                  'Lo que ha pasado',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (sala.registro.isEmpty)
                  const Text(
                    'Todavia no ha pasado nada.',
                    style: TextStyle(color: AppColors.textoSuave),
                  ),
                ...sala.registro.reversed.toList().asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6, right: 10),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: e.key == 0
                                ? AppColors.acento
                                : AppColors.textoTenue,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: e.key == 0
                                  ? AppColors.texto
                                  : AppColors.textoSuave,
                              fontWeight: e.key == 0
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _hojaCartas() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          builder: (_, controlador) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: ListView(
              controller: controlador,
              children: [
                const SizedBox(height: 12),
                Center(child: _tirador()),
                const SizedBox(height: 14),
                const Text(
                  'Las 21 cartas del mazo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ...Cartas.catalogo.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CartaWidget(valor: c.valor, altura: 78),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.nombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.acentoSuave,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.superficieAlta,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'x${c.cantidad}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c.efecto,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.3,
                                  color: AppColors.textoSuave,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dialogoCarta(int valor) {
    final info = Cartas.info(valor);
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CartaWidget(
              valor: valor,
              altura: MediaQuery.of(context).size.height * 0.45,
            ),
            const SizedBox(height: 14),
            Panel(
              child: Column(
                children: [
                  Text(
                    '${info.valor}  ·  ${info.nombre}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    info.efecto,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _explicarFueraDeJuego() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cartas fuera de juego'),
        content: const Text(
          'En las partidas de 2 jugadores se apartan 3 cartas antes de '
          'empezar: estas 2 se dejan boca arriba y otra queda oculta.\n\n'
          'Es una regla del juego: sirve para que no puedas deducir con '
          'certeza que carta tiene el rival contando las que han salido.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _tirador() => Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: AppColors.textoTenue,
      borderRadius: BorderRadius.circular(4),
    ),
  );

  Jugador? _buscar(List<Jugador> jugadores, String uid) {
    for (final j in jugadores) {
      if (j.uid == uid) return j;
    }
    return null;
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Sala>(
      stream: _salaStream,
      builder: (context, snapSala) {
        if (!snapSala.hasData) return const _Cargando();
        final sala = snapSala.data!;

        return StreamBuilder<List<Jugador>>(
          stream: _jugadoresStream,
          builder: (context, snapJugadores) {
            if (!snapJugadores.hasData) return const _Cargando();

            final jugadores = snapJugadores.data!;
            final yo = _buscar(jugadores, widget.miUid);
            if (yo == null) {
              return const Scaffold(
                body: MesaFondo(
                  child: Center(child: Text('Ya no estas en esta partida')),
                ),
              );
            }

            _vigilarEliminacion(yo);

            // El aviso de "te estoy grabando" va por encima de todo, en
            // cualquier pantalla: nadie debe tener el micro abierto sin verlo.
            Widget conAvisoDeMicro(Widget pantalla) => Stack(
              children: [pantalla, if (_grabando) const _AvisoGrabando()],
            );

            if (sala.terminada) {
              // Antes del marcador se repasa la ronda enseñando las cartas.
              if (!_repasoHecho && sala.historial.isNotEmpty) {
                return conAvisoDeMicro(
                  ResumenRondaScreen(
                    sala: sala,
                    jugadores: jugadores,
                    miUid: widget.miUid,
                    onVerCarta: _dialogoCarta,
                    onTerminar: () => setState(() => _repasoHecho = true),
                  ),
                );
              }
              return conAvisoDeMicro(_pantallaResultado(sala, jugadores));
            }
            return conAvisoDeMicro(_pantallaMesa(sala, jugadores, yo));
          },
        );
      },
    );
  }

  // ==========================================================
  // MESA
  // ==========================================================

  Widget _pantallaMesa(Sala sala, List<Jugador> jugadores, Jugador yo) {
    // Se esta jugando: el repaso de la ronda que acabe habra que verlo.
    _repasoHecho = false;
    _vigilarTurno(sala, yo);
    _vigilarJugada(sala);

    final rivales = jugadores.where((j) => j.uid != widget.miUid).toList();
    final esMiTurno = sala.turnoActual == widget.miUid;
    final tengoQueRobar = esMiTurno && yo.vivo && yo.mano.length == 1;
    final puedoJugar =
        esMiTurno &&
        yo.vivo &&
        yo.mano.length == 2 &&
        yo.accionPendiente == null;

    final seleccionValida =
        puedoJugar && _seleccion != null && _seleccion! < yo.mano.length
        ? _seleccion
        : null;
    final valorSeleccionado = seleccionValida == null
        ? null
        : yo.mano[seleccionValida];

    return Scaffold(
      body: MesaFondo(
        child: SafeArea(
          child: Center(
            // En pantallas anchas (ordenador, tablet) el tablero no se estira:
            // se queda con forma de mesa y centrado.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: LayoutBuilder(
                builder: (context, restricciones) {
                  final alto = restricciones.maxHeight;
                  final apretado = alto < 620;

                  // Reparto vertical. Las barras son fijas y el resto se
                  // reparte en porcentajes, así que la suma siempre da el
                  // alto disponible y nunca hay que hacer scroll.
                  final hSuperior = apretado ? 40.0 : 46.0;
                  final hTurno = apretado ? 30.0 : 36.0;
                  final hAccion = apretado ? 52.0 : 60.0;
                  final libre = alto - hSuperior - hTurno - hAccion;

                  final hAsientos = libre * 0.22;
                  // Con la mano tapada mi zona ocupa mucho menos y todo ese
                  // hueco se lo queda el tablero.
                  final hMiZona = libre * (_manoVisible ? 0.38 : 0.20);
                  final hCentro = libre - hAsientos - hMiZona;

                  return Stack(
                    children: [
                      Column(
                        children: [
                          SizedBox(
                            height: hSuperior,
                            child: _barraSuperior(sala, yo),
                          ),
                          SizedBox(
                            height: hTurno,
                            child: _barraTurno(sala, jugadores, yo),
                          ),
                          SizedBox(
                            height: hAsientos,
                            child: _filaAsientos(
                              sala,
                              rivales,
                              hAsientos,
                              valorSeleccionado,
                            ),
                          ),
                          SizedBox(
                            height: hCentro,
                            child: _centro(sala, jugadores),
                          ),
                          SizedBox(
                            height: hMiZona,
                            child: _miZona(
                              sala,
                              yo,
                              puedoJugar,
                              seleccionValida,
                            ),
                          ),
                          SizedBox(
                            height: hAccion,
                            child: _barraAccion(
                              sala,
                              jugadores,
                              yo,
                              rivales,
                              tengoQueRobar,
                              valorSeleccionado,
                            ),
                          ),
                        ],
                      ),
                      if (yo.revelaciones.isNotEmpty)
                        _capaRevelacion(yo)
                      else if (yo.accionPendiente != null)
                        _capaPendiente(sala, yo),
                      Positioned.fill(
                        child: DestelloTurno(animacion: _destello),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _barraSuperior(Sala sala, Jugador yo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
      child: Row(
        children: [
          // Se encoge si hace falta: en moviles estrechos los tres botones
          // de la derecha se comen el sitio.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.superficie.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borde),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.tag,
                          size: 13,
                          color: AppColors.textoTenue,
                        ),
                        Text(
                          sala.id,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Etiqueta('ronda ${sala.ronda}'),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _microActivado ? Icons.mic : Icons.mic_off,
              size: 20,
              color: _microActivado ? AppColors.acento : AppColors.textoTenue,
            ),
            tooltip: _microActivado
                ? 'Al caer, tu micro se abre 5 s: activado'
                : 'Al caer, tu micro se abre 5 s: desactivado',
            onPressed: _cambiarMicro,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _avisoActivado
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              size: 20,
              color: _avisoActivado ? AppColors.acento : AppColors.textoTenue,
            ),
            tooltip: _avisoActivado
                ? 'Avisar cuando me toque: activado'
                : 'Avisar cuando me toque: desactivado',
            onPressed: _cambiarAviso,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.receipt_long, size: 21),
            tooltip: 'Historial',
            onPressed: () => _hojaHistorial(sala),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.style, size: 21),
            tooltip: 'Ver todas las cartas',
            onPressed: _hojaCartas,
          ),
        ],
      ),
    );
  }

  /// Píldora que deja claro de quién es el turno.
  Widget _barraTurno(Sala sala, List<Jugador> jugadores, Jugador yo) {
    final enTurno = _buscar(jugadores, sala.turnoActual);
    final esMio = sala.turnoActual == widget.miUid;

    final Color color;
    final String texto;
    if (!yo.vivo) {
      color = AppColors.peligro;
      texto = 'Estas fuera de esta ronda';
    } else if (esMio) {
      color = AppColors.acento;
      texto = 'TU TURNO';
    } else if (enTurno != null) {
      color = AppColors.asiento(enTurno.orden);
      texto = 'Turno de ${enTurno.nombre}';
    } else {
      color = AppColors.textoTenue;
      texto = 'Esperando...';
    }

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: esMio ? 14 : 13,
                    fontWeight: esMio ? FontWeight.w900 : FontWeight.w700,
                    letterSpacing: esMio ? 2 : 0.2,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filaAsientos(
    Sala sala,
    List<Jugador> rivales,
    double altura,
    int? valorSeleccionado,
  ) {
    if (rivales.isEmpty) {
      return const Center(child: Etiqueta('sin rivales'));
    }

    final asientos = rivales.map((r) {
      final seleccionable =
          _eligiendoObjetivo &&
          valorSeleccionado != null &&
          r.vivo &&
          !r.protegido;
      return AsientoWidget(
        jugador: r,
        esSuTurno: sala.turnoActual == r.uid,
        seleccionable: seleccionable,
        fichasParaGanar: sala.fichasParaGanar,
        altura: altura,
        onTap: () => _apuntarA(r, valorSeleccionado!),
        onVerCarta: _dialogoCarta,
        // Si la ultima jugada le afecto, su sitio lo acusa.
        reaccion: sala.ultimaJugada?.objetivoUid == r.uid
            ? sala.ultimaJugada!.efecto.reaccion
            : ReaccionAsiento.ninguna,
      );
    }).toList();

    // Si caben, van centrados; si no, la fila se desplaza.
    return LayoutBuilder(
      builder: (context, restricciones) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: restricciones.maxWidth - 20 > 0
                ? restricciones.maxWidth - 20
                : 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: asientos,
          ),
        ),
      ),
    );
  }

  /// Mazo y última jugada. Se dimensiona con el alto que recibe, para que
  /// nunca haya que hacer scroll.
  Widget _centro(Sala sala, List<Jugador> jugadores) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        final alto = restricciones.maxHeight;
        // La fila del mazo se lleva un tercio; el resto es para la carta
        // grande de la última jugada, que es lo que interesa ver.
        final hFila = (alto * 0.34).clamp(46.0, 84.0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
          child: Column(
            children: [
              SizedBox(height: hFila, child: _filaMazo(sala, hFila)),
              const SizedBox(height: 6),
              // Con la mano tapada sobra mucho sitio, pero una carta gigante
              // queda rara: se le pone tope y se centra.
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 210),
                    child: _ultimaJugada(sala, jugadores),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Mazo, carta apartada y (en partidas de 2) las cartas fuera de juego.
  Widget _filaMazo(Sala sala, double altoTotal) {
    // Debajo de cada montón va su etiqueta, así que la carta se queda con
    // lo que sobra.
    final alto = (altoTotal - 16).clamp(28.0, 70.0);

    Widget columna(Widget arriba, Widget etiqueta) => Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [arriba, etiqueta],
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          columna(
            MazoApilado(cantidad: sala.mazoCentral.length, altura: alto),
            const Etiqueta('mazo'),
          ),
          const SizedBox(width: 18),
          columna(
            Opacity(
              opacity: sala.cartaOculta == null ? 0.25 : 1,
              child: CartaWidget(valor: null, altura: alto),
            ),
            const Etiqueta('apartada'),
          ),
          if (sala.cartasApartadas.isNotEmpty) ...[
            const SizedBox(width: 18),
            columna(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: sala.cartasApartadas
                    .map(
                      (c) => CartaMini(
                        valor: c,
                        altura: alto,
                        onTap: () => _dialogoCarta(c),
                      ),
                    )
                    .toList(),
              ),
              GestureDetector(
                onTap: _explicarFueraDeJuego,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Etiqueta('fuera de juego'),
                    SizedBox(width: 3),
                    Icon(
                      Icons.info_outline,
                      size: 11,
                      color: AppColors.textoTenue,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// La última carta jugada, en grande y con lo que ha provocado.
  Widget _ultimaJugada(Sala sala, List<Jugador> jugadores) {
    final jugada = sala.ultimaJugada;

    if (jugada == null) {
      return const Center(
        child: Panel(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.style_outlined, size: 16, color: AppColors.textoTenue),
              SizedBox(width: 9),
              Flexible(
                child: Text(
                  'Todavia no ha jugado nadie',
                  style: TextStyle(fontSize: 13, color: AppColors.textoSuave),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final quien = _buscar(jugadores, jugada.uid);
    final color = quien == null
        ? AppColors.textoSuave
        : AppColors.asiento(quien.orden);

    return LayoutBuilder(
      builder: (context, restricciones) {
        const relleno = 10.0;
        final altoCarta = restricciones.maxHeight - relleno * 2;

        return Panel(
          key: const Key('ultimaJugada'),
          padding: const EdgeInsets.all(relleno),
          borde: color.withValues(alpha: 0.45),
          child: AnimacionJugada(
            jugada: jugada,
            animacion: _animJugada,
            colorJugador: color,
            altoCarta: altoCarta,
            onVerCarta: () => _dialogoCarta(jugada.carta),
          ),
        );
      },
    );
  }

  /// Mi zona: quién soy, lo que llevo jugado y mi mano. Se reparte el alto
  /// que reciba, así que la mano crece o encoge con la pantalla.
  Widget _miZona(Sala sala, Jugador yo, bool puedoJugar, int? seleccion) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      decoration: BoxDecoration(
        color: AppColors.fondo.withValues(alpha: 0.55),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: AppColors.borde)),
      ),
      child: LayoutBuilder(
        builder: (context, restricciones) {
          final alto = restricciones.maxHeight;
          // Con poco sitio se sacrifica lo accesorio y la mano se queda con
          // todo lo que sobre: así nunca desborda ni hace falta scroll.
          final hayJugadas = yo.cartasJugadas.isNotEmpty && alto >= 130;
          final hayPista = alto >= 120;

          return Column(
            children: [
              SizedBox(height: 26, child: _cabeceraMiZona(sala, yo)),
              if (hayJugadas)
                SizedBox(
                  height: (alto * 0.17).clamp(26.0, 42.0),
                  child: Row(
                    children: [
                      const Etiqueta('has jugado'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, r) => ListView(
                            scrollDirection: Axis.horizontal,
                            children: yo.cartasJugadas
                                .map(
                                  (c) => CartaMini(
                                    valor: c,
                                    altura: r.maxHeight,
                                    onTap: () => _dialogoCarta(c),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, r) =>
                      _manoEnAbanico(yo, r.maxHeight, puedoJugar, seleccion),
                ),
              ),
              if (hayPista)
                SizedBox(
                  height: 15,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      !_manoVisible
                          ? 'Tus cartas estan tapadas · tocalas para mirarlas'
                          : puedoJugar
                          ? 'Toca para elegirla · manten pulsada para verla'
                          : 'Toca cualquier carta de la mesa para verla',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textoTenue,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _cabeceraMiZona(Sala sala, Jugador yo) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.asiento(yo.orden),
            border: Border.all(
              color: yo.protegido ? AppColors.escudo : Colors.white24,
              width: yo.protegido ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              yo.nombre.isEmpty ? '?' : yo.nombre[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            yo.nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        FichasPips(ganadas: yo.fichasVictoria, total: sala.fichasParaGanar),
        const Spacer(),
        if (yo.protegido) ...[
          const Icon(Icons.shield, size: 12, color: AppColors.escudo),
          const SizedBox(width: 4),
          const Etiqueta('protegido', color: AppColors.escudo),
          const SizedBox(width: 8),
        ],
        if (yo.mano.isNotEmpty)
          GestureDetector(
            onTap: () => setState(() => _manoVisible = !_manoVisible),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: _manoVisible
                    ? AppColors.superficieAlta
                    : AppColors.acento.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _manoVisible
                      ? AppColors.borde
                      : AppColors.acento.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _manoVisible ? Icons.visibility_off : Icons.visibility,
                    size: 13,
                    color: _manoVisible
                        ? AppColors.textoSuave
                        : AppColors.acento,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _manoVisible ? 'TAPAR' : 'MIRAR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: _manoVisible
                          ? AppColors.textoSuave
                          : AppColors.acento,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _manoEnAbanico(
    Jugador yo,
    double altoMano,
    bool puedoJugar,
    int? seleccion,
  ) {
    if (yo.mano.isEmpty) {
      return const Center(
        child: Text(
          'Sin cartas en la mano',
          style: TextStyle(color: AppColors.textoTenue),
        ),
      );
    }
    // La carta elegida se levanta un poco, así que se reserva ese hueco.
    final levanta = altoMano > 90 && _manoVisible ? 10.0 : 0.0;
    final alto = (altoMano - levanta).clamp(24.0, 1000.0);

    return Row(
      key: const Key('mano'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(yo.mano.length, (i) {
        final elegida = _manoVisible && seleccion == i;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(
            left: 7,
            right: 7,
            bottom: elegida ? levanta : 0,
          ),
          child: CartaWidget(
            // Tapada = se ve el dorso, como en la mesa de verdad.
            valor: _manoVisible ? yo.mano[i] : null,
            altura: alto,
            seleccionada: elegida,
            onTap: !_manoVisible
                ? () => setState(() => _manoVisible = true)
                : puedoJugar
                ? () => _pulsarCartaMano(i)
                : () => _dialogoCarta(yo.mano[i]),
            onLongPress: _manoVisible
                ? () => _dialogoCarta(yo.mano[i])
                : () => setState(() => _manoVisible = true),
          ),
        );
      }),
    );
  }

  Widget _barraAccion(
    Sala sala,
    List<Jugador> jugadores,
    Jugador yo,
    List<Jugador> rivales,
    bool tengoQueRobar,
    int? valorSeleccionado,
  ) {
    Widget contenido;

    if (yo.accionPendiente != null) {
      contenido = _textoAccion('Resuelve tu carta arriba', Icons.pending);
    } else if (!yo.vivo) {
      contenido = _textoAccion(
        'Espera a que acabe la ronda',
        Icons.hourglass_bottom,
      );
    } else if (sala.turnoActual != widget.miUid) {
      contenido = _textoAccion(
        'Esperando a ${_buscar(jugadores, sala.turnoActual)?.nombre ?? "..."}',
        Icons.more_horiz,
      );
    } else if (tengoQueRobar) {
      contenido = SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.download, size: 19),
          label: const Text('ROBAR CARTA'),
          onPressed: _procesando
              ? null
              : () => _ejecutar(_repo.robarCarta(widget.idSala, widget.miUid)),
        ),
      );
    } else if (_eligiendoObjetivo && valorSeleccionado != null) {
      contenido = Row(
        children: [
          const Expanded(
            child: Row(
              children: [
                Icon(Icons.gps_fixed, size: 17, color: AppColors.acento),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Toca al rival al que apuntas',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppColors.acento,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _eligiendoObjetivo = false),
            child: const Text('Cancelar'),
          ),
        ],
      );
    } else if (valorSeleccionado != null) {
      contenido = Row(
        children: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Ver la carta',
            onPressed: () => _dialogoCarta(valorSeleccionado),
          ),
          Expanded(
            child: ElevatedButton(
              onPressed: _procesando
                  ? null
                  : () => _confirmarJugada(valorSeleccionado, rivales),
              child: Text(
                'JUGAR ${Cartas.nombreCorto(valorSeleccionado).toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      );
    } else if (!_manoVisible) {
      // No se puede elegir carta sin verla: se ofrece destaparla.
      contenido = SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.visibility, size: 19),
          label: const Text('MIRAR MIS CARTAS'),
          onPressed: () => setState(() => _manoVisible = true),
        ),
      );
    } else {
      contenido = _textoAccion('Elige una carta para jugarla', Icons.touch_app);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      color: AppColors.fondo.withValues(alpha: 0.55),
      child: Center(child: contenido),
    );
  }

  Widget _textoAccion(String texto, IconData icono) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icono, size: 16, color: AppColors.textoTenue),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          texto,
          style: const TextStyle(fontSize: 13, color: AppColors.textoSuave),
        ),
      ),
    ],
  );

  // ==========================================================
  // CAPAS MODALES (informacion secreta y decisiones)
  // ==========================================================

  Widget _scrim({required Widget child}) => Positioned.fill(
    child: Container(
      color: Colors.black.withValues(alpha: 0.72),
      padding: const EdgeInsets.all(22),
      child: Center(child: SingleChildScrollView(child: child)),
    ),
  );

  Widget _capaRevelacion(Jugador yo) {
    return _scrim(
      child: Panel(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        borde: AppColors.secreto,
        color: AppColors.superficie,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility, color: AppColors.secreto, size: 30),
            const SizedBox(height: 8),
            const Etiqueta('solo lo ves tu', color: AppColors.secreto),
            const SizedBox(height: 14),
            ...yo.revelaciones.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  r,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14.5, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    _repo.limpiarRevelaciones(widget.idSala, widget.miUid),
                child: const Text('ENTENDIDO'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _capaPendiente(Sala sala, Jugador yo) {
    final pendiente = yo.accionPendiente!;
    final carta = pendiente.carta;
    final esEnterrador = pendiente.tipo == 'enterrador';

    return _scrim(
      child: Panel(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        borde: AppColors.acento,
        color: AppColors.superficie,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Etiqueta(
              esEnterrador ? 'el ladron de sombras' : 'el correvvidile',
              color: AppColors.acento,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    CartaWidget(valor: carta, altura: 116),
                    const SizedBox(height: 6),
                    Etiqueta(esEnterrador ? 'la apartada' : 'la de arriba'),
                  ],
                ),
                if (esEnterrador && yo.mano.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.swap_horiz, color: AppColors.textoTenue),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      CartaWidget(valor: yo.mano.first, altura: 116),
                      const SizedBox(height: 6),
                      const Etiqueta('la tuya'),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            if (esEnterrador)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _procesando
                          ? null
                          : () => _ejecutar(
                              _repo.resolverPerroSepulturero(
                                widget.idSala,
                                widget.miUid,
                                true,
                              ),
                            ),
                      child: const Text('QUEDARME LA APARTADA'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _procesando
                          ? null
                          : () => _ejecutar(
                              _repo.resolverPerroSepulturero(
                                widget.idSala,
                                widget.miUid,
                                false,
                              ),
                            ),
                      child: const Text('Dejarla donde estaba'),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  const Text(
                    'Donde la devuelves al mazo?',
                    style: TextStyle(fontSize: 13, color: AppColors.textoSuave),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    alignment: WrapAlignment.center,
                    children: List.generate(sala.mazoCentral.length + 1, (i) {
                      final total = sala.mazoCentral.length + 1;
                      final etiqueta = i == 0
                          ? 'Arriba'
                          : i == total - 1
                          ? 'Abajo'
                          : '${i + 1}a';
                      return ActionChip(
                        label: Text(
                          etiqueta,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        backgroundColor: i == 0
                            ? AppColors.acento.withValues(alpha: 0.2)
                            : null,
                        onPressed: _procesando
                            ? null
                            : () => _ejecutar(
                                _repo.resolverCazarratones(
                                  widget.idSala,
                                  widget.miUid,
                                  i,
                                ),
                              ),
                      );
                    }),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // RESULTADO DE RONDA / PARTIDA
  // ==========================================================

  Widget _pantallaResultado(Sala sala, List<Jugador> jugadores) {
    final finPartida = sala.estado == EstadoSala.finPartida;
    return PantallaResultado(
      sala: sala,
      jugadores: jugadores,
      miUid: widget.miUid,
      procesando: _procesando,
      onContinuar: () => _ejecutar(
        finPartida
            ? _repo.nuevaPartida(widget.idSala)
            : _repo.siguienteRonda(widget.idSala),
      ),
      onVolverAlLobby: () => _repo.volverAlLobby(widget.idSala),
      onHistorial: () => _hojaHistorial(sala),
      onVerCarta: _dialogoCarta,
    );
  }
}

/// Barra roja bien visible mientras el micro esta abierto.
class _AvisoGrabando extends StatelessWidget {
  const _AvisoGrabando();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.peligro,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.peligro.withValues(alpha: 0.5),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic, size: 18, color: Colors.white),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'MICRO ABIERTO · te esta oyendo la sala',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      letterSpacing: 0.5,
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

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: MesaFondo(
      child: Center(child: CircularProgressIndicator(color: AppColors.acento)),
    ),
  );
}
