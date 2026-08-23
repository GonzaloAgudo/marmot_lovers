import 'package:flutter_test/flutter_test.dart';
import 'package:marmot_lovers/models/fin_ronda.dart';

class _Mano implements ManoFinal {
  final String nombre;
  @override
  final int carta;
  @override
  final int mayorJugada;
  _Mano(this.nombre, this.carta, {this.mayorJugada = -1});
  @override
  String toString() => nombre;
}

void main() {
  List<String> nombres(List<_Mano> l) => l.map((m) => m.nombre).toList();

  group('Fin de ronda', () {
    test('gana la carta mas alta', () {
      final r = ganadoresDeRonda([
        _Mano('ana', 3),
        _Mano('bea', 8),
        _Mano('caz', 5),
      ]);
      expect(nombres(r), ['bea']);
    });

    test('el Roboaspirador (0) le gana al Gato Rey (10)', () {
      final r = ganadoresDeRonda([
        _Mano('ana', 10),
        _Mano('bea', 0),
      ]);
      expect(nombres(r), ['bea']);
    });

    test('el Roboaspirador (0) pierde contra cualquier otra carta', () {
      final r = ganadoresDeRonda([
        _Mano('ana', 9),
        _Mano('bea', 0),
      ]);
      expect(nombres(r), ['ana']);
    });

    test('el 0 no gana si el 10 no esta en juego', () {
      final r = ganadoresDeRonda([
        _Mano('ana', 1),
        _Mano('bea', 0),
      ]);
      expect(nombres(r), ['ana']);
    });

    test('empate: desempata la carta mas alta ya jugada', () {
      final r = ganadoresDeRonda([
        _Mano('ana', 5, mayorJugada: 3),
        _Mano('bea', 5, mayorJugada: 7),
        _Mano('caz', 2, mayorJugada: 9),
      ]);
      expect(nombres(r), ['bea']);
    });

    test('empate total: ganan los dos y cada uno se lleva ficha', () {
      final r = ganadoresDeRonda([
        _Mano('ana', 6, mayorJugada: 4),
        _Mano('bea', 6, mayorJugada: 4),
      ]);
      expect(nombres(r), ['ana', 'bea']);
    });

    test('un solo superviviente gana', () {
      expect(nombres(ganadoresDeRonda([_Mano('ana', 1)])), ['ana']);
    });

    test('sin supervivientes no devuelve a nadie', () {
      expect(ganadoresDeRonda(<_Mano>[]), isEmpty);
    });
  });
}
