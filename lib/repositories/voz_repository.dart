import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Una reacción de voz que ha llegado a la sala.
class Reaccion {
  final String id;
  final String uid;
  final String nombre;
  final Uint8List datos;
  final String formato;

  const Reaccion({
    required this.id,
    required this.uid,
    required this.nombre,
    required this.datos,
    required this.formato,
  });
}

/// Graba y reparte las reacciones de voz de quien acaba de caer eliminado.
///
/// El audio va en la propia base de datos (unos 10-15 KB por reacción, muy
/// por debajo del límite de 1 MB por documento de Firestore), así no hace
/// falta Storage ni plan de pago.
class VozRepository {
  /// Lo que dura el micro abierto al caer eliminado.
  static const Duration duracion = Duration(seconds: 5);

  /// Pasado este rato, una reacción ya no se reproduce: es de antes.
  static const Duration caducidad = Duration(seconds: 45);

  // Perezosos: así se puede crear el repositorio (y la pantalla de juego en
  // los tests) sin Firebase ni plugins de audio arrancados.
  late final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final AudioRecorder _grabadora = AudioRecorder();
  late final AudioPlayer _altavoz = AudioPlayer();

  CollectionReference<Map<String, dynamic>> _audios(String idSala) =>
      _db.collection('salas').doc(idSala).collection('audios');

  // ==========================================================
  // GRABAR
  // ==========================================================

  /// ¿Hay micrófono y nos dejan usarlo?
  Future<bool> hayPermiso() async {
    try {
      return await _grabadora.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Abre el micrófono [duracion] y manda lo grabado a la sala.
  ///
  /// Devuelve `true` si se ha enviado algo.
  Future<bool> grabarYEnviar({
    required String idSala,
    required String uid,
    required String nombre,
  }) async {
    String? ruta;
    try {
      _usado = true;
      if (!await hayPermiso()) return false;

      // Calidad de walkie-talkie: se entiende de sobra y ocupa poquísimo.
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 24000,
        sampleRate: 22050,
        numChannels: 1,
      );

      ruta = kIsWeb ? '' : '${(await getTemporaryDirectory()).path}/voz.m4a';
      await _grabadora.start(config, path: ruta);
      await Future<void>.delayed(duracion);
      final salida = await _grabadora.stop();
      if (salida == null) return false;

      final datos = await _leerBytes(salida);
      if (datos == null || datos.isEmpty) return false;

      await _audios(idSala).add({
        'uid': uid,
        'nombre': nombre,
        'formato': kIsWeb ? 'webm' : 'm4a',
        'datos': base64Encode(datos),
        'creado': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      // Que no se pueda grabar no debe estropear la partida.
      try {
        await _grabadora.cancel();
      } catch (_) {}
      return false;
    }
  }

  /// En movil `stop()` devuelve la ruta del fichero; en web, la URL de un blob.
  Future<Uint8List?> _leerBytes(String salida) async {
    try {
      if (kIsWeb) {
        final respuesta = await http.get(Uri.parse(salida));
        return respuesta.bodyBytes;
      }
      final fichero = File(salida);
      if (!fichero.existsSync()) return null;
      return await fichero.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  // ==========================================================
  // ESCUCHAR
  // ==========================================================

  /// Reacciones recién llegadas a la sala.
  ///
  /// Si no hay Firestore disponible devuelve un stream vacío: la voz es un
  /// extra y no debe impedir que se juegue.
  Stream<List<Reaccion>> escuchar(String idSala) {
    try {
      return _escuchar(idSala);
    } catch (_) {
      return const Stream.empty();
    }
  }

  Stream<List<Reaccion>> _escuchar(String idSala) {
    return _audios(idSala)
        .orderBy('creado', descending: true)
        .limit(5)
        .snapshots()
        .map((snap) {
      final ahora = DateTime.now();
      final salida = <Reaccion>[];
      for (final doc in snap.docs) {
        final d = doc.data();

        // Las de hace rato no se reproducen: al entrar a mitad de partida
        // no queremos que suene todo lo de antes.
        final creado = (d['creado'] as Timestamp?)?.toDate();
        if (creado == null) continue;
        if (ahora.difference(creado) > caducidad) continue;

        final base64 = d['datos'] as String?;
        if (base64 == null || base64.isEmpty) continue;

        try {
          salida.add(Reaccion(
            id: doc.id,
            uid: d['uid'] as String? ?? '',
            nombre: d['nombre'] as String? ?? '',
            datos: base64Decode(base64),
            formato: d['formato'] as String? ?? 'm4a',
          ));
        } catch (_) {
          // Un audio corrupto no debe tirar el resto.
        }
      }
      return salida.reversed.toList();
    }).handleError((_) => <Reaccion>[]);
  }

  Future<void> reproducir(Reaccion reaccion) async {
    try {
      _usado = true;
      await _altavoz.play(
        BytesSource(reaccion.datos, mimeType: _mime(reaccion.formato)),
      );
    } catch (_) {}
  }

  String _mime(String formato) =>
      formato == 'webm' ? 'audio/webm' : 'audio/mp4';

  /// Borra las reacciones de la sala (al empezar una ronda nueva).
  Future<void> limpiar(String idSala) async {
    try {
      final viejos = await _audios(idSala).get();
      if (viejos.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in viejos.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Solo hay que soltar lo que se llegó a usar.
  bool _usado = false;

  Future<void> soltar() async {
    if (!_usado) return;
    try {
      await _grabadora.dispose();
    } catch (_) {}
    try {
      await _altavoz.dispose();
    } catch (_) {}
  }
}
