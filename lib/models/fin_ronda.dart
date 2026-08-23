/// Lo que hace falta saber de un jugador para resolver el final de una ronda.
abstract class ManoFinal {
  /// Valor de la carta que le queda en la mano.
  int get carta;

  /// La carta mas alta de las que tiene boca arriba delante de el.
  int get mayorJugada;
}

/// Decide quien gana la ronda cuando se agota el mazo.
///
/// Reglas:
///  - gana la carta mas alta que quede en la mano;
///  - El Capo de la Colonia (0) le gana al Rey del Trono (10), y solo a el;
///  - si hay empate, desempata la carta mas alta ya jugada;
///  - si sigue habiendo empate, ganan todos los empatados.
///
/// Devuelve la lista de ganadores (nunca vacia si [vivos] no lo esta).
List<T> ganadoresDeRonda<T extends ManoFinal>(
  List<T> vivos, {
  void Function(String)? log,
}) {
  if (vivos.isEmpty) return <T>[];

  final maxValor =
      vivos.map((p) => p.carta).reduce((a, b) => a > b ? a : b);

  if (maxValor == 10) {
    final robovac = vivos.where((p) => p.carta == 0).toList();
    if (robovac.isNotEmpty) {
      log?.call('El Capo de la Colonia (0) le gana al Rey del Trono (10).');
      return robovac;
    }
  }

  var candidatos = vivos.where((p) => p.carta == maxValor).toList();
  if (candidatos.length > 1) {
    final mejor =
        candidatos.map((p) => p.mayorJugada).reduce((a, b) => a > b ? a : b);
    log?.call(
        'Empate a $maxValor: desempata la carta mas alta ya jugada ($mejor).');
    candidatos = candidatos.where((p) => p.mayorJugada == mejor).toList();
  }
  return candidatos;
}
