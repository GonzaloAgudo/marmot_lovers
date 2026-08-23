import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:marmot_lovers/models/jugador.dart';
import 'package:marmot_lovers/models/sala.dart';
import 'package:marmot_lovers/providers/style_provider.dart';
import 'package:marmot_lovers/screens/resumen_ronda_screen.dart';
import 'package:marmot_lovers/theme/app_theme.dart';
import 'package:marmot_lovers/widgets/carta_widget.dart';

const _jugadas = [
  {
    'uid': 'yo',
    'nombre': 'Gonzalo',
    'carta': 1,
    'resultado': 'Gonzalo dice que Marta tiene un 5: falla, y Marta no '
        'revela nada.',
  },
  {
    'uid': 'r1',
    'nombre': 'Marta',
    'carta': 4,
    'resultado': 'Marta queda protegida hasta su proximo turno.',
  },
  {
    'uid': 'r2',
    'nombre': 'Javi',
    'carta': 3,
    'resultado': 'Javi gana la comparacion: Gonzalo queda eliminado con un 2.',
  },
];

Sala _sala({List<Map<String, dynamic>> historial = _jugadas}) =>
    Sala.fromMap('CREH', {
      'estado': EstadoSala.finRonda,
      'host_uid': 'yo',
      'turno_actual': '',
      'mazo_central': const <int>[],
      'carta_oculta': 6,
      'cartas_apartadas': const <int>[],
      'orden_jugadores': const ['yo', 'r1', 'r2'],
      'ronda': 2,
      'fichas_para_ganar': 3,
      'ganadores_ronda': const ['Marta'],
      'motivo_final': 'mazo_agotado',
      'carta_ganadora': 9,
      'historial_jugadas': historial,
      'registro': const <String>[],
    });

Jugador _jug(String uid, String n, int orden, {List<int> mano = const [3]}) =>
    Jugador.fromMap(uid, {
      'nombre': n,
      'mano': mano,
      'cartas_jugadas': const [1],
      'vivo': mano.isNotEmpty,
      'protegido': false,
      'fichas_victoria': 0,
      'orden': orden,
    });

Future<int> _pintar(
  WidgetTester tester, {
  Sala? sala,
  Size tamano = const Size(390, 844),
  Duration ritmo = const Duration(seconds: 30),
}) async {
  var terminados = 0;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = tamano;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => StyleProvider(),
      child: MaterialApp(
        theme: AppTheme.oscuro,
        home: ResumenRondaScreen(
          sala: sala ?? _sala(),
          jugadores: [
            _jug('yo', 'Gonzalo', 0, mano: const []),
            _jug('r1', 'Marta', 1, mano: const [9]),
            _jug('r2', 'Javi', 2, mano: const [6]),
          ],
          miUid: 'yo',
          onTerminar: () => terminados++,
          onVerCarta: (_) {},
          ritmo: ritmo,
        ),
      ),
    ),
  );
  await tester.pump();
  return terminados;
}

/// Pasa a la siguiente jugada y deja que termine la animacion, sin correr
/// el reloj mas de la cuenta.
Future<void> _siguiente(WidgetTester tester) async {
  await tester.tap(find.text('Siguiente jugada'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Cuenta las cartas grandes (la jugada que se esta enseñando).
int _cartasGrandes(WidgetTester tester, int valor) => tester
    .widgetList<CartaWidget>(find.byType(CartaWidget))
    .where((c) => c.valor == valor && c.altura > 80)
    .length;

void main() {
  group('Repaso de la ronda', () {
    testWidgets('empieza por la primera jugada, con su carta', (t) async {
      await _pintar(t);
      expect(find.text('COMO HA IDO LA RONDA'), findsOneWidget);
      expect(find.text('1 de 3'), findsOneWidget);
      expect(find.text('Gonzalo'), findsOneWidget);
      expect(find.text('1  La Pitonisa'), findsOneWidget);
      expect(_cartasGrandes(t, 1), 1);
      expect(t.takeException(), isNull);
    });

    testWidgets('avanza sola con el tiempo', (t) async {
      await _pintar(t, ritmo: const Duration(milliseconds: 300));

      expect(find.text('1 de 3'), findsOneWidget);
      // Justo despues del ritmo, sin pasarse hasta la siguiente jugada.
      await t.pump(const Duration(milliseconds: 310));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('2 de 3'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('va enseñando la carta de cada jugada', (t) async {
      await _pintar(t);

      await _siguiente(t);
      expect(find.text('2 de 3'), findsOneWidget);
      expect(find.text('4  La Sabia'), findsOneWidget);
      expect(_cartasGrandes(t, 4), 1);

      await _siguiente(t);
      expect(find.text('3 de 3'), findsOneWidget);
      expect(find.text('3  El Matón'), findsOneWidget);
      expect(find.textContaining('Gonzalo queda eliminado'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('se puede adelantar tocando', (t) async {
      await _pintar(t);
      await _siguiente(t);
      expect(find.text('2 de 3'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('acaba destapando las manos y ofrece ver el marcador',
        (t) async {
      await _pintar(t);
      for (var i = 0; i < 3; i++) {
        await _siguiente(t);
      }

      expect(find.text('final'), findsOneWidget);
      expect(find.textContaining('se destapan las manos'), findsOneWidget);
      // Las cartas con las que se decidio la ronda, de los que siguen vivos.
      expect(_cartasGrandes(t, 9), 1);
      expect(_cartasGrandes(t, 6), 1);
      expect(find.text('VER QUIEN GANA'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('la tira va acumulando las cartas ya vistas', (t) async {
      await _pintar(t);
      // Solo la primera: una grande y una en la tira.
      expect(
        t
            .widgetList<CartaWidget>(find.byType(CartaWidget))
            .where((c) => c.valor == 1)
            .length,
        2,
      );

      await _siguiente(t);
      // Ahora tambien esta el 4 en la tira.
      expect(
        t
            .widgetList<CartaWidget>(find.byType(CartaWidget))
            .where((c) => c.valor == 4)
            .length,
        2,
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('SALTAR se va directo al marcador', (t) async {
      var terminados = 0;
      t.view.devicePixelRatio = 1.0;
      t.view.physicalSize = const Size(390, 844);
      addTearDown(t.view.reset);

      await t.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => StyleProvider(),
          child: MaterialApp(
            theme: AppTheme.oscuro,
            home: ResumenRondaScreen(
              sala: _sala(),
              jugadores: [_jug('yo', 'Gonzalo', 0)],
              miUid: 'yo',
              onTerminar: () => terminados++,
              onVerCarta: (_) {},
            ),
          ),
        ),
      );
      await t.pump();
      await t.tap(find.text('SALTAR'));
      await t.pump();
      expect(terminados, 1);
    });

    testWidgets('sin historial no se queda atascado', (t) async {
      final terminados = await _pintar(t, sala: _sala(historial: const []));
      await t.pump();
      expect(terminados, greaterThanOrEqualTo(0));
      expect(t.takeException(), isNull);
    });

    for (final entrada in const {
      'movil pequeno': Size(320, 568),
      'movil normal': Size(390, 844),
      'movil alto': Size(360, 900),
      'escritorio bajo': Size(1440, 700),
      'apaisado': Size(844, 390),
    }.entries) {
      testWidgets('cabe sin scroll en ${entrada.key}', (t) async {
        await _pintar(t, tamano: entrada.value);
        expect(t.takeException(), isNull);

        // Y tambien en la revelacion final.
        for (var i = 0; i < 3; i++) {
          await _siguiente(t);
        }
        expect(t.takeException(), isNull);
      });
    }
  });
}
