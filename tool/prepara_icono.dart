// Prepara los PNG que necesita flutter_launcher_icons a partir del JPEG
// original, y genera una vista previa de cómo quedará el icono en Android.
//
//   dart run tool/prepara_icono.dart <ruta_del_jpeg>
//
// Genera:
//   assets/icon/icono.png            -> icono cuadrado completo (para el
//                                       icono clásico y para la web)
//   assets/icon/icono_adaptativo.png -> primer plano del icono adaptativo,
//                                       recortado al contenido
//   build/preview_icono.png          -> cómo se verá con máscara redonda y
//                                       cuadrada, para revisarlo a ojo
//
// Nota: flutter_launcher_icons mete el primer plano con un `inset` del 16%
// en `mipmap-anydpi-v26/ic_launcher.xml`, así que aquí NO hay que dejar
// margen extra: el recorte va al contenido y del margen se encarga el inset.
import 'dart:io';

import 'package:image/image.dart' as img;

const int lado = 1024;

/// Zona con dibujo dentro del JPEG original, en tanto por uno.
/// El original trae un fondo difuminado alrededor de la insignia que no
/// interesa en el icono adaptativo.
const double centroX = 0.495;
const double centroY = 0.510;
const double ladoContenido = 0.88;

/// El mismo inset que escribe flutter_launcher_icons, para la vista previa.
const double insetLauncher = 0.16;

void main(List<String> args) {
  final origen = args.isNotEmpty ? args.first : 'icono.jpeg';

  final archivo = File(origen);
  if (!archivo.existsSync()) {
    stderr.writeln('No encuentro $origen');
    exit(1);
  }

  final original = img.decodeImage(archivo.readAsBytesSync());
  if (original == null) {
    stderr.writeln('No he podido decodificar $origen');
    exit(1);
  }
  stdout.writeln('Original: ${original.width}x${original.height}');

  // 1. Recorte cuadrado centrado, por si no viniera cuadrado.
  final corto =
      original.width < original.height ? original.width : original.height;
  final cuadrado = img.copyCrop(
    original,
    x: (original.width - corto) ~/ 2,
    y: (original.height - corto) ~/ 2,
    width: corto,
    height: corto,
  );

  // 2. Icono completo (clásico y web).
  final completo = img.copyResize(cuadrado,
      width: lado, height: lado, interpolation: img.Interpolation.cubic);
  Directory('assets/icon').createSync(recursive: true);
  File('assets/icon/icono.png').writeAsBytesSync(img.encodePng(completo));
  stdout.writeln('OK assets/icon/icono.png (${lado}x$lado)');

  // 3. Color de fondo: media del borde, que es el fondo difuminado.
  final fondo = _colorDelBorde(completo);
  final hex = '#${_hex(fondo.$1)}${_hex(fondo.$2)}${_hex(fondo.$3)}';

  // 4. Primer plano adaptativo: recorte ajustado al contenido.
  final ladoRecorte = (corto * ladoContenido).round();
  final recorte = img.copyCrop(
    cuadrado,
    x: (corto * centroX - ladoRecorte / 2).round().clamp(0, corto - 1),
    y: (corto * centroY - ladoRecorte / 2).round().clamp(0, corto - 1),
    width: ladoRecorte,
    height: ladoRecorte,
  );
  final adaptativo = img.copyResize(recorte,
      width: lado, height: lado, interpolation: img.Interpolation.cubic);
  File('assets/icon/icono_adaptativo.png')
      .writeAsBytesSync(img.encodePng(adaptativo));
  stdout.writeln('OK assets/icon/icono_adaptativo.png '
      '(recorte al ${(ladoContenido * 100).round()}%)');

  // 5. Vista previa: como lo compone Android.
  _previa(completo, adaptativo, fondo);
  stdout.writeln('OK build/preview_icono.png');

  stdout.writeln('');
  stdout.writeln('Color de fondo para el icono adaptativo: $hex');
}

/// Dibuja, de izquierda a derecha:
///  1. el icono clásico tal cual,
///  2. el adaptativo con máscara redonda,
///  3. el adaptativo con máscara de cuadrado redondeado,
///  4. el JPEG entero como primer plano con máscara redonda (la alternativa,
///     para poder comparar).
void _previa(img.Image completo, img.Image adaptativo, (int, int, int) fondo) {
  const celda = 256;
  const hueco = 16;
  final ancho = celda * 4 + hueco * 5;
  final alto = celda + hueco * 2;
  final lienzo = img.Image(width: ancho, height: alto, numChannels: 4);
  img.fill(lienzo, color: img.ColorRgb8(24, 24, 24));

  final clasico = img.copyResize(completo, width: celda, height: celda);
  img.compositeImage(lienzo, clasico, dstX: hueco, dstY: hueco);

  final compuesto = _componerAdaptativo(adaptativo, fondo, celda);
  img.compositeImage(lienzo, _mascaraCirculo(compuesto),
      dstX: hueco * 2 + celda, dstY: hueco);
  img.compositeImage(lienzo, _mascaraRedondeada(compuesto),
      dstX: hueco * 3 + celda * 2, dstY: hueco);

  final alternativa = _componerAdaptativo(completo, fondo, celda);
  img.compositeImage(lienzo, _mascaraCirculo(alternativa),
      dstX: hueco * 4 + celda * 3, dstY: hueco);

  Directory('build').createSync(recursive: true);
  File('build/preview_icono.png').writeAsBytesSync(img.encodePng(lienzo));
}

/// Fondo de color + primer plano metido con el inset del launcher.
img.Image _componerAdaptativo(
    img.Image primerPlano, (int, int, int) fondo, int celda) {
  final base = img.Image(width: celda, height: celda, numChannels: 4);
  img.fill(base, color: img.ColorRgb8(fondo.$1, fondo.$2, fondo.$3));
  final interior = (celda * (1 - insetLauncher * 2)).round();
  final reducido = img.copyResize(primerPlano,
      width: interior, height: interior, interpolation: img.Interpolation.cubic);
  final off = (celda - interior) ~/ 2;
  img.compositeImage(base, reducido, dstX: off, dstY: off);
  return base;
}

img.Image _mascaraCirculo(img.Image im) {
  final salida = img.Image(width: im.width, height: im.height, numChannels: 4);
  final r = im.width / 2;
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      final dx = x - r + .5, dy = y - r + .5;
      if (dx * dx + dy * dy <= r * r) salida.setPixel(x, y, im.getPixel(x, y));
    }
  }
  return salida;
}

img.Image _mascaraRedondeada(img.Image im) {
  final salida = img.Image(width: im.width, height: im.height, numChannels: 4);
  final radio = im.width * 0.28;
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      if (_dentroDeRedondeado(x + .5, y + .5, im.width, im.height, radio)) {
        salida.setPixel(x, y, im.getPixel(x, y));
      }
    }
  }
  return salida;
}

bool _dentroDeRedondeado(
    double x, double y, int ancho, int alto, double radio) {
  final cx = x < radio
      ? radio
      : (x > ancho - radio ? ancho - radio : x);
  final cy = y < radio ? radio : (y > alto - radio ? alto - radio : y);
  final dx = x - cx, dy = y - cy;
  return dx * dx + dy * dy <= radio * radio;
}

/// Media de los píxeles del marco exterior de la imagen.
(int, int, int) _colorDelBorde(img.Image im) {
  var r = 0, g = 0, b = 0, n = 0;
  final margen = (im.width * 0.03).round().clamp(1, im.width);
  for (var y = 0; y < im.height; y++) {
    final bordeV = y < margen || y >= im.height - margen;
    for (var x = 0; x < im.width; x++) {
      final bordeH = x < margen || x >= im.width - margen;
      if (!bordeV && !bordeH) continue;
      final p = im.getPixel(x, y);
      r += p.r.toInt();
      g += p.g.toInt();
      b += p.b.toInt();
      n++;
    }
  }
  if (n == 0) return (0, 0, 0);
  return (r ~/ n, g ~/ n, b ~/ n);
}

String _hex(int v) => v.clamp(0, 255).toRadixString(16).padLeft(2, '0');
