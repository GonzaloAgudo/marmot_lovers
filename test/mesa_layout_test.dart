import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:marmot_lovers/models/jugador.dart';
import 'package:marmot_lovers/models/sala.dart';
import 'package:marmot_lovers/providers/style_provider.dart';
import 'package:marmot_lovers/repositories/game_repository.dart';
import 'package:marmot_lovers/screens/game_screen.dart';
import 'package:marmot_lovers/screens/login_screen.dart';
import 'package:marmot_lovers/widgets/boton_google.dart';
import 'package:marmot_lovers/theme/app_theme.dart';
import 'package:marmot_lovers/widgets/aviso_turno.dart';
import 'package:marmot_lovers/widgets/carta_widget.dart';

/// Repo de mentira con streams que se pueden ir alimentando a mano, para
/// probar que pasa cuando cambia el turno.
class _RepoVivo extends GameRepository {
  final salas = StreamController<Sala>.broadcast();
  final jugadores = StreamController<List<Jugador>>.broadcast();

  @override
  Stream<Sala> streamSala(String idSala) => salas.stream;

  @override
  Stream<List<Jugador>> streamJugadores(String idSala) => jugadores.stream;
}

/// Repo de mentira: devuelve una mesa fija sin tocar Firebase.
class _RepoFalso extends GameRepository {
  final Sala sala;
  final List<Jugador> jugadores;
  _RepoFalso(this.sala, this.jugadores);

  @override
  Stream<Sala> streamSala(String idSala) => Stream.value(sala);

  @override
  Stream<List<Jugador>> streamJugadores(String idSala) =>
      Stream.value(jugadores);
}

Sala _sala({
  int estado = EstadoSala.jugando,
  String turno = 'yo',
  List<int> mazo = const [5, 3, 1, 9, 2, 4, 1, 7],
  List<int> apartadas = const [],
  int? oculta = 6,
  List<String> ganadoresRonda = const [],
  List<String> ganadoresPartida = const [],
  Map<String, dynamic>? ultimaJugada,
  List<String> registro = const [
    'Ronda 2. Empieza Gonzalo. Hacen falta 2 fichas para ganar la partida.',
    'Marta juega 4 Escudo de Concha.',
    'Marta queda protegida hasta su proximo turno.',
    'Gonzalo juega 1 Cuenco de Cristal.',
  ],
}) {
  return Sala.fromMap('7K2P', {
    'estado': estado,
    'host_uid': 'yo',
    'turno_actual': turno,
    'mazo_central': mazo,
    'carta_oculta': oculta,
    'cartas_apartadas': apartadas,
    'orden_jugadores': const ['yo'],
    'ronda': 2,
    'fichas_para_ganar': 2,
    'ganadores_ronda': ganadoresRonda,
    'ganadores_partida': ganadoresPartida,
    'ultima_jugada': ultimaJugada,
    'registro': registro,
  });
}

Jugador _jug(
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

/// El destello solo pinta algo mientras esta activo.
bool _destelloPintando(WidgetTester tester) {
  final destello = find.descendant(
    of: find.byType(DestelloTurno),
    matching: find.byType(DecoratedBox),
  );
  return destello.evaluate().isNotEmpty;
}

/// La carta grande que hay dentro del panel de "ultima jugada".
Finder _cartaDeLaMesa(int valor) => find.descendant(
      of: find.byKey(const Key('ultimaJugada')),
      matching: find.byWidgetPredicate(
          (w) => w is CartaWidget && w.valor == valor),
    );

Future<void> _pintar(
  WidgetTester tester,
  Sala sala,
  List<Jugador> jugadores, {
  Size tamano = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = tamano;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => StyleProvider(),
      child: MaterialApp(
        theme: AppTheme.oscuro,
        home: GameScreen(
          idSala: '7K2P',
          miUid: 'yo',
          repositorio: _RepoFalso(sala, jugadores),
        ),
      ),
    ),
  );
  // Dos StreamBuilders anidados: hay que dejar que lleguen los dos.
  await tester.pumpAndSettle();
}

void main() {
  // Los desbordamientos de layout (RenderFlex overflow) hacen fallar el test,
  // asi que estas pruebas verifican que la mesa cabe en pantalla.
  group('La mesa cabe en pantalla', () {
    testWidgets('mi turno con 3 rivales', (tester) async {
      await _pintar(tester, _sala(), [
        _jug('yo', 'Gonzalo', 0, mano: [8, 2], jugadas: [1, 4], fichas: 1),
        _jug('r1', 'Marta', 1, jugadas: [4], protegido: true),
        _jug('r2', 'Javi', 2, jugadas: [1, 1, 3], fichas: 1),
        _jug('r3', 'Lucia', 3, jugadas: [10], vivo: false),
      ]);

      expect(find.text('TU TURNO'), findsOneWidget);
      expect(find.text('Gonzalo'), findsOneWidget);
      // La mano empieza tapada, asi que primero hay que mirarla.
      expect(find.text('MIRAR MIS CARTAS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('movil pequeno de 360x640', (tester) async {
      await _pintar(
        tester,
        _sala(),
        [
          _jug('yo', 'Gonzalo', 0, mano: [8, 2], jugadas: [1, 4]),
          _jug('r1', 'Marta', 1, jugadas: [4]),
        ],
        tamano: const Size(360, 640),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mesa llena de 6 jugadores', (tester) async {
      await _pintar(tester, _sala(), [
        _jug('yo', 'Gonzalo', 0, mano: [8, 2], jugadas: [1, 4]),
        _jug('r1', 'Marta', 1, jugadas: [4, 3]),
        _jug('r2', 'Javi', 2, jugadas: [1, 1, 3, 5]),
        _jug('r3', 'Lucia', 3, jugadas: [10], vivo: false),
        _jug('r4', 'Nombrelargisimo', 4, jugadas: [2]),
        _jug('r5', 'Ana', 5, jugadas: []),
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('partida de 2 con cartas fuera de juego', (tester) async {
      await _pintar(tester, _sala(apartadas: const [7, 10]), [
        _jug('yo', 'Gonzalo', 0, mano: [8, 2]),
        _jug('r1', 'Marta', 1),
      ]);
      expect(find.text('FUERA DE JUEGO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('turno de otro jugador', (tester) async {
      await _pintar(tester, _sala(turno: 'r1'), [
        _jug('yo', 'Gonzalo', 0, mano: [8]),
        _jug('r1', 'Marta', 1),
      ]);
      expect(find.text('Turno de Marta'), findsOneWidget);
      expect(find.text('Esperando a Marta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hay que robar carta', (tester) async {
      await _pintar(tester, _sala(), [
        _jug('yo', 'Gonzalo', 0, mano: [8]),
        _jug('r1', 'Marta', 1),
      ]);
      expect(find.text('ROBAR CARTA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('estoy eliminado', (tester) async {
      await _pintar(tester, _sala(turno: 'r1'), [
        _jug('yo', 'Gonzalo', 0, mano: [], jugadas: [3, 10], vivo: false),
        _jug('r1', 'Marta', 1),
      ]);
      expect(find.text('Estas fuera de esta ronda'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Las capas modales caben', () {
    testWidgets('aviso privado', (tester) async {
      await _pintar(tester, _sala(), [
        _jug('yo', 'Gonzalo', 0, mano: [8, 2], revelaciones: const [
          'Conejo Guerrero: tu 8 contra el 5 de Marta.',
        ]),
        _jug('r1', 'Marta', 1),
      ]);
      expect(find.text('SOLO LO VES TU'), findsOneWidget);
      expect(find.text('ENTENDIDO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('perro sepulturero', (tester) async {
      await _pintar(tester, _sala(), [
        _jug('yo', 'Gonzalo', 0,
            mano: [8],
            jugadas: [6],
            pendiente: {'tipo': 'enterrador', 'carta': 9}),
        _jug('r1', 'Marta', 1),
      ]);
      expect(find.text('QUEDARME LA APARTADA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cazarratones con el mazo lleno', (tester) async {
      await _pintar(
        tester,
        _sala(mazo: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 1, 2, 3, 4, 5]),
        [
          _jug('yo', 'Gonzalo', 0,
              mano: [8],
              jugadas: [2],
              pendiente: {'tipo': 'ratonera', 'carta': 10}),
          _jug('r1', 'Marta', 1),
        ],
      );
      expect(find.text('Arriba'), findsOneWidget);
      expect(find.text('Abajo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Pantallas de resultado', () {
    testWidgets('fin de ronda', (tester) async {
      await _pintar(
        tester,
        _sala(
            estado: EstadoSala.finRonda,
            turno: '',
            ganadoresRonda: const ['Marta']),
        [
          _jug('yo', 'Gonzalo', 0, mano: [], jugadas: [1, 3], vivo: false),
          _jug('r1', 'Marta', 1, mano: [9], jugadas: [4], fichas: 1),
        ],
      );
      expect(find.text('FIN DE LA RONDA'), findsOneWidget);
      expect(find.text('SIGUIENTE RONDA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fin de partida con empate a ganadores', (tester) async {
      await _pintar(
        tester,
        _sala(
          estado: EstadoSala.finPartida,
          turno: '',
          ganadoresRonda: const ['Marta', 'Javi'],
          ganadoresPartida: const ['Marta', 'Javi'],
        ),
        [
          _jug('yo', 'Gonzalo', 0, mano: [], jugadas: [1, 3], vivo: false),
          _jug('r1', 'Marta', 1, mano: [6], jugadas: [4], fichas: 2),
          _jug('r2', 'Javi', 2, mano: [6], jugadas: [4], fichas: 2),
        ],
      );
      expect(find.text('FIN DE LA PARTIDA'), findsOneWidget);
      expect(find.text('Marta y Javi'), findsOneWidget);
      expect(find.text('NUEVA PARTIDA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Interaccion', () {
    testWidgets('elegir carta muestra el boton de jugar', (tester) async {
      await _pintar(tester, _sala(), [
        _jug('yo', 'Gonzalo', 0, mano: [8, 2]),
        _jug('r1', 'Marta', 1),
      ]);

      // Primero hay que destapar la mano.
      await tester.tap(find.text('MIRAR MIS CARTAS'));
      await tester.pumpAndSettle();

      // Ahora si: toco el 8 (Forja de Hephesto) de mi mano.
      final miCarta = find.byWidgetPredicate(
          (w) => w is CartaWidget && w.valor == 8 && w.altura > 100);
      expect(miCarta, findsOneWidget);
      await tester.tap(miCarta);
      await tester.pumpAndSettle();

      expect(find.textContaining('JUGAR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Ultima jugada en la mesa', () {
    testWidgets('sin jugadas todavia', (tester) async {
      await _pintar(tester, _sala(), [
        _jug('yo', 'Gonzalo', 0, mano: [8, 2]),
        _jug('r1', 'Marta', 1),
      ]);
      expect(find.text('Todavia no ha jugado nadie'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ensena en grande la carta que acaba de jugarse',
        (tester) async {
      await _pintar(
        tester,
        _sala(ultimaJugada: {
          'uid': 'r1',
          'nombre': 'Marta',
          'carta': 4,
          'resultado': 'Marta queda protegida hasta su proximo turno.',
          'efecto': 'protegido',
        }),
        [
          _jug('yo', 'Gonzalo', 0, mano: [8, 2], jugadas: [1]),
          _jug('r1', 'Marta', 1, jugadas: [4], protegido: true),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ultimaJugada')), findsOneWidget);
      expect(find.text('4  La Sabia'), findsOneWidget);
      // Ya no se cuenta con un parrafo: se ve el sello del efecto.
      expect(find.text('Marta se protege'), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsWidgets);
      // La carta grande dentro del panel de la ultima jugada.
      expect(_cartaDeLaMesa(4), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con un resultado largo sigue cabiendo', (tester) async {
      await _pintar(
        tester,
        _sala(ultimaJugada: {
          'uid': 'r1',
          'nombre': 'Marta',
          'carta': 5,
          'resultado': 'Marta obliga a Gonzalo a bajar su 10 Rey del Trono '
              'sin efecto. Era el Rey del Trono: Gonzalo queda eliminado. '
              'Se ha agotado el mazo. Gana la ronda Marta.',
        }),
        [
          _jug('yo', 'Gonzalo', 0, mano: [8, 2], jugadas: [1, 3, 4]),
          _jug('r1', 'Marta', 1, jugadas: [5]),
        ],
        tamano: const Size(360, 640),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Ampliar cartas', () {
    testWidgets('tocar una carta de la mesa la abre en grande',
        (tester) async {
      await _pintar(
        tester,
        _sala(ultimaJugada: {
          'uid': 'r1',
          'nombre': 'Marta',
          'carta': 4,
          'resultado': '',
        }),
        [
          _jug('yo', 'Gonzalo', 0, mano: [8, 2]),
          _jug('r1', 'Marta', 1, jugadas: [4]),
        ],
      );

      await tester.tap(_cartaDeLaMesa(4));
      await tester.pumpAndSettle();

      // El dialogo muestra el nombre completo y el efecto.
      expect(find.text('4  ·  La Sabia del Valle de la Madriguera'),
          findsOneWidget);
      expect(find.text('Cerrar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('manten pulsada una carta de la mano para verla',
        (tester) async {
      await _pintar(tester, _sala(), [
        _jug('yo', 'Gonzalo', 0, mano: [8, 2]),
        _jug('r1', 'Marta', 1),
      ]);

      await tester.tap(find.text('MIRAR MIS CARTAS'));
      await tester.pumpAndSettle();

      await tester.longPress(find.byWidgetPredicate(
          (w) => w is CartaWidget && w.valor == 8 && w.altura > 100));
      await tester.pumpAndSettle();

      expect(find.text('8  ·  Forja de Hephesto'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // El tablero tiene que caber entero sin scroll en cualquier pantalla.
  group('Cabe sin scroll', () {
    const pantallas = <String, Size>{
      'movil pequeno': Size(320, 568),
      'movil normal': Size(390, 844),
      'movil alto': Size(360, 900),
      'movil ancho': Size(412, 915),
      'tablet': Size(768, 1024),
      'escritorio ancho': Size(1920, 870),
      'escritorio bajo': Size(1440, 700),
      'apaisado': Size(844, 390),
    };

    pantallas.forEach((nombre, tamano) {
      testWidgets(nombre, (tester) async {
        await _pintar(
          tester,
          _sala(ultimaJugada: {
            'uid': 'r1',
            'nombre': 'Marta',
            'carta': 5,
            'resultado': 'Marta obliga a Gonzalo a bajar su 10 Rey del Trono '
                'sin efecto. Era el Rey del Trono: Gonzalo queda eliminado.',
          }, apartadas: const [7, 10]),
          [
            _jug('yo', 'Gonzalo', 0,
                mano: [8, 2], jugadas: [1, 4, 3, 2], fichas: 1),
            _jug('r1', 'Marta', 1, jugadas: [4, 5, 1], protegido: true),
            _jug('r2', 'Javi', 2, jugadas: [1, 1, 3], fichas: 1),
            _jug('r3', 'Lucia', 3, jugadas: [10], vivo: false),
          ],
          tamano: tamano,
        );

        expect(tester.takeException(), isNull,
            reason: 'no debe desbordar en $nombre');

        // Nada de scroll: ningún scroll del tablero puede tener contenido
        // que sobresalga de su hueco.
        for (final estado in tester.stateList<ScrollableState>(
            find.byType(Scrollable, skipOffstage: false))) {
          final pos = estado.position;
          if (pos.axis != Axis.vertical) continue;
          expect(pos.maxScrollExtent, 0.0,
              reason: 'hay que hacer scroll vertical en $nombre');
        }
      });
    });
  });

  group('Mano tapada', () {
    // Solo las cartas que estan en mi mano, no las del mazo.
    Finder enLaMano({int? valor}) => find.descendant(
          of: find.byKey(const Key('mano')),
          matching: find.byWidgetPredicate(
              (w) => w is CartaWidget && w.valor == valor),
        );

    testWidgets('empieza tapada, con el dorso hacia arriba', (tester) async {
      await _pintar(tester, _sala(), [
        _jug('yo', 'Gonzalo', 0, mano: [8, 2]),
        _jug('r1', 'Marta', 1),
      ]);

      // Dos dorsos en la mano, y ninguna carta mia visible.
      expect(enLaMano(), findsNWidgets(2));
      expect(enLaMano(valor: 8), findsNothing);
      expect(enLaMano(valor: 2), findsNothing);
      expect(find.text('MIRAR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el boton MIRAR la destapa y TAPAR la vuelve a tapar',
        (tester) async {
      await _pintar(tester, _sala(), [
        _jug('yo', 'Gonzalo', 0, mano: [8, 2]),
        _jug('r1', 'Marta', 1),
      ]);

      await tester.tap(find.text('MIRAR'));
      await tester.pumpAndSettle();
      expect(enLaMano(valor: 8), findsOneWidget);
      expect(find.text('TAPAR'), findsOneWidget);

      await tester.tap(find.text('TAPAR'));
      await tester.pumpAndSettle();
      expect(enLaMano(), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tocar un dorso tambien la destapa', (tester) async {
      await _pintar(tester, _sala(), [
        _jug('yo', 'Gonzalo', 0, mano: [8, 2]),
        _jug('r1', 'Marta', 1),
      ]);

      await tester.tap(enLaMano().first);
      await tester.pumpAndSettle();
      expect(enLaMano(valor: 8), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapada deja mas sitio al tablero', (tester) async {
      Future<double> altoDeLaCartaDeLaMesa() async {
        final w = tester.widget<CartaWidget>(_cartaDeLaMesa(4));
        return w.altura;
      }

      await _pintar(
        tester,
        _sala(ultimaJugada: {
          'uid': 'r1',
          'nombre': 'Marta',
          'carta': 4,
          'resultado': '',
        }),
        [
          _jug('yo', 'Gonzalo', 0, mano: [8, 2]),
          _jug('r1', 'Marta', 1, jugadas: [4]),
        ],
      );

      final tapada = await altoDeLaCartaDeLaMesa();
      await tester.tap(find.text('MIRAR'));
      await tester.pumpAndSettle();
      final destapada = await altoDeLaCartaDeLaMesa();

      expect(tapada, greaterThan(destapada),
          reason: 'con la mano tapada el tablero debe crecer');
      expect(tester.takeException(), isNull);
    });
  });

  group('Aviso de turno', () {
    testWidgets('destella al pasar a ser mi turno', (tester) async {
      final repo = _RepoVivo();
      addTearDown(() {
        repo.salas.close();
        repo.jugadores.close();
      });

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => StyleProvider(),
          child: MaterialApp(
            theme: AppTheme.oscuro,
            home: GameScreen(
                idSala: '7K2P', miUid: 'yo', repositorio: repo),
          ),
        ),
      );

      final mesa = [
        _jug('yo', 'Gonzalo', 0, mano: [8]),
        _jug('r1', 'Marta', 1),
      ];

      // Empieza sin ser mi turno: nada de destello.
      // Ojo al orden: el StreamBuilder de jugadores no existe (ni escucha)
      // hasta que el de la sala tiene datos.
      repo.salas.add(_sala(turno: 'r1'));
      await tester.pump();
      repo.jugadores.add(mesa);
      await tester.pumpAndSettle();
      expect(_destelloPintando(tester), isFalse);

      // Pasa a ser mio: el destello arranca.
      repo.salas.add(_sala(turno: 'yo'));
      await tester.pump();
      repo.jugadores.add(mesa);
      await tester.pump();
      // El ticker no da su primer tic hasta el frame siguiente.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(_destelloPintando(tester), isTrue,
          reason: 'deberia destellar al tocarme el turno');

      // Y se apaga solo.
      await tester.pumpAndSettle();
      expect(_destelloPintando(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('se puede silenciar desde la barra', (tester) async {
      await _pintar(tester, _sala(), [
        _jug('yo', 'Gonzalo', 0, mano: [8, 2]),
        _jug('r1', 'Marta', 1),
      ]);

      expect(find.byIcon(Icons.notifications_active), findsOneWidget);
      await tester.tap(find.byIcon(Icons.notifications_active));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notifications_off), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Animacion de la jugada', () {
    testWidgets('una eliminacion se ve con su sello y ademas se puede leer',
        (tester) async {
      await _pintar(
        tester,
        _sala(ultimaJugada: {
          'uid': 'r1',
          'nombre': 'Marta',
          'carta': 3,
          'resultado': 'Marta gana la comparacion: Javi queda eliminado.',
          'objetivo_uid': 'r2',
          'objetivo_nombre': 'Javi',
          'efecto': 'eliminado',
        }),
        [
          _jug('yo', 'Gonzalo', 0, mano: [8, 2]),
          _jug('r1', 'Marta', 1, jugadas: [3]),
          _jug('r2', 'Javi', 2, jugadas: [1], vivo: false),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Javi fuera'), findsOneWidget);
      expect(find.byIcon(Icons.dangerous), findsWidgets);
      // El sello se ve de un vistazo, pero el texto tambien se puede leer.
      expect(find.textContaining('gana la comparacion'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cada efecto tiene su sello', (tester) async {
      // Los streams se crean una sola vez, asi que las jugadas se van
      // emitiendo por el stream, igual que en una partida de verdad.
      final repo = _RepoVivo();
      addTearDown(() {
        repo.salas.close();
        repo.jugadores.close();
      });

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => StyleProvider(),
          child: MaterialApp(
            theme: AppTheme.oscuro,
            home:
                GameScreen(idSala: '7K2P', miUid: 'yo', repositorio: repo),
          ),
        ),
      );

      final mesa = [
        _jug('yo', 'Gonzalo', 0, mano: [8, 2]),
        _jug('r1', 'Marta', 1),
      ];
      repo.salas.add(_sala());
      await tester.pump();
      repo.jugadores.add(mesa);
      await tester.pumpAndSettle();

      const casos = {
        4: ['protegido', 'Marta se protege'],
        8: ['intercambio', 'Cartas cambiadas'],
        1: ['fallo', 'Falla'],
        7: ['rebarajado', 'Se reparte de nuevo'],
        3: ['eliminado', 'Javi fuera'],
      };

      for (final caso in casos.entries) {
        repo.salas.add(_sala(ultimaJugada: {
          'uid': 'r1',
          'nombre': 'Marta',
          'carta': caso.key,
          'resultado': '',
          'objetivo_uid': 'r2',
          'objetivo_nombre': 'Javi',
          'efecto': caso.value[0],
        }));
        await tester.pumpAndSettle();

        expect(find.text(caso.value[1]), findsOneWidget,
            reason: 'falta el sello de ${caso.value[0]}');
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('Micro al caer eliminado', () {
    testWidgets('el interruptor esta en la barra y se puede apagar',
        (tester) async {
      await _pintar(tester, _sala(), [
        _jug('yo', 'Gonzalo', 0, mano: [8, 2]),
        _jug('r1', 'Marta', 1),
      ]);

      expect(find.byIcon(Icons.mic), findsOneWidget);
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic_off), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  _testsLogin();
}

/// La pantalla de login no usa el repositorio al dibujarse, asi que se puede
/// comprobar sin Firebase arrancado.
void _testsLogin() {
  group('Pantalla de acceso', () {
    Future<void> pintar(WidgetTester tester, Size tamano) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = tamano;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => StyleProvider(),
          child: MaterialApp(
            theme: AppTheme.oscuro,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra correo, contrasena y Google', (tester) async {
      await pintar(tester, const Size(390, 844));
      expect(find.text('ENTRAR'), findsOneWidget);
      expect(find.text('Crear una cuenta nueva'), findsOneWidget);
      expect(find.text('Continuar con Google'), findsOneWidget);
      expect(find.byType(BotonGoogle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cabe en un movil pequeno', (tester) async {
      await pintar(tester, const Size(360, 640));
      expect(find.byType(BotonGoogle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
