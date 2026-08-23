/// Estados de la sala.
class EstadoSala {
  EstadoSala._();
  static const int lobby = 0;
  static const int jugando = 1;
  static const int finRonda = 2;
  static const int finPartida = 3;
}

/// La última carta que se ha puesto boca arriba sobre la mesa, para poder
/// enseñarla en grande a todo el mundo.
/// Lo que provoca una carta, para poder animarlo en vez de solo contarlo.
class Efecto {
  Efecto._();

  static const nada = 'nada';
  static const eliminado = 'eliminado';
  static const autoEliminado = 'auto_eliminado';
  static const protegido = 'protegido';
  static const intercambio = 'intercambio';
  static const fallo = 'fallo';
  static const mirada = 'mirada';
  static const rebarajado = 'rebarajado';
  static const forzado = 'forzado';
}

class UltimaJugada {
  final String uid;
  final String nombre;
  final int carta;

  /// Qué pasó al jugarla, en una frase.
  final String resultado;

  /// A quién iba dirigida, si iba a alguien.
  final String? objetivoUid;
  final String? objetivoNombre;

  /// Uno de los valores de [Efecto].
  final String efecto;

  const UltimaJugada({
    required this.uid,
    required this.nombre,
    required this.carta,
    required this.resultado,
    this.objetivoUid,
    this.objetivoNombre,
    this.efecto = Efecto.nada,
  });

  static UltimaJugada? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final carta = (data['carta'] as num?)?.toInt();
    if (carta == null) return null;
    return UltimaJugada(
      uid: data['uid'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      carta: carta,
      resultado: data['resultado'] as String? ?? '',
      objetivoUid: data['objetivo_uid'] as String?,
      objetivoNombre: data['objetivo_nombre'] as String?,
      efecto: data['efecto'] as String? ?? Efecto.nada,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'nombre': nombre,
        'carta': carta,
        'resultado': resultado,
        'objetivo_uid': objetivoUid,
        'objetivo_nombre': objetivoNombre,
        'efecto': efecto,
      };

  UltimaJugada copiaCon({String? resultado, String? efecto}) => UltimaJugada(
        uid: uid,
        nombre: nombre,
        carta: carta,
        resultado: resultado ?? this.resultado,
        objetivoUid: objetivoUid,
        objetivoNombre: objetivoNombre,
        efecto: efecto ?? this.efecto,
      );
}

class Sala {
  final String id;
  final int estado;
  final String hostUid;
  final String turnoActual;

  /// El mazo de robo. La posición 0 es la carta superior.
  final List<int> mazoCentral;

  /// Carta apartada boca abajo al principio de la ronda.
  final int? cartaOculta;

  /// Cartas apartadas boca arriba (solo en partidas de 2 jugadores).
  final List<int> cartasApartadas;

  /// Orden de turnos (uids).
  final List<String> ordenJugadores;

  final int ronda;
  final int fichasParaGanar;

  /// Nombres de quien ha ganado la ronda (puede haber empate).
  final List<String> ganadoresRonda;
  final String? ganadorRondaUid;

  /// Nombres de quien ha ganado la partida.
  final List<String> ganadoresPartida;

  /// Historial público de lo que ha pasado en la ronda.
  final List<String> registro;

  /// Última carta jugada, para enseñarla en grande en el centro de la mesa.
  final UltimaJugada? ultimaJugada;

  /// Todas las cartas jugadas en la ronda, en orden. Es lo que permite
  /// repasar la partida al final enseñando las cartas, no solo texto.
  final List<UltimaJugada> historial;

  /// Cómo acabó la ronda: `ultimo_en_pie` o `mazo_agotado`.
  final String? motivoFinal;

  /// Carta con la que se ganó la ronda.
  final int? cartaGanadora;

  Sala({
    required this.id,
    required this.estado,
    required this.hostUid,
    required this.turnoActual,
    required this.mazoCentral,
    required this.cartaOculta,
    required this.cartasApartadas,
    required this.ordenJugadores,
    required this.ronda,
    required this.fichasParaGanar,
    required this.ganadoresRonda,
    required this.ganadorRondaUid,
    required this.ganadoresPartida,
    required this.registro,
    required this.ultimaJugada,
    required this.historial,
    required this.motivoFinal,
    required this.cartaGanadora,
  });

  factory Sala.fromMap(String id, Map<String, dynamic>? data) {
    final d = data ?? const <String, dynamic>{};
    return Sala(
      id: id,
      estado: (d['estado'] as num?)?.toInt() ?? EstadoSala.lobby,
      hostUid: d['host_uid'] as String? ?? '',
      turnoActual: d['turno_actual'] as String? ?? '',
      mazoCentral: _listaInt(d['mazo_central']),
      cartaOculta: (d['carta_oculta'] as num?)?.toInt(),
      cartasApartadas: _listaInt(d['cartas_apartadas']),
      ordenJugadores: _listaString(d['orden_jugadores']),
      ronda: (d['ronda'] as num?)?.toInt() ?? 0,
      fichasParaGanar: (d['fichas_para_ganar'] as num?)?.toInt() ?? 3,
      ganadoresRonda: _listaString(d['ganadores_ronda']),
      ganadorRondaUid: d['ganador_ronda_uid'] as String?,
      ganadoresPartida: _listaString(d['ganadores_partida']),
      registro: _listaString(d['registro']),
      ultimaJugada: UltimaJugada.fromMap(
        (d['ultima_jugada'] as Map?)?.cast<String, dynamic>(),
      ),
      historial: ((d['historial_jugadas'] as List?) ?? const [])
          .map((e) =>
              UltimaJugada.fromMap((e as Map).cast<String, dynamic>()))
          .whereType<UltimaJugada>()
          .toList(),
      motivoFinal: d['motivo_final'] as String?,
      cartaGanadora: (d['carta_ganadora'] as num?)?.toInt(),
    );
  }

  bool get enJuego => estado == EstadoSala.jugando;
  bool get terminada =>
      estado == EstadoSala.finRonda || estado == EstadoSala.finPartida;

  static List<int> _listaInt(dynamic v) =>
      (v as List?)?.map((e) => (e as num).toInt()).toList() ?? <int>[];

  static List<String> _listaString(dynamic v) =>
      (v as List?)?.map((e) => e.toString()).toList() ?? <String>[];
}
