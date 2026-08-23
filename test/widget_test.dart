import 'package:flutter_test/flutter_test.dart';
import 'package:marmot_lovers/models/carta.dart';

void main() {
  group('Mazo', () {
    test('tiene exactamente 21 cartas', () {
      expect(Cartas.mazoCompleto().length, 21);
    });

    test('la composicion coincide con las reglas', () {
      final mazo = Cartas.mazoCompleto();
      final esperado = {
        0: 1, 1: 5, 2: 3, 3: 3, 4: 2, 5: 2,
        6: 1, 7: 1, 8: 1, 9: 1, 10: 1,
      };
      for (final entrada in esperado.entries) {
        expect(
          mazo.where((c) => c == entrada.key).length,
          entrada.value,
          reason: 'deberia haber ${entrada.value} cartas de valor ${entrada.key}',
        );
      }
    });

    test('todas las cartas tienen nombre y efecto', () {
      for (final c in Cartas.catalogo) {
        expect(c.nombre.isNotEmpty, isTrue);
        expect(c.efecto.isNotEmpty, isTrue);
      }
    });

    test('solo 1, 3, 5 y 8 necesitan objetivo', () {
      for (var v = 0; v <= 10; v++) {
        expect(Cartas.requiereObjetivo(v), {1, 3, 5, 8}.contains(v),
            reason: 'carta $v');
      }
    });

    test('solo el Cuenco de Cristal pide adivinar', () {
      expect(Cartas.requiereAdivinanza(1), isTrue);
      expect(Cartas.requiereAdivinanza(3), isFalse);
    });
  });
}
