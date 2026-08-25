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
        // `enviado` lo pone el propio movil: Firestore descarta de un
        // orderBy los documentos a los que aun les falta el campo, y el
        // serverTimestamp tarda un viaje de ida y vuelta en aparecer.
        'enviado': DateTime.now().millisecondsSinceEpoch,
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
        .orderBy('enviado', descending: true)
        .limit(5)
        .snapshots()
        .map((snap) {
      final ahora = DateTime.now();
      final salida = <Reaccion>[];
      for (final doc in snap.docs) {
        final d = doc.data();

        // Las de hace rato no se reproducen: al entrar a mitad de partida
        // no queremos que suene todo lo de antes.
        final enviado = (d['enviado'] as num?)?.toInt();
        if (enviado == null) continue;
        final cuando = DateTime.fromMillisecondsSinceEpoch(enviado);
        if (ahora.difference(cuando).abs() > caducidad) continue;

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

  final List<Reaccion> _cola = [];
  bool _sonando = false;

  /// Encola la reacción y la reproduce en cuanto le toque.
  ///
  /// Sin cola, dos reacciones que llegan juntas usan el mismo reproductor y
  /// la segunda corta a la primera: solo se oiría una.
  Future<void> reproducir(Reaccion reaccion) async {
    _cola.add(reaccion);
    if (_sonando) return;
    _sonando = true;
    try {
      while (_cola.isNotEmpty) {
        final siguiente = _cola.removeAt(0);
        await _sonar(siguiente);
      }
    } finally {
      _sonando = false;
    }
  }

  Future<void> _sonar(Reaccion reaccion) async {
    try {
      _usado = true;
      await _altavoz.stop();
      await _altavoz.setVolume(1);
      await _altavoz.play(
        BytesSource(reaccion.datos, mimeType: _mime(reaccion.formato)),
      );
      // Esperar a que acabe para que la siguiente no la pise.
      await _altavoz.onPlayerComplete.first
          .timeout(duracion + const Duration(seconds: 3));
    } catch (_) {}
  }

  /// Prepara el altavoz con un sonido mudo.
  ///
  /// Los navegadores no dejan reproducir audio hasta que la persona toca la
  /// página: si no se hace esto, las reacciones se quedan bloqueadas y
  /// suenan todas de golpe al primer toque, normalmente al acabar la ronda.
  Future<void> desbloquear() async {
    if (_desbloqueado) return;
    _desbloqueado = true;
    try {
      _usado = true;
      await _altavoz.setVolume(0);
      await _altavoz.play(BytesSource(_silencio, mimeType: 'audio/wav'));
      await _altavoz.stop();
      await _altavoz.setVolume(1);
    } catch (_) {}
  }

  bool _desbloqueado = false;

  /// WAV minimo: cabecera de 44 bytes y unas muestras mudas.
  static final Uint8List _silencio = _wavMudo();

  static Uint8List _wavMudo() {
    const muestras = 64;
    final datos = BytesBuilder();
    void texto(String t) => datos.add(t.codeUnits);
    void u32(int v) => datos.add([
          v & 0xff,
          (v >> 8) & 0xff,
          (v >> 16) & 0xff,
          (v >> 24) & 0xff,
        ]);
    void u16(int v) => datos.add([v & 0xff, (v >> 8) & 0xff]);

    texto('RIFF');
    u32(36 + muestras);
    texto('WAVE');
    texto('fmt ');
    u32(16);
    u16(1); // PCM
    u16(1); // mono
    u32(8000);
    u32(8000);
    u16(1);
    u16(8); // 8 bits
    texto('data');
    u32(muestras);
    // En 8 bits sin signo, el silencio es 128.
    datos.add(List<int>.filled(muestras, 128));
    return datos.toBytes();
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
