import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:marmot_lovers/models/jugador.dart';
import 'package:marmot_lovers/models/sala.dart';
import 'package:marmot_lovers/providers/style_provider.dart';
import 'package:marmot_lovers/repositories/game_repository.dart';
import 'package:marmot_lovers/screens/game_screen.dart';
import 'package:marmot_lovers/theme/app_theme.dart';
import 'package:marmot_lovers/widgets/anuncio_jugada.dart';
import 'package:marmot_lovers/widgets/carta_widget.dart';

/// Repo de mentira con streams que se alimentan a mano, para simular que
/// van llegando jugadas de Firestore.
class _RepoVivo extends GameRepository {
  final salas = StreamController<Sala>.broadcast();
  final jugadores = StreamController<List<Jugador>>.broadcast();

  @override
  Stream<Sala> streamSala(String idSala) => salas.stream;

  @override
  Stream<List<Jugador>> streamJugadores(String idSala) => jugadores.stream;
}

/// Emite un estado nuevo de la partida. Ojo al orden: el StreamBuilder de
/// jugadores no escucha hasta que el de la sala tiene datos, así que la
/// sala siempre va primero y con un frame entre medias.
Future<void> _emitir(
  WidgetTester t,
  _RepoVivo repo,
  Sala sala,
  List<Jugador> lista,
) async {
  repo.salas.add(sala);
  await t.pump();
  repo.jugadores.add(lista);
  await t.pump();
}

const _jugadaMarta = {
  'uid': 'r1',
  'nombre': 'Marta',
  'carta': 5,
  'resultado': 'Marta obliga a Javi a bajar su 3 El Matón sin efecto.',
  'reveladas': [
    {'uid': 'r2', 'nombre': 'Javi', 'carta': 3, 'motivo': 'forzada'},
  ],
};

const _jugadaJavi = {
  'uid': 'r2',
  'nombre': 'Javi',
  'carta': 4,
  'resultado': 'Javi queda protegido hasta su proximo turno.',
};

Sala _sala({
  String turno = 'r2',
  int ronda = 2,
  List<Map<String, dynamic>> historial = const [],
  Map<String, dynamic>? ultimaJugada,
}) =>
    Sala.fromMap('7K2P', {
      'estado': EstadoSala.jugando,
      'host_uid': 'yo',
      'turno_actual': turno,
      'mazo_central': const [5, 3, 1, 9, 2, 4, 1, 7],
      'carta_oculta': 6,
      'cartas_apartadas': const [],
      'orden_jugadores': const ['yo', 'r1', 'r2'],
      'ronda': ronda,
      'fichas_para_ganar': 3,
      'ganadores_ronda': const [],
      'ganadores_partida': const [],
      'ultima_jugada': ultimaJugada,
      'historial_jugadas': historial,
      'registro': const ['Ronda 2. Empieza Marta.'],
    });

List<Jugador> _jugadores({List<int> miMano = const [3]}) => [
      _jug('yo', 'Gonzalo', 0, mano: miMano),
      _jug('r1', 'Marta', 1, jugadas: const [4]),
      _jug('r2', 'Javi', 2, jugadas: const [1]),
    ];

Jugador _jug(
  String uid,
  String nombre,
  int orden, {
  List<int> mano = const [],
  List<int> jugadas = const [],
}) =>
    Jugador.fromMap(uid, {
      'nombre': nombre,
      'mano': mano,
      'cartas_jugadas': jugadas,
      'vivo': true,
      'protegido': false,
      'fichas_victoria': 0,
      'orden': orden,
      'revelaciones': const [],
      'accion_pendiente': null,
    });

Future<void> _pantalla(
  WidgetTester t,
  _RepoVivo repo, {
  Size tamano = const Size(390, 844),
}) async {
  t.view.devicePixelRatio = 1.0;
  t.view.physicalSize = tamano;
  addTearDown(t.view.reset);

  await t.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => StyleProvider(),
      child: MaterialApp(
        theme: AppTheme.oscuro,
        home: GameScreen(idSala: '7K2P', miUid: 'yo', repositorio: repo),
      ),
    ),
  );
  // Deja que el StreamBuilder de la sala se suscriba antes de emitir nada.
  await t.pump();
}

/// Deja pasar el volteo de la carta para ver ya la cara.
Future<void> _volteo(WidgetTester t) =>
    t.pump(const Duration(milliseconds: 700));

/// Cartas boca arriba y grandes (las del anuncio, no las de la mesa).
int _carasGrandes(WidgetTester t, int valor) => t
    .widgetList<CartaWidget>(find.descendant(
      of: find.byType(AnuncioJugada),
      matching: find.byType(CartaWidget),
    ))
    .where((c) => c.valor == valor && c.altura > 100)
    .length;

void main() {
  group('Serializado', () {
    test('UltimaJugada conserva las cartas reveladas al pasar por Firestore',
        () {
      const jugada = UltimaJugada(
        uid: 'r1',
        nombre: 'Marta',
        carta: 5,
        resultado: 'ok',
        reveladas: [
          CartaRevelada(
              uid: 'r2', nombre: 'Javi', carta: 3, motivo: 'forzada'),
        ],
      );
      final leida = UltimaJugada.fromMap(jugada.toMap())!;
      expect(leida.reveladas, hasLength(1));
      expect(leida.reveladas.first.uid, 'r2');
      expect(leida.reveladas.first.nombre, 'Javi');
      expect(leida.reveladas.first.carta, 3);
      expect(leida.reveladas.first.motivo, 'forzada');
    });

    test('Una jugada vieja sin el campo se lee sin reveladas', () {
      final leida = UltimaJugada.fromMap({
        'uid': 'r1',
        'nombre': 'Marta',
        'carta': 5,
        'resultado': '',
      })!;
      expect(leida.reveladas, isEmpty);
    });
  });

  group('Anuncio de la jugada', () {
    testWidgets('no anuncia lo que ya estaba al abrir la pantalla', (t) async {
      final repo = _RepoVivo();
      await _pantalla(t, repo);

      await _emitir(
        t,
        repo,
        _sala(historial: const [_jugadaMarta], ultimaJugada: _jugadaMarta),
        _jugadores(),
      );
      await t.pump(const Duration(milliseconds: 2500));
      expect(find.byType(AnuncioJugada), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('anuncia la jugada nueva con su carta y se salta tocando',
        (t) async {
      final repo = _RepoVivo();
      await _pantalla(t, repo);

      await _emitir(t, repo, _sala(), _jugadores());
      expect(find.byType(AnuncioJugada), findsNothing);

      await _emitir(
        t,
        repo,
        _sala(historial: const [_jugadaMarta], ultimaJugada: _jugadaMarta),
        _jugadores(),
      );
      await _volteo(t);

      expect(find.byType(AnuncioJugada), findsOneWidget);
      final anuncio = find.byType(AnuncioJugada);
      expect(find.descendant(of: anuncio, matching: find.text('Marta juega')),
          findsOneWidget);
      expect(
        find.descendant(
            of: anuncio, matching: find.text('5  Rey de las Mareas')),
        findsOneWidget,
      );
      expect(_carasGrandes(t, 5), 1);

      await t.tap(find.byType(AnuncioJugada));
      await t.pump();
      expect(find.byType(AnuncioJugada), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('enseña la carta revelada y se cierra sola', (t) async {
      final repo = _RepoVivo();
      await _pantalla(t, repo);

      await _emitir(t, repo, _sala(), _jugadores());
      await _emitir(
        t,
        repo,
        _sala(historial: const [_jugadaMarta], ultimaJugada: _jugadaMarta),
        _jugadores(),
      );
      await _volteo(t);

      // Paso 1: la carta forzada de Javi, volteándose desde el dorso.
      await t.pump(const Duration(milliseconds: 1900));
      await _volteo(t);
      expect(find.byType(AnuncioJugada), findsOneWidget);
      expect(find.text('BAJA SU CARTA SIN EFECTO'), findsOneWidget);
      expect(find.text('Javi revela'), findsOneWidget);
      expect(_carasGrandes(t, 3), 1);

      // Paso 2: se cierra sola al acabarse la secuencia.
      await t.pump(const Duration(milliseconds: 1900));
      expect(find.byType(AnuncioJugada), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('si llegan varias jugadas seguidas, las anuncia por orden',
        (t) async {
      final repo = _RepoVivo();
      await _pantalla(t, repo);

      await _emitir(t, repo, _sala(), _jugadores());
      await _emitir(
        t,
        repo,
        _sala(
          historial: const [_jugadaMarta, _jugadaJavi],
          ultimaJugada: _jugadaJavi,
        ),
        _jugadores(),
      );
      await _volteo(t);

      // Primero la de Marta.
      expect(find.text('Marta juega'), findsOneWidget);
      await t.tap(find.byType(AnuncioJugada));
      await t.pump();
      await _volteo(t);

      // Después la de Javi.
      expect(find.byType(AnuncioJugada), findsOneWidget);
      expect(find.text('Javi juega'), findsOneWidget);
      await t.tap(find.byType(AnuncioJugada));
      await t.pump();
      expect(find.byType(AnuncioJugada), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('una ronda nueva empieza sin anuncios pendientes', (t) async {
      final repo = _RepoVivo();
      await _pantalla(t, repo);

      await _emitir(t, repo, _sala(), _jugadores());
      await _emitir(
        t,
        repo,
        _sala(historial: const [_jugadaMarta], ultimaJugada: _jugadaMarta),
        _jugadores(),
      );
      await t.tap(find.byType(AnuncioJugada));
      await t.pump();

      // Nueva ronda: el historial se reinicia y no salta nada viejo.
      await _emitir(t, repo, _sala(ronda: 3, turno: 'yo'), _jugadores());
      await t.pump(const Duration(milliseconds: 2500));
      expect(find.byType(AnuncioJugada), findsNothing);

      // Y la primera jugada de la ronda nueva sí se anuncia.
      await _emitir(
        t,
        repo,
        _sala(
          ronda: 3,
          historial: const [_jugadaJavi],
          ultimaJugada: _jugadaJavi,
        ),
        _jugadores(),
      );
      expect(find.byType(AnuncioJugada), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    for (final entrada in const {
      'movil pequeno': Size(320, 568),
      'apaisado': Size(844, 390),
      'escritorio bajo': Size(1440, 700),
    }.entries) {
      testWidgets('cabe sin desbordarse en ${entrada.key}', (t) async {
        final repo = _RepoVivo();
        await _pantalla(t, repo, tamano: entrada.value);

        await _emitir(t, repo, _sala(), _jugadores());
        await _emitir(
          t,
          repo,
          _sala(historial: const [_jugadaMarta], ultimaJugada: _jugadaMarta),
          _jugadores(),
        );
        await _volteo(t);
        expect(find.byType(AnuncioJugada), findsOneWidget);

        // También con la carta revelada en pantalla.
        await t.pump(const Duration(milliseconds: 1900));
        await _volteo(t);
        expect(t.takeException(), isNull);
      });
    }
  });
}
