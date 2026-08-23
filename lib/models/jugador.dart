/// Acción pendiente de resolver por el propio jugador (cartas de dos pasos).
class AccionPendiente {
  /// 'ratonera' (carta 2) o 'enterrador' (carta 6).
  final String tipo;

  /// La carta que el jugador está viendo en secreto.
  final int carta;

  const AccionPendiente({required this.tipo, required this.carta});

  static AccionPendiente? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final tipo = data['tipo'] as String?;
    final carta = (data['carta'] as num?)?.toInt();
    if (tipo == null || carta == null) return null;
    return AccionPendiente(tipo: tipo, carta: carta);
  }

  Map<String, dynamic> toMap() => {'tipo': tipo, 'carta': carta};
}

class Jugador {
  final String uid;
  final String nombre;

  /// 1 carta normalmente, 2 durante tu turno (tras robar).
  final List<int> mano;

  /// Cartas que has jugado, boca arriba delante de ti. No hay descarte común.
  final List<int> cartasJugadas;

  final bool vivo;
  final bool protegido;
  final int fichasVictoria;
  final int orden;

  /// Mensajes privados pendientes de leer (información secreta).
  final List<String> revelaciones;

  final AccionPendiente? accionPendiente;

  Jugador({
    required this.uid,
    required this.nombre,
    required this.mano,
    required this.cartasJugadas,
    required this.vivo,
    required this.protegido,
    required this.fichasVictoria,
    required this.orden,
    required this.revelaciones,
    required this.accionPendiente,
  });

  factory Jugador.fromMap(String uid, Map<String, dynamic>? data) {
    final d = data ?? const <String, dynamic>{};
    return Jugador(
      uid: uid,
      nombre: d['nombre'] as String? ?? 'Jugador',
      mano: _listaInt(d['mano']),
      cartasJugadas: _listaInt(d['cartas_jugadas']),
      vivo: d['vivo'] as bool? ?? true,
      protegido: d['protegido'] as bool? ?? false,
      fichasVictoria: (d['fichas_victoria'] as num?)?.toInt() ?? 0,
      orden: (d['orden'] as num?)?.toInt() ?? 0,
      revelaciones:
          (d['revelaciones'] as List?)?.map((e) => e.toString()).toList() ??
              <String>[],
      accionPendiente: AccionPendiente.fromMap(
        (d['accion_pendiente'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  /// La carta más alta que tiene delante (para desempatar al final de ronda).
  int get mayorCartaJugada =>
      cartasJugadas.isEmpty ? -1 : cartasJugadas.reduce((a, b) => a > b ? a : b);

  static List<int> _listaInt(dynamic v) =>
      (v as List?)?.map((e) => (e as num).toInt()).toList() ?? <int>[];
}
