import 'package:flutter/material.dart';

/// Controla el mazo de diseno que se esta usando.
///
/// Para anadir un estilo nuevo:
///  1. crea la carpeta `assets/cards/<estilo>/` con `carta_0.png` ... `carta_10.png`
///     (y opcionalmente `dorso.png`),
///  2. anade la carpeta a la seccion `assets:` del `pubspec.yaml`,
///  3. anade el nombre a [estilosDisponibles].
///
/// Si falta algun PNG, [CartaWidget] pinta una carta de respaldo en su lugar,
/// asi que la app sigue funcionando.
class StyleProvider extends ChangeNotifier {
  String _estiloActual = 'clasico';

  final List<String> estilosDisponibles = ['clasico'];

  String get estiloActual => _estiloActual;

  void cambiarEstilo(String nuevoEstilo) {
    if (estilosDisponibles.contains(nuevoEstilo) &&
        nuevoEstilo != _estiloActual) {
      _estiloActual = nuevoEstilo;
      notifyListeners();
    }
  }

  /// Ruta del PNG de una carta. `-1` devuelve el dorso.
  String rutaCarta(int idCarta) {
    if (idCarta < 0) return 'assets/cards/$_estiloActual/dorso.png';
    return 'assets/cards/$_estiloActual/carta_$idCarta.png';
  }
}
