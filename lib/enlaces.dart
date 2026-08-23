import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Enlaces de invitación a una sala.
///
/// Al abrir `https://marmot-lovers.web.app/?sala=CREH` la web entra sola en
/// esa sala. En el móvil el enlace abre la versión web, que funciona igual.
class Enlaces {
  Enlaces._();

  static const String web = 'https://marmot-lovers.web.app';

  static String invitacion(String idSala) => '$web/?sala=$idSala';

  static String mensajeInvitacion(String idSala) =>
      'Te invito a una partida de Marmot Lovers.\n'
      'Entra aqui: ${invitacion(idSala)}\n'
      '(o mete el codigo $idSala en la app)';

  /// Sala que venía en la URL al abrir la app, pendiente de usar.
  static String? _pendiente = _leerDeLaUrl();

  static String? _leerDeLaUrl() {
    if (!kIsWeb) return null;
    final valor = Uri.base.queryParameters['sala']?.trim().toUpperCase();
    if (valor == null || valor.isEmpty) return null;
    // Los códigos son de 4 caracteres alfanuméricos.
    if (!RegExp(r'^[A-Z0-9]{4}$').hasMatch(valor)) return null;
    return valor;
  }

  /// Devuelve la sala del enlace **una sola vez**: así no se vuelve a entrar
  /// sola cada vez que se dibuja la pantalla de inicio.
  static String? tomarSalaPendiente() {
    final valor = _pendiente;
    _pendiente = null;
    return valor;
  }

  /// Solo para pruebas.
  static void ponerSalaPendiente(String? codigo) => _pendiente = codigo;

  /// Extrae el código de sala de una URL de invitación, si lo lleva.
  static String? codigoDe(Uri? url) {
    if (url == null) return null;
    final valor = url.queryParameters['sala']?.trim().toUpperCase();
    if (valor == null || !RegExp(r'^[A-Z0-9]{4}$').hasMatch(valor)) return null;
    return valor;
  }

  /// Escucha los enlaces que abren la app en Android/iOS.
  ///
  /// En web no hace falta: el código ya viene en [Uri.base]. En móvil, en
  /// cambio, el enlace llega como un intent, tanto si la app estaba cerrada
  /// (enlace inicial) como si ya estaba abierta (stream).
  static Future<void> escucharEnlacesNativos(
      void Function(String codigo) alRecibir) async {
    if (kIsWeb) return;
    try {
      final enlaces = AppLinks();

      final inicial = codigoDe(await enlaces.getInitialLink());
      if (inicial != null) {
        _pendiente = inicial;
        alRecibir(inicial);
      }

      enlaces.uriLinkStream.listen((url) {
        final codigo = codigoDe(url);
        if (codigo != null) alRecibir(codigo);
      }, onError: (_) {});
    } catch (_) {
      // Si la plataforma no lo soporta, se entra por codigo y ya esta.
    }
  }
}
