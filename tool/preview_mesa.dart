// Banco de pruebas visual: dibuja la mesa con datos falsos, sin Firebase.
// No forma parte de la app. Se ejecuta con:
//   flutter run -d chrome -t tool/preview_mesa.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:marmot_lovers/models/jugador.dart';
import 'package:marmot_lovers/models/sala.dart';
import 'package:marmot_lovers/providers/style_provider.dart';
import 'package:marmot_lovers/repositories/game_repository.dart';
import 'package:marmot_lovers/screens/game_screen.dart';
import 'package:marmot_lovers/theme/app_theme.dart';

class RepoFalso extends GameRepository {
  final Sala sala;
  final List<Jugador> jugadores;
  RepoFalso(this.sala, this.jugadores);

  @override
  Stream<Sala> streamSala(String idSala) => Stream.value(sala);

  @override
  Stream<List<Jugador>> streamJugadores(String idSala) =>
      Stream.value(jugadores);
}

/// Emite primero la mesa y, un momento después, una jugada nueva: así se
/// ve la animación con la que se anuncia cada jugada.
class RepoAnimado extends GameRepository {
  final Sala inicial;
  final Sala conJugada;
  final List<Jugador> jugadores;

  RepoAnimado(this.inicial, this.conJugada, this.jugadores);

  @override
  Stream<Sala> streamSala(String idSala) async* {
    yield inicial;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    yield conJugada;
  }

  @override
  Stream<List<Jugador>> streamJugadores(String idSala) =>
      Stream.value(jugadores);
}

Sala sala({
  int estado = EstadoSala.jugando,
  String turno = 'yo',
  List<int> mazo = const [5, 3, 1, 9, 2, 4, 1, 7, 3],
  List<int> apartadas = const [],
  List<String> ganadoresRonda = const [],
  List<String> ganadoresPartida = const [],
  Map<String, dynamic>? ultimaJugada,
  List<Map<String, dynamic>> historial = const [],
}) {
  return Sala.fromMap('7K2P', {
    'estado': estado,
    'host_uid': 'yo',
    'turno_actual': turno,
    'mazo_central': mazo,
    'carta_oculta': 6,
    'cartas_apartadas': apartadas,
    'orden_jugadores': const ['yo'],
    'ronda': 2,
    'fichas_para_ganar': 2,
    'ganadores_ronda': ganadoresRonda,
    'ganadores_partida': ganadoresPartida,
    'ultima_jugada': ultimaJugada,
    'historial_jugadas': historial,
    'registro': const [
      'Ronda 2. Empieza Gonzalo.',
      'Marta juega 4 Escudo de Concha.',
      'Javi juega 1 Cuenco de Cristal.',
      'Javi dice que Lucia tiene un 5: falla, y Lucia no revela nada.',
    ],
  });
}

Jugador jug(
  String uid,
  String nombre,
  int orden, {
  List<int> mano = const [3],
  List<int> jugadas = const [],
  bool vivo = true,
  bool protegido = false,
  int fichas = 0,
  List<String> revelaciones = const [],
  Map<String, dynamic>? pendiente,
}) {
  return Jugador.fromMap(uid, {
    'nombre': nombre,
    'mano': mano,
    'cartas_jugadas': jugadas,
    'vivo': vivo,
    'protegido': protegido,
    'fichas_victoria': fichas,
    'orden': orden,
    'revelaciones': revelaciones,
    'accion_pendiente': pendiente,
  });
}

class Marco extends StatelessWidget {
  final String titulo;
  final Sala s;
  final List<Jugador> j;

  /// Para los marcos que necesitan algo más que una mesa fija (animaciones).
  final GameRepository? repo;

  const Marco(this.titulo, this.s, this.j, {super.key, this.repo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Text(titulo,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            width: 390,
            height: 800,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: MediaQuery(
              data: const MediaQueryData(size: Size(390, 800)),
              child: GameScreen(
                idSala: '7K2P',
                miUid: 'yo',
                repositorio: repo ?? RepoFalso(s, j),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  final mesa = [
    jug('yo', 'Gonzalo', 0, mano: [8, 2], jugadas: [1, 4], fichas: 1),
    jug('r1', 'Marta', 1, jugadas: [4], protegido: true),
    jug('r2', 'Javi', 2, jugadas: [1, 1, 3], fichas: 1),
    jug('r3', 'Lucia', 3, jugadas: [10], vivo: false),
  ];

  runApp(
    ChangeNotifierProvider(
      create: (_) => StyleProvider(),
      child: MaterialApp(
        theme: AppTheme.oscuro,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF101010),
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Marco(
                    '1. Mi turno (4 jugadores)',
                    sala(ultimaJugada: const {
                      'uid': 'r2',
                      'nombre': 'Javi',
                      'carta': 1,
                      'resultado': 'Javi dice que Lucia tiene un 5: falla, '
                          'y Lucia no revela nada.',
                    }),
                    mesa),
                Marco(
                  '2. Turno de otro',
                  sala(turno: 'r2', ultimaJugada: const {
                    'uid': 'r1',
                    'nombre': 'Marta',
                    'carta': 5,
                    'resultado': 'Marta obliga a Lucia a bajar su 10 Rey del '
                        'Trono sin efecto. Era el Rey del Trono: Lucia queda '
                        'eliminada.',
                  }),
                  [
                    jug('yo', 'Gonzalo', 0, mano: [8], jugadas: [1, 4]),
                    jug('r1', 'Marta', 1, jugadas: [4], protegido: true),
                    jug('r2', 'Javi', 2, jugadas: [1, 1, 3], fichas: 1),
                    jug('r3', 'Lucia', 3, jugadas: [10], vivo: false),
                  ],
                ),
                Marco(
                  '3. Perro Sepulturero',
                  sala(),
                  [
                    jug('yo', 'Gonzalo', 0,
                        mano: [3],
                        jugadas: [1, 6],
                        pendiente: {'tipo': 'enterrador', 'carta': 9}),
                    ...mesa.sublist(1),
                  ],
                ),
                Marco(
                  '4. Aviso privado',
                  sala(),
                  [
                    jug('yo', 'Gonzalo', 0, mano: [8, 2], revelaciones: const [
                      'Conejo Guerrero: tu 8 contra el 5 de Marta.',
                    ]),
                    ...mesa.sublist(1),
                  ],
                ),
                Marco(
                  '5. Fin de ronda',
                  sala(
                      estado: EstadoSala.finRonda,
                      turno: '',
                      ganadoresRonda: const ['Marta']),
                  [
                    jug('yo', 'Gonzalo', 0,
                        mano: [], jugadas: [1, 3], vivo: false, fichas: 1),
                    jug('r1', 'Marta', 1, mano: [9], jugadas: [4], fichas: 1),
                    jug('r2', 'Javi', 2, mano: [2], jugadas: [1, 1, 3]),
                    jug('r3', 'Lucia', 3,
                        mano: [], jugadas: [10], vivo: false),
                  ],
                ),
                Marco(
                  '6. Partida de 2',
                  sala(apartadas: const [7, 10], ultimaJugada: const {
                    'uid': 'yo',
                    'nombre': 'Gonzalo',
                    'carta': 2,
                    'resultado': 'Gonzalo mira la carta superior del mazo en '
                        'secreto. Gonzalo devuelve la carta al mazo en secreto.',
                  }),
                  [
                    jug('yo', 'Gonzalo', 0, mano: [10, 1], jugadas: [2, 5]),
                    jug('r1', 'Marta', 1, jugadas: [4, 3, 1], fichas: 2),
                  ],
                ),
                // La mesa sale 0,7 s y entonces llega la jugada, para ver la
                // animacion con la que se anuncia (carta jugada + revelada).
                Marco(
                  '7. Anuncio de jugada',
                  sala(turno: 'r2'),
                  mesa,
                  repo: RepoAnimado(
                    sala(turno: 'r2'),
                    sala(turno: 'r2', ultimaJugada: const {
                      'uid': 'r1',
                      'nombre': 'Marta',
                      'carta': 5,
                      'resultado': 'Marta obliga a Lucia a bajar su 10 Rey '
                          'del Trono sin efecto.',
                      'reveladas': [
                        {
                          'uid': 'r3',
                          'nombre': 'Lucia',
                          'carta': 10,
                          'motivo': 'forzada',
                        },
                      ],
                    }, historial: const [
                      {
                        'uid': 'r1',
                        'nombre': 'Marta',
                        'carta': 5,
                        'resultado': 'Marta obliga a Lucia a bajar su 10.',
                        'reveladas': [
                          {
                            'uid': 'r3',
                            'nombre': 'Lucia',
                            'carta': 10,
                            'motivo': 'forzada',
                          },
                        ],
                      },
                    ]),
                    mesa,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
