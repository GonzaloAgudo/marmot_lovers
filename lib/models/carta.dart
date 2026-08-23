/// Catálogo de cartas: 21 en total.
///
/// Los nombres son los que aparecen impresos en el arte de
/// `assets/cards/clasico/`. Los efectos son los del reglamento
/// (Power Hungry Pets), que es lo que aplica el motor del juego.
class Carta {
  final int valor;

  /// Nombre completo, tal y como está en la carta.
  final String nombre;

  /// Version corta, para botones, registros y sitios estrechos.
  final String nombreCorto;

  final int cantidad;
  final String efecto;

  const Carta({
    required this.valor,
    required this.nombre,
    required this.nombreCorto,
    required this.cantidad,
    required this.efecto,
  });
}

class Cartas {
  Cartas._();

  static const List<Carta> catalogo = [
    Carta(
      valor: 10,
      nombre: 'Rey del Trono de Peluche',
      nombreCorto: 'Rey del Trono',
      cantidad: 1,
      efecto: 'Si pones esta carta boca arriba por cualquier motivo, quedas '
          'eliminado inmediatamente.',
    ),
    Carta(
      valor: 9,
      nombre: 'La Venganza de la Perezosa',
      nombreCorto: 'La Venganza',
      cantidad: 1,
      efecto: 'Quien tenga al Rey del Trono de Peluche en la mano debe '
          'intercambiar su carta con la tuya. No hace nada si no lo tiene '
          'nadie, o si lo tienes tú.',
    ),
    Carta(
      valor: 8,
      nombre: 'Forja de Hephesto',
      nombreCorto: 'La Forja',
      cantidad: 1,
      efecto: 'Elige a un jugador vivo y obligale a intercambiar la carta de '
          'su mano por la tuya.',
    ),
    Carta(
      valor: 7,
      nombre: 'El Animador de la Fiesta de la Madriguera',
      nombreCorto: 'El Animador',
      cantidad: 1,
      efecto: 'Todos los jugadores vivos (tú incluido) devuelven su carta al '
          'mazo. Se baraja y se reparte una carta nueva a cada uno.',
    ),
    Carta(
      valor: 6,
      nombre: 'El Ladrón de Sombras del Inframundo',
      nombreCorto: 'El Ladrón',
      cantidad: 1,
      efecto: 'Mira en secreto la carta que se aparta al principio de la '
          'ronda. Puedes cambiarla por la de tu mano.',
    ),
    Carta(
      valor: 5,
      nombre: 'El Rey de las Mareas',
      nombreCorto: 'Rey de las Mareas',
      cantidad: 2,
      efecto: 'Elige a un jugador vivo: baja su carta boca arriba sin aplicar '
          'su efecto y roba una nueva. Si le toca bajar al Rey del Trono de '
          'Peluche, queda eliminado.',
    ),
    Carta(
      valor: 4,
      nombre: 'La Sabia del Valle de la Madriguera',
      nombreCorto: 'La Sabia',
      cantidad: 2,
      efecto: 'Hasta tu próximo turno nadie puede mirar tu carta, quitártela '
          'ni obligarte a nada.',
    ),
    Carta(
      valor: 3,
      nombre: 'El Matón del Campo de Batalla',
      nombreCorto: 'El Matón',
      cantidad: 3,
      efecto: 'Elige a un jugador vivo y comparad vuestras cartas en secreto. '
          'El de la carta más baja queda eliminado. Si empatáis, no pasa nada.',
    ),
    Carta(
      valor: 2,
      nombre: 'El Correvvidile de las Madrigueras',
      nombreCorto: 'El Correvvidile',
      cantidad: 3,
      efecto: 'Mira la carta de arriba del mazo y vuelve a meterla en secreto '
          'en la posición que quieras.',
    ),
    Carta(
      valor: 1,
      nombre: 'La Pitonisa de los Túneles',
      nombreCorto: 'La Pitonisa',
      cantidad: 5,
      efecto: 'Elige a un jugador vivo y adivina el número de su carta. Si '
          'aciertas, queda eliminado. Si fallas, no revela nada.',
    ),
    Carta(
      valor: 0,
      nombre: 'El Capo de la Colonia',
      nombreCorto: 'El Capo',
      cantidad: 1,
      efecto: 'Si tienes esta carta al final de la ronda, gana al Rey del '
          'Trono de Peluche (10). No gana contra ninguna otra carta.',
    ),
  ];

  static const Carta _desconocida = Carta(
    valor: -1,
    nombre: 'Carta desconocida',
    nombreCorto: 'Desconocida',
    cantidad: 0,
    efecto: '',
  );

  static Carta info(int valor) => catalogo.firstWhere(
        (c) => c.valor == valor,
        orElse: () => _desconocida,
      );

  static String nombre(int valor) => info(valor).nombre;

  static String nombreCorto(int valor) => info(valor).nombreCorto;

  /// Mazo completo sin barajar (21 cartas).
  static List<int> mazoCompleto() {
    final mazo = <int>[];
    for (final c in catalogo) {
      for (var i = 0; i < c.cantidad; i++) {
        mazo.add(c.valor);
      }
    }
    return mazo;
  }

  /// Cartas que necesitan que elijas a un rival.
  static const Set<int> conObjetivo = {1, 3, 5, 8};

  /// Cartas que además necesitan que adivines un número.
  static bool requiereAdivinanza(int valor) => valor == 1;

  static bool requiereObjetivo(int valor) => conObjetivo.contains(valor);

  /// Cartas cuyo efecto se resuelve en dos pasos (dejan accion pendiente).
  static bool esEnDosPasos(int valor) => valor == 2 || valor == 6;
}
