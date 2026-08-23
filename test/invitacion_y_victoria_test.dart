import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:marmot_lovers/enlaces.dart';
import 'package:marmot_lovers/models/jugador.dart';
import 'package:marmot_lovers/models/sala.dart';
import 'package:marmot_lovers/providers/style_provider.dart';
import 'package:marmot_lovers/screens/resultado_screen.dart';
import 'package:marmot_lovers/theme/app_theme.dart';
import 'package:marmot_lovers/widgets/confeti.dart';

Sala _sala({
  int estado = EstadoSala.finRonda,
  List<String> ganadoresRonda = const ['Marta'],
  List<String> ganadoresPartida = const [],
  String? motivo,
  int? cartaGanadora,
}) =>
    Sala.fromMap('CREH', {
      'estado': estado,
      'host_uid': 'yo',
      'turno_actual': '',
      'mazo_central': const <int>[],
      'carta_oculta': 6,
      'cartas_apartadas': const <int>[],
      'orden_jugadores': const ['yo', 'r1'],
      'ronda': 3,
      'fichas_para_ganar': 3,
      'ganadores_ronda': ganadoresRonda,
      'ganadores_partida': ganadoresPartida,
      'motivo_final': motivo,
      'carta_ganadora': cartaGanadora,
      'registro': const ['Se ha agotado el mazo.'],
    });

Jugador _jug(String uid, String n, int orden,
        {List<int> mano = const [3], int fichas = 0}) =>
    Jugador.fromMap(uid, {
      'nombre': n,
      'mano': mano,
      'cartas_jugadas': const [1],
      'vivo': mano.isNotEmpty,
      'protegido': false,
      'fichas_victoria': fichas,
      'orden': orden,
    });

Future<void> _pintar(WidgetTester tester, Sala sala,
    {Size tamano = const Size(390, 844)}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = tamano;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => StyleProvider(),
      child: MaterialApp(
        theme: AppTheme.oscuro,
        home: PantallaResultado(
          sala: sala,
          jugadores: [
            _jug('yo', 'Gonzalo', 0, mano: const [], fichas: 1),
            _jug('r1', 'Marta', 1, mano: const [9], fichas: 2),
          ],
          miUid: 'yo',
          procesando: false,
          onContinuar: () {},
          onVolverAlLobby: () {},
          onHistorial: () {},
          onVerCarta: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Enlace de invitacion', () {
    test('el enlace lleva el codigo de la sala', () {
      expect(Enlaces.invitacion('CREH'),
          'https://marmot-lovers.web.app/?sala=CREH');
      expect(Enlaces.mensajeInvitacion('CREH'), contains('CREH'));
      expect(Enlaces.mensajeInvitacion('CREH'), contains('marmot-lovers'));
    });

    test('la sala pendiente solo se coge una vez', () {
      Enlaces.ponerSalaPendiente('7K2P');
      expect(Enlaces.tomarSalaPendiente(), '7K2P');
      // La segunda vez ya no, para no volver a entrar solo.
      expect(Enlaces.tomarSalaPendiente(), isNull);
    });
  });

  group('Pantalla de victoria', () {
    testWidgets('cuenta que gano por ser el ultimo en pie', (tester) async {
      await _pintar(tester, _sala(motivo: 'ultimo_en_pie'));
      expect(find.text('FIN DE LA RONDA'), findsOneWidget);
      expect(find.text('Marta'), findsWidgets);
      expect(find.text('COMO HA GANADO'), findsOneWidget);
      expect(
          find.textContaining('Ultimo en pie'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cuenta que gano con la carta mas alta', (tester) async {
      await _pintar(
          tester, _sala(motivo: 'mazo_agotado', cartaGanadora: 9));
      expect(find.textContaining('Se agoto el mazo'), findsOneWidget);
      // El texto de 'como ha ganado' (en la fila de Marta tambien sale su carta).
      expect(find.textContaining('se quedo con un 9 La Venganza'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cuenta el caso especial del Capo contra el Rey',
        (tester) async {
      await _pintar(
          tester, _sala(motivo: 'mazo_agotado', cartaGanadora: 0));
      expect(find.textContaining('El Capo de la Colonia (0)'), findsOneWidget);
      expect(find.textContaining('Rey del Trono'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('al ganar la partida hay confeti y boton de nueva partida',
        (tester) async {
      await _pintar(
        tester,
        _sala(
          estado: EstadoSala.finPartida,
          ganadoresPartida: const ['Marta'],
          motivo: 'mazo_agotado',
          cartaGanadora: 9,
        ),
      );
      expect(find.text('FIN DE LA PARTIDA'), findsOneWidget);
      expect(find.byType(Confeti), findsOneWidget);
      expect(find.text('NUEVA PARTIDA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('al acabar solo una ronda no hay confeti', (tester) async {
      await _pintar(tester, _sala(motivo: 'mazo_agotado', cartaGanadora: 9));
      expect(find.byType(Confeti), findsNothing);
      expect(find.text('SIGUIENTE RONDA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cabe en un movil pequeno', (tester) async {
      await _pintar(
        tester,
        _sala(
          estado: EstadoSala.finPartida,
          ganadoresPartida: const ['Marta'],
          motivo: 'mazo_agotado',
          cartaGanadora: 9,
        ),
        tamano: const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
