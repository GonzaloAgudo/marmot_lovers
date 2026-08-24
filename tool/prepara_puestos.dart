// Convierte los JPEG de las medallas de puesto en PNG con fondo
// transparente, recortados y a un tamaño razonable.
//
//   dart run tool/prepara_puestos.dart <carpeta_con_1.jpeg..6.jpeg>
//
// El fondo se quita con un relleno por inundación desde los bordes: así se
// borra solo el negro que rodea la medalla y no los negros de dentro (las
// líneas del dibujo, las sombras...).
import 'dart:collection';
import 'dart:io';

import 'package:image/image.dart' as img;

/// Por debajo de este brillo se considera fondo.
const int umbral = 60;

/// Alto final de cada medalla.
const int altoFinal = 256;

void main(List<String> args) {
  final origen = args.isNotEmpty ? args.first : 'iconos';
  final destino = Directory('assets/puestos')..createSync(recursive: true);

  for (var puesto = 1; puesto <= 6; puesto++) {
    final entrada = File('$origen/$puesto.jpeg');
    if (!entrada.existsSync()) {
      stderr.writeln('Falta ${entrada.path}');
      continue;
    }

    final original = img.decodeImage(entrada.readAsBytesSync());
    if (original == null) {
      stderr.writeln('No se pudo leer ${entrada.path}');
      continue;
    }

    final conAlfa = original.convert(numChannels: 4);
    _quitarFondo(conAlfa);
    final recortado = _recortarAlContenido(conAlfa);
    final final_ = img.copyResize(
      recortado,
      height: altoFinal,
      interpolation: img.Interpolation.cubic,
    );

    File('${destino.path}/$puesto.png')
        .writeAsBytesSync(img.encodePng(final_));
    stdout.writeln('OK puesto $puesto: '
        '${original.width}x${original.height} -> '
        '${final_.width}x${final_.height}');
  }
}

/// Borra el fondo oscuro que rodea la medalla, sin tocar el de dentro.
void _quitarFondo(img.Image im) {
  final visto = List<bool>.filled(im.width * im.height, false);
  final cola = Queue<int>();

  void encolar(int x, int y) {
    if (x < 0 || y < 0 || x >= im.width || y >= im.height) return;
    final i = y * im.width + x;
    if (visto[i]) return;
    final p = im.getPixel(x, y);
    // Brillo aproximado; si es claro, ya es dibujo y no fondo.
    final brillo = (p.r * 0.299 + p.g * 0.587 + p.b * 0.114).round();
    if (brillo > umbral) return;
    visto[i] = true;
    cola.add(i);
  }

  for (var x = 0; x < im.width; x++) {
    encolar(x, 0);
    encolar(x, im.height - 1);
  }
  for (var y = 0; y < im.height; y++) {
    encolar(0, y);
    encolar(im.width - 1, y);
  }

  while (cola.isNotEmpty) {
    final i = cola.removeFirst();
    final x = i % im.width;
    final y = i ~/ im.width;
    im.setPixelRgba(x, y, 0, 0, 0, 0);
    encolar(x + 1, y);
    encolar(x - 1, y);
    encolar(x, y + 1);
    encolar(x, y - 1);
  }
}

img.Image _recortarAlContenido(img.Image im) {
  var minX = im.width, minY = im.height, maxX = -1, maxY = -1;
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      if (im.getPixel(x, y).a <= 8) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) return im;
  return img.copyCrop(
    im,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}
