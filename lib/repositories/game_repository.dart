import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/carta.dart';
import '../models/fin_ronda.dart';
import '../models/jugador.dart';
import '../models/sala.dart';

/// Estado mutable de un jugador mientras se resuelve una jugada.
class _EstadoJugador implements ManoFinal {
  final String uid;
  final String nombre;
  final int orden;
  List<int> mano;
  List<int> jugadas;
  bool vivo;
  bool protegido;
  int fichas;
  List<String> revelaciones;
  AccionPendiente? pendiente;

  _EstadoJugador.desde(Jugador j)
      : uid = j.uid,
        nombre = j.nombre,
        orden = j.orden,
        mano = List<int>.from(j.mano),
        jugadas = List<int>.from(j.cartasJugadas),
        vivo = j.vivo,
        protegido = j.protegido,
        fichas = j.fichasVictoria,
        revelaciones = List<String>.from(j.revelaciones),
        pendiente = j.accionPendiente;

  @override
  int get carta => mano.isEmpty ? -1 : mano.first;

  @override
  int get mayorJugada =>
      jugadas.isEmpty ? -1 : jugadas.reduce((a, b) => a > b ? a : b);

  /// Elimina al jugador: su carta de mano queda boca arriba delante de él.
  void eliminar() {
    vivo = false;
    jugadas.addAll(mano);
    mano = [];
    protegido = false;
  }

  Map<String, dynamic> aFirestore() => {
        'nombre': nombre,
        'mano': mano,
        'cartas_jugadas': jugadas,
        'vivo': vivo,
        'protegido': protegido,
        'fichas_victoria': fichas,
        'orden': orden,
        'revelaciones': revelaciones,
        'accion_pendiente': pendiente?.toMap(),
      };
}

class GameRepository {
  GameRepository();

  static const int minJugadores = 2;
  static const int maxJugadores = 6;
  static const int _maxRegistro = 40;

  // Perezoso: asi se puede crear el repo (o una subclase de pruebas)
  // sin necesidad de tener Firebase inicializado.
  late final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Random _rnd = Random();

  DocumentReference<Map<String, dynamic>> _salaRef(String id) =>
      _db.collection('salas').doc(id);

  CollectionReference<Map<String, dynamic>> _jugadoresRef(String id) =>
      _salaRef(id).collection('jugadores');

  // ==========================================================
  // STREAMS
  // ==========================================================

  Stream<Sala> streamSala(String idSala) => _salaRef(idSala)
      .snapshots()
      .map((snap) => Sala.fromMap(snap.id, snap.data()));

  Stream<List<Jugador>> streamJugadores(String idSala) =>
      _jugadoresRef(idSala).orderBy('orden').snapshots().map(
            (snap) => snap.docs
                .map((doc) => Jugador.fromMap(doc.id, doc.data()))
                .toList(),
          );

  // ==========================================================
  // SALAS
  // ==========================================================

  /// Crea una sala con un codigo de 4 caracteres que no este en uso.
  Future<String?> crearSala(String uid, String nombreJugador) async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    for (var intento = 0; intento < 8; intento++) {
      final idSala = String.fromCharCodes(
        Iterable.generate(
            4, (_) => chars.codeUnitAt(_rnd.nextInt(chars.length))),
      );
      final ref = _salaRef(idSala);
      if ((await ref.get()).exists) continue;

      await ref.set({
        'estado': EstadoSala.lobby,
        'host_uid': uid,
        'turno_actual': '',
        'mazo_central': <int>[],
        'carta_oculta': null,
        'cartas_apartadas': <int>[],
        'orden_jugadores': <String>[uid],
        'ronda': 0,
        'fichas_para_ganar': 3,
        'ganadores_ronda': <String>[],
        'ganador_ronda_uid': null,
        'ganadores_partida': <String>[],
        'registro': <String>[],
        'creada': FieldValue.serverTimestamp(),
        'actualizada': FieldValue.serverTimestamp(),
      });

      await _jugadoresRef(idSala).doc(uid).set({
        'nombre': nombreJugador,
        'mano': <int>[],
        'cartas_jugadas': <int>[],
        'vivo': true,
        'protegido': false,
        'fichas_victoria': 0,
        'orden': 0,
        'revelaciones': <String>[],
        'accion_pendiente': null,
      });

      return idSala;
    }
    return null;
  }

  /// Se une a una sala. Devuelve `null` si va bien, o el mensaje de error.
  Future<String?> unirseASala(
      String idSala, String uid, String nombreJugador) async {
    final id = idSala.trim().toUpperCase();
    if (id.isEmpty) return 'Escribe el codigo de la sala';

    try {
      return await _db.runTransaction<String?>((tx) async {
        final salaRef = _salaRef(id);
        final salaSnap = await tx.get(salaRef);
        if (!salaSnap.exists) return 'Esa sala no existe';

        final sala = Sala.fromMap(id, salaSnap.data());
        final orden = List<String>.from(sala.ordenJugadores);
        final yaEstaba = orden.contains(uid);

        if (!yaEstaba) {
          if (sala.estado != EstadoSala.lobby) {
            return 'La partida ya ha empezado';
          }
          if (orden.length >= maxJugadores) {
            return 'La sala esta llena ($maxJugadores jugadores)';
          }
          orden.add(uid);
        }

        tx.set(
          _jugadoresRef(id).doc(uid),
          {
            'nombre': nombreJugador,
            'orden': orden.indexOf(uid),
            if (!yaEstaba) ...{
              'mano': <int>[],
              'cartas_jugadas': <int>[],
              'vivo': true,
              'protegido': false,
              'fichas_victoria': 0,
              'revelaciones': <String>[],
              'accion_pendiente': null,
            },
          },
          SetOptions(merge: true),
        );

        tx.update(salaRef, {
          'orden_jugadores': orden,
          'actualizada': FieldValue.serverTimestamp(),
        });
        return null;
      });
    } catch (e) {
      return 'No se pudo entrar en la sala: $e';
    }
  }

  /// Salir de la sala mientras se esta en el lobby.
  Future<void> abandonarSala(String idSala, String uid) async {
    try {
      await _db.runTransaction((tx) async {
        final salaRef = _salaRef(idSala);
        final salaSnap = await tx.get(salaRef);
        if (!salaSnap.exists) return;

        final sala = Sala.fromMap(idSala, salaSnap.data());
        if (sala.estado != EstadoSala.lobby) return;

        final orden = List<String>.from(sala.ordenJugadores)..remove(uid);
        tx.delete(_jugadoresRef(idSala).doc(uid));
        if (orden.isEmpty) {
          // Se ha ido el ultimo: la sala no le sirve ya a nadie.
          tx.delete(salaRef);
          return;
        }
        tx.update(salaRef, {
          'orden_jugadores': orden,
          'actualizada': FieldValue.serverTimestamp(),
          if (sala.hostUid == uid) 'host_uid': orden.first,
        });
      });
    } catch (_) {
      // Si falla, el jugador simplemente sigue listado en el lobby.
    }
  }

  // ==========================================================
  // LIMPIEZA DE SALAS ABANDONADAS
  // ==========================================================

  /// Cuánto aguanta una sala sin que pase nada antes de borrarse.
  static const Duration vidaDeUnaSala = Duration(hours: 2);

  /// Borra las salas que llevan [vidaDeUnaSala] sin actividad, con sus
  /// jugadores dentro.
  ///
  /// Se mide desde la última jugada, no desde que se creó la sala: así una
  /// partida larga de varias rondas no se borra mientras se está jugando,
  /// y una abandonada desaparece igual.
  ///
  /// Se llama al abrir la pantalla de inicio. No hace falta un servidor:
  /// basta con que alguien abra la app de vez en cuando.
  ///
  /// Devuelve cuántas salas ha borrado.
  Future<int> limpiarSalasAbandonadas({int maximo = 20}) async {
    try {
      final limite = Timestamp.fromDate(
        DateTime.now().toUtc().subtract(vidaDeUnaSala),
      );

      final caducadas = <DocumentSnapshot<Map<String, dynamic>>>[];

      final porActividad = await _db
          .collection('salas')
          .where('actualizada', isLessThan: limite)
          .limit(maximo)
          .get();
      caducadas.addAll(porActividad.docs);

      // Salas creadas antes de que existiera el campo `actualizada`: se miran
      // por fecha de creación, pero solo se borran si de verdad no lo tienen
      // (si lo tienen, ya las habría cogido la consulta de arriba).
      if (caducadas.length < maximo) {
        final antiguas = await _db
            .collection('salas')
            .where('creada', isLessThan: limite)
            .limit(maximo)
            .get();
        for (final doc in antiguas.docs) {
          if (doc.data().containsKey('actualizada')) continue;
          if (caducadas.any((d) => d.id == doc.id)) continue;
          caducadas.add(doc);
        }
      }

      var borradas = 0;
      for (final sala in caducadas) {
        if (await _borrarSala(sala.reference)) borradas++;
      }
      return borradas;
    } catch (_) {
      // La limpieza es un extra: si falla, no debe estorbar al jugador.
      return 0;
    }
  }

  /// Borra una sala y sus subcolecciones (jugadores y reacciones de voz).
  ///
  /// Firestore no borra las subcolecciones al borrar el documento padre: si
  /// no se hace a mano, los jugadores se quedan ahí colgados para siempre.
  Future<bool> _borrarSala(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      final jugadores = await ref.collection('jugadores').get();
      final audios = await ref.collection('audios').get();
      final batch = _db.batch();
      for (final j in jugadores.docs) {
        batch.delete(j.reference);
      }
      for (final a in audios.docs) {
        batch.delete(a.reference);
      }
      batch.delete(ref);
      await batch.commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ==========================================================
  // REPARTO DE RONDAS
  // ==========================================================

  Future<String?> iniciarPartida(String idSala) =>
      _repartirRonda(idSala, reiniciarFichas: true, primeraRonda: true);

  Future<String?> siguienteRonda(String idSala) =>
      _repartirRonda(idSala, reiniciarFichas: false, primeraRonda: false);

  Future<String?> nuevaPartida(String idSala) =>
      _repartirRonda(idSala, reiniciarFichas: true, primeraRonda: true);

  /// Baraja, aparta cartas y reparte 1 carta a cada jugador.
  Future<String?> _repartirRonda(
    String idSala, {
    required bool reiniciarFichas,
    required bool primeraRonda,
  }) async {
    try {
      final salaRef = _salaRef(idSala);
      final salaSnap = await salaRef.get();
      if (!salaSnap.exists) return 'La sala no existe';
      final sala = Sala.fromMap(idSala, salaSnap.data());

      final jugadoresSnap = await _jugadoresRef(idSala).orderBy('orden').get();
      final docs = jugadoresSnap.docs;

      if (docs.length < minJugadores) {
        return 'Hacen falta al menos $minJugadores jugadores';
      }
      if (docs.length > maxJugadores) {
        return 'Como maximo $maxJugadores jugadores';
      }

      final mazo = Cartas.mazoCompleto()..shuffle(_rnd);

      // Reglas: en partida de 2 jugadores se apartan 3 cartas (2 boca arriba
      // y 1 boca abajo). Con 3 o mas jugadores solo 1 boca abajo.
      final apartadas = <int>[];
      if (docs.length == 2) {
        apartadas.add(mazo.removeAt(0));
        apartadas.add(mazo.removeAt(0));
      }
      final cartaOculta = mazo.removeAt(0);

      final batch = _db.batch();
      final orden = <String>[];
      final nombres = <String, String>{};

      for (var i = 0; i < docs.length; i++) {
        final doc = docs[i];
        orden.add(doc.id);
        nombres[doc.id] = (doc.data()['nombre'] as String?) ?? 'Jugador';
        batch.set(
          doc.reference,
          {
            'mano': <int>[mazo.removeAt(0)],
            'cartas_jugadas': <int>[],
            'vivo': true,
            'protegido': false,
            'orden': i,
            'revelaciones': <String>[],
            'accion_pendiente': null,
            if (reiniciarFichas) 'fichas_victoria': 0,
          },
          SetOptions(merge: true),
        );
      }

      // En la primera ronda empieza uno al azar (antes salia siempre el
      // anfitrion). En las siguientes empieza quien gano la ronda anterior.
      var inicial = primeraRonda ? null : sala.ganadorRondaUid;
      if (inicial == null || !orden.contains(inicial)) {
        inicial = orden[_rnd.nextInt(orden.length)];
      }

      final ronda = primeraRonda ? 1 : sala.ronda + 1;
      final fichasParaGanar = docs.length <= 3 ? 3 : 2;

      batch.update(salaRef, {
        'actualizada': FieldValue.serverTimestamp(),
        'estado': EstadoSala.jugando,
        'mazo_central': mazo,
        'carta_oculta': cartaOculta,
        'cartas_apartadas': apartadas,
        'orden_jugadores': orden,
        'turno_actual': inicial,
        'ronda': ronda,
        'fichas_para_ganar': fichasParaGanar,
        'ganadores_ronda': <String>[],
        'ganador_ronda_uid': null,
        'ultima_jugada': null,
        'historial_jugadas': <Map<String, dynamic>>[],
        'motivo_final': null,
        'carta_ganadora': null,
        if (primeraRonda) 'ganadores_partida': <String>[],
        'registro': <String>[
          'Ronda $ronda. Empieza ${nombres[inicial]}. '
              'Hacen falta $fichasParaGanar fichas para ganar la partida.',
        ],
      });

      await batch.commit();

      // Las reacciones de voz de la ronda anterior ya no pintan nada.
      try {
        final audios = await salaRef.collection('audios').get();
        if (audios.docs.isNotEmpty) {
          final limpieza = _db.batch();
          for (final a in audios.docs) {
            limpieza.delete(a.reference);
          }
          await limpieza.commit();
        }
      } catch (_) {}

      return null;
    } catch (e) {
      return 'No se pudo repartir la ronda: $e';
    }
  }

  /// Vuelve al lobby manteniendo a los jugadores.
  Future<void> volverAlLobby(String idSala) async {
    final batch = _db.batch();
    final jugadoresSnap = await _jugadoresRef(idSala).get();
    for (final doc in jugadoresSnap.docs) {
      batch.set(
        doc.reference,
        {
          'mano': <int>[],
          'cartas_jugadas': <int>[],
          'vivo': true,
          'protegido': false,
          'fichas_victoria': 0,
          'revelaciones': <String>[],
          'accion_pendiente': null,
        },
        SetOptions(merge: true),
      );
    }
    batch.update(_salaRef(idSala), {
      'actualizada': FieldValue.serverTimestamp(),
      'estado': EstadoSala.lobby,
      'mazo_central': <int>[],
      'carta_oculta': null,
      'cartas_apartadas': <int>[],
      'turno_actual': '',
      'ronda': 0,
      'ganadores_ronda': <String>[],
      'ganador_ronda_uid': null,
      'ganadores_partida': <String>[],
      'registro': <String>[],
      'ultima_jugada': null,
      'historial_jugadas': <Map<String, dynamic>>[],
    });
    await batch.commit();
  }

  // ==========================================================
  // TURNO: ROBAR
  // ==========================================================

  Future<String?> robarCarta(String idSala, String uid) async {
    try {
      return await _db.runTransaction<String?>((tx) async {
        final salaRef = _salaRef(idSala);
        final jugadorRef = _jugadoresRef(idSala).doc(uid);

        final salaSnap = await tx.get(salaRef);
        final jugadorSnap = await tx.get(jugadorRef);
        if (!salaSnap.exists || !jugadorSnap.exists) {
          return 'Sala no encontrada';
        }

        final sala = Sala.fromMap(idSala, salaSnap.data());
        final jugador = Jugador.fromMap(uid, jugadorSnap.data());

        if (sala.estado != EstadoSala.jugando) {
          return 'La partida no esta en curso';
        }
        if (sala.turnoActual != uid) return 'No es tu turno';
        if (!jugador.vivo) return 'Estas eliminado';
        if (jugador.accionPendiente != null) {
          return 'Resuelve primero tu accion pendiente';
        }
        if (jugador.mano.length != 1) return 'Ya has robado';

        final mazo = List<int>.from(sala.mazoCentral);
        if (mazo.isEmpty) return 'No quedan cartas en el mazo';

        final robada = mazo.removeAt(0);

        tx.update(salaRef, {
          'mazo_central': mazo,
          'actualizada': FieldValue.serverTimestamp(),
        });
        tx.update(jugadorRef, {
          'mano': [...jugador.mano, robada],
          // El escudo dura hasta el inicio de tu siguiente turno.
          'protegido': false,
        });
        return null;
      });
    } catch (e) {
      return 'No se pudo robar: $e';
    }
  }

  // ==========================================================
  // TURNO: JUGAR CARTA
  // ==========================================================

  /// Juega una carta. Devuelve `null` si va bien, o el motivo del fallo.
  Future<String?> jugarCarta(
    String idSala,
    String miUid,
    int valor, {
    String? targetUid,
    int? adivinanza,
  }) async {
    try {
      return await _db.runTransaction<String?>((tx) async {
        final salaRef = _salaRef(idSala);
        final salaSnap = await tx.get(salaRef);
        if (!salaSnap.exists) return 'La sala no existe';

        final sala = Sala.fromMap(idSala, salaSnap.data());
        if (sala.estado != EstadoSala.jugando) {
          return 'La partida no esta en curso';
        }
        if (sala.turnoActual != miUid) return 'No es tu turno';

        final estados = await _leerJugadores(tx, idSala, sala.ordenJugadores);
        final yo = _buscar(estados, miUid);
        if (yo == null) return 'No estas en esta partida';
        if (!yo.vivo) return 'Estas eliminado';
        if (yo.pendiente != null) return 'Resuelve primero tu accion pendiente';
        if (yo.mano.length != 2) return 'Primero roba una carta';
        if (!yo.mano.contains(valor)) return 'No tienes esa carta en la mano';

        final mazo = List<int>.from(sala.mazoCentral);
        final registro = List<String>.from(sala.registro);
        int? cartaOculta = sala.cartaOculta;

        // Bajar la carta: queda boca arriba delante de mi.
        // No hay descarte comun, cada jugador acumula lo que ha jugado.
        yo.mano.remove(valor);
        yo.jugadas.add(valor);
        yo.protegido = false;
        final retenida = yo.mano.isEmpty ? -1 : yo.mano.first;

        _log(registro, '${yo.nombre} juega $valor ${Cartas.nombreCorto(valor)}.');
        // A partir de aqui, todo lo que se registre es consecuencia de esta
        // carta: sirve para contar en la mesa que ha pasado.
        final marcaRegistro = registro.length;

        // Objetivos validos: vivos, que no sea yo, y que no esten protegidos.
        final objetivosLegales = estados
            .where((p) => p.uid != miUid && p.vivo && !p.protegido)
            .toList();

        // Que ha provocado la carta, para poder animarlo en la mesa.
        var efecto = Efecto.nada;
        _EstadoJugador? afectado;

        _EstadoJugador? objetivo;
        if (Cartas.requiereObjetivo(valor)) {
          if (objetivosLegales.isEmpty) {
            _log(registro,
                'No hay ningun rival al que apuntar, la carta no hace nada.');
          } else {
            if (targetUid == null) return 'Tienes que elegir a un rival';
            objetivo = _buscar(objetivosLegales, targetUid);
            if (objetivo == null) return 'Ese rival no es un objetivo valido';
          }
        }

        // ------------------------------------------------------
        // EFECTOS
        // ------------------------------------------------------
        switch (valor) {
          case 0: // El Capo de la Colonia: solo cuenta al final de la ronda.
            break;

          case 1: // La Pitonisa: adivinar la carta del rival.
            if (objetivo != null) {
              // Regla de la casa: aqui SI se puede adivinar el 1.
              if (adivinanza == null || adivinanza < 0 || adivinanza > 10) {
                return 'Tienes que adivinar un numero del 1 al 10';
              }
              if (objetivo.carta == adivinanza) {
                _log(
                    registro,
                    '${yo.nombre} adivina que ${objetivo.nombre} tenia un '
                    '$adivinanza: acierta y queda eliminado.');
                objetivo.eliminar();
                efecto = Efecto.eliminado;
                afectado = objetivo;
              } else {
                _log(
                    registro,
                    '${yo.nombre} dice que ${objetivo.nombre} tiene un '
                    '$adivinanza: falla, y ${objetivo.nombre} no revela nada.');
                efecto = Efecto.fallo;
                afectado = objetivo;
              }
            }
            break;

          case 2: // El Correvvidile: mirar la carta de arriba y recolocarla.
            if (mazo.isEmpty) {
              _log(registro,
                  'El mazo esta vacio: El Correvvidile no hace nada.');
            } else {
              final vista = mazo.removeAt(0);
              yo.pendiente = AccionPendiente(tipo: 'ratonera', carta: vista);
              efecto = Efecto.mirada;
              _log(registro,
                  '${yo.nombre} mira la carta superior del mazo en secreto.');
            }
            break;

          case 3: // El Maton: comparar cartas.
            if (objetivo != null) {
              yo.revelaciones.add(
                  'El Maton: tu $retenida contra el ${objetivo.carta} '
                  'de ${objetivo.nombre}.');
              objetivo.revelaciones.add(
                  'El Maton: ${yo.nombre} comparo su $retenida con tu '
                  '${objetivo.carta}.');
              if (retenida > objetivo.carta) {
                _log(
                    registro,
                    '${yo.nombre} gana la comparacion: ${objetivo.nombre} '
                    'queda eliminado con un ${objetivo.carta}.');
                objetivo.eliminar();
                efecto = Efecto.eliminado;
                afectado = objetivo;
              } else if (retenida < objetivo.carta) {
                _log(
                    registro,
                    '${objetivo.nombre} gana la comparacion: ${yo.nombre} '
                    'queda eliminado con un $retenida.');
                yo.eliminar();
                efecto = Efecto.autoEliminado;
                afectado = yo;
              } else {
                _log(registro,
                    '${yo.nombre} y ${objetivo.nombre} empatan: no pasa nada.');
                efecto = Efecto.nada;
                afectado = objetivo;
              }
            }
            break;

          case 4: // La Sabia: proteccion.
            yo.protegido = true;
            _log(registro,
                '${yo.nombre} queda protegido hasta su proximo turno.');
            efecto = Efecto.protegido;
            afectado = yo;
            break;

          case 5: // El Rey de las Mareas: forzar a bajar carta y robar otra.
            if (objetivo != null) {
              final forzada = objetivo.carta;
              objetivo.mano.clear();
              objetivo.jugadas.add(forzada);
              _log(
                  registro,
                  '${yo.nombre} obliga a ${objetivo.nombre} a bajar su '
                  '$forzada ${Cartas.nombreCorto(forzada)} sin efecto.');
              efecto = Efecto.forzado;
              afectado = objetivo;
              if (forzada == 10) {
                _log(registro,
                    'Era el Rey del Trono: ${objetivo.nombre} queda eliminado.');
                objetivo.eliminar();
                efecto = Efecto.eliminado;
              } else if (mazo.isNotEmpty) {
                objetivo.mano.add(mazo.removeAt(0));
              } else if (cartaOculta != null) {
                // Regla: si no quedan cartas, roba la carta apartada.
                objetivo.mano.add(cartaOculta);
                objetivo.revelaciones
                    .add('Has robado la carta que estaba apartada.');
                cartaOculta = null;
              } else {
                _log(
                    registro,
                    'No queda ninguna carta que robar: ${objetivo.nombre} '
                    'queda fuera de la ronda.');
                objetivo.eliminar();
              }
            }
            break;

          case 6: // El Ladron de Sombras: mirar la carta apartada.
            if (cartaOculta == null) {
              _log(registro,
                  'No hay carta apartada: El Ladron de Sombras no hace nada.');
            } else {
              yo.pendiente =
                  AccionPendiente(tipo: 'enterrador', carta: cartaOculta);
              efecto = Efecto.mirada;
              _log(registro,
                  '${yo.nombre} desentierra la carta apartada en secreto.');
            }
            break;

          case 7: // El Animador: todos devuelven su carta y se rebaraja.
            final participantes =
                estados.where((p) => p.vivo && !p.protegido).toList();
            final bolsa = <int>[...mazo];
            for (final p in participantes) {
              bolsa.addAll(p.mano);
              p.mano = [];
            }
            bolsa.shuffle(_rnd);
            for (final p in participantes) {
              if (bolsa.isNotEmpty) p.mano = [bolsa.removeAt(0)];
            }
            mazo
              ..clear()
              ..addAll(bolsa);
            _log(
                registro,
                '${participantes.map((p) => p.nombre).join(', ')} devuelven su '
                'carta al mazo, se baraja y se reparte de nuevo.');
            efecto = Efecto.rebarajado;
            break;

          case 8: // La Forja: intercambio de manos.
            if (objetivo != null) {
              final suya = objetivo.carta;
              objetivo.mano = [retenida];
              yo.mano = [suya];
              yo.revelaciones.add(
                  'La Forja: le diste tu $retenida a '
                  '${objetivo.nombre} y recibiste un $suya.');
              objetivo.revelaciones.add(
                  'La Forja: ${yo.nombre} te quito tu $suya y te '
                  'dejo un $retenida.');
              _log(registro,
                  '${yo.nombre} y ${objetivo.nombre} intercambian sus cartas.');
              efecto = Efecto.intercambio;
              afectado = objetivo;
            }
            break;

          case 9: // La Venganza: quien tenga el Rey del Trono cambia contigo.
            final conRey = estados.firstWhere(
              (p) => p.uid != miUid && p.vivo && !p.protegido && p.carta == 10,
              orElse: () => yo,
            );
            if (conRey.uid == miUid) {
              _log(registro,
                  'Nadie al alcance tiene al Rey del Trono: no pasa nada.');
            } else {
              conRey.mano = [retenida];
              yo.mano = [10];
              efecto = Efecto.intercambio;
              afectado = conRey;
              _log(
                  registro,
                  '${conRey.nombre} tenia al Rey del Trono. Ahora lo tiene '
                  '${yo.nombre}, que le pasa su $retenida.');
            }
            break;

          case 10: // Rey del Trono de Peluche: bajarlo te elimina.
            _log(registro,
                '${yo.nombre} baja al Rey del Trono y queda eliminado al instante.');
            yo.eliminar();
            efecto = Efecto.autoEliminado;
            afectado = yo;
            break;
        }

        // ------------------------------------------------------
        // CIERRE DE TURNO
        // ------------------------------------------------------
        final jugada = UltimaJugada(
          uid: miUid,
          nombre: yo.nombre,
          carta: valor,
          resultado: registro.length > marcaRegistro
              ? registro.sublist(marcaRegistro).join(' ')
              : '',
          objetivoUid: afectado?.uid ?? objetivo?.uid,
          objetivoNombre: afectado?.nombre ?? objetivo?.nombre,
          efecto: efecto,
        );

        final salaUpdate = <String, dynamic>{
          'mazo_central': mazo,
          'carta_oculta': cartaOculta,
          'ultima_jugada': jugada.toMap(),
          'historial_jugadas': _apuntarEnHistorial(sala.historial, jugada),
        };

        // Si la carta deja una accion pendiente (2 y 6), el turno no avanza
        // hasta que el jugador la resuelva.
        if (yo.pendiente == null) {
          salaUpdate.addAll(_finDeTurno(
            estados: estados,
            actorUid: miUid,
            mazo: mazo,
            registro: registro,
            sala: sala,
          ));
        }
        salaUpdate['registro'] = registro;
        salaUpdate['actualizada'] = FieldValue.serverTimestamp();

        for (final p in estados) {
          tx.set(_jugadoresRef(idSala).doc(p.uid), p.aFirestore(),
              SetOptions(merge: true));
        }
        tx.update(salaRef, salaUpdate);
        return null;
      });
    } catch (e) {
      return 'No se pudo jugar la carta: $e';
    }
  }

  // ==========================================================
  // RESOLUCION DE ACCIONES PENDIENTES (cartas 2 y 6)
  // ==========================================================

  /// Carta 2 (El Correvvidile): devuelve la carta vista al mazo.
  Future<String?> resolverCazarratones(
      String idSala, String miUid, int posicion) {
    return _resolverPendiente(idSala, miUid, 'ratonera',
        (estados, yo, mazo, registro, cartaOculta) {
      final destino = posicion.clamp(0, mazo.length);
      mazo.insert(destino, yo.pendiente!.carta);
      _log(registro, '${yo.nombre} devuelve la carta al mazo en secreto.');
      return cartaOculta;
    });
  }

  /// Carta 6 (El Ladron de Sombras): decide si se queda la apartada.
  Future<String?> resolverPerroSepulturero(
      String idSala, String miUid, bool intercambiar) {
    return _resolverPendiente(idSala, miUid, 'enterrador',
        (estados, yo, mazo, registro, cartaOculta) {
      final vista = yo.pendiente!.carta;
      if (!intercambiar) {
        _log(registro, '${yo.nombre} deja la carta apartada donde estaba.');
        return vista;
      }
      final mia = yo.carta;
      yo.mano = [vista];
      _log(registro,
          '${yo.nombre} cambia su carta por la que estaba apartada.');
      return mia;
    });
  }

  Future<String?> _resolverPendiente(
    String idSala,
    String miUid,
    String tipo,
    int? Function(List<_EstadoJugador> estados, _EstadoJugador yo,
            List<int> mazo, List<String> registro, int? cartaOculta)
        aplicar,
  ) async {
    try {
      return await _db.runTransaction<String?>((tx) async {
        final salaRef = _salaRef(idSala);
        final salaSnap = await tx.get(salaRef);
        if (!salaSnap.exists) return 'La sala no existe';

        final sala = Sala.fromMap(idSala, salaSnap.data());
        if (sala.estado != EstadoSala.jugando) {
          return 'La partida no esta en curso';
        }

        final estados = await _leerJugadores(tx, idSala, sala.ordenJugadores);
        final yo = _buscar(estados, miUid);
        if (yo == null) return 'No estas en esta partida';
        if (yo.pendiente?.tipo != tipo) return 'No tienes esa accion pendiente';

        final mazo = List<int>.from(sala.mazoCentral);
        final registro = List<String>.from(sala.registro);

        final marcaRegistro = registro.length;
        final nuevaOculta =
            aplicar(estados, yo, mazo, registro, sala.cartaOculta);
        yo.pendiente = null;

        final salaUpdate = <String, dynamic>{
          'mazo_central': mazo,
          'carta_oculta': nuevaOculta,
        };
        if (yo.jugadas.isNotEmpty) {
          // Se conserva a quien afectaba la jugada original: esto solo
          // completa la carta de dos pasos, no es una jugada nueva.
          final original = sala.historial.isNotEmpty ? sala.historial.last : null;
          final jugada = UltimaJugada(
            uid: miUid,
            nombre: yo.nombre,
            carta: yo.jugadas.last,
            resultado: registro.length > marcaRegistro
                ? registro.sublist(marcaRegistro).join(' ')
                : '',
            objetivoUid: original?.objetivoUid,
            objetivoNombre: original?.objetivoNombre,
            efecto: original?.efecto ?? Efecto.mirada,
          );
          salaUpdate['ultima_jugada'] = jugada.toMap();
          salaUpdate['historial_jugadas'] =
              _apuntarEnHistorial(sala.historial, jugada, completando: true);
        }
        salaUpdate.addAll(_finDeTurno(
          estados: estados,
          actorUid: miUid,
          mazo: mazo,
          registro: registro,
          sala: sala,
        ));
        salaUpdate['registro'] = registro;
        salaUpdate['actualizada'] = FieldValue.serverTimestamp();

        for (final p in estados) {
          tx.set(_jugadoresRef(idSala).doc(p.uid), p.aFirestore(),
              SetOptions(merge: true));
        }
        tx.update(salaRef, salaUpdate);
        return null;
      });
    } catch (e) {
      return 'No se pudo resolver la accion: $e';
    }
  }

  /// Marca como leidos los mensajes privados.
  Future<void> limpiarRevelaciones(String idSala, String uid) async {
    try {
      await _jugadoresRef(idSala).doc(uid).update({'revelaciones': <String>[]});
    } catch (_) {}
  }

  // ==========================================================
  // FIN DE TURNO / FIN DE RONDA
  // ==========================================================

  Map<String, dynamic> _finDeTurno({
    required List<_EstadoJugador> estados,
    required String actorUid,
    required List<int> mazo,
    required List<String> registro,
    required Sala sala,
  }) {
    final vivos = estados.where((p) => p.vivo).toList();

    // Solo queda uno en pie: gana la ronda.
    if (vivos.length <= 1) {
      return _terminarRonda(
        estados: estados,
        ganadores: vivos,
        registro: registro,
        sala: sala,
        motivo: 'Solo queda un jugador en pie',
        codigo: 'ultimo_en_pie',
      );
    }

    // Regla: la ronda acaba cuando el siguiente jugador no puede robar.
    if (mazo.isEmpty) {
      final ganadores = _ganadoresPorCarta(vivos, registro);
      return _terminarRonda(
        estados: estados,
        ganadores: ganadores,
        registro: registro,
        sala: sala,
        motivo: 'Se ha agotado el mazo',
        codigo: 'mazo_agotado',
      );
    }

    // Pasar el turno al siguiente jugador vivo.
    final indice = estados.indexWhere((p) => p.uid == actorUid);
    for (var i = 1; i <= estados.length; i++) {
      final siguiente = estados[(indice + i) % estados.length];
      if (siguiente.vivo) return {'turno_actual': siguiente.uid};
    }
    return const {};
  }

  List<_EstadoJugador> _ganadoresPorCarta(
      List<_EstadoJugador> vivos, List<String> registro) {
    for (final p in vivos) {
      _log(registro,
          '${p.nombre} revela un ${p.carta} ${Cartas.nombreCorto(p.carta)}.');
    }
    // La regla vive en models/fin_ronda.dart para poder testearla aparte.
    return ganadoresDeRonda(vivos, log: (texto) => _log(registro, texto));
  }

  Map<String, dynamic> _terminarRonda({
    required List<_EstadoJugador> estados,
    required List<_EstadoJugador> ganadores,
    required List<String> registro,
    required Sala sala,
    required String motivo,
    required String codigo,
  }) {
    for (final g in ganadores) {
      g.fichas += 1;
      g.pendiente = null;
    }

    final nombres = ganadores.map((g) => g.nombre).toList();
    _log(
        registro,
        '$motivo. Gana la ronda '
        '${nombres.isEmpty ? "nadie" : nombres.join(" y ")}.');

    final campeones =
        estados.where((p) => p.fichas >= sala.fichasParaGanar).toList();

    final update = <String, dynamic>{
      'ganadores_ronda': nombres,
      'ganador_ronda_uid': ganadores.isEmpty ? null : ganadores.first.uid,
      'turno_actual': '',
      // Como se ha ganado, para poder contarlo bien en la pantalla final.
      'motivo_final': codigo,
      'carta_ganadora': ganadores.isEmpty ? null : ganadores.first.carta,
    };

    if (campeones.isNotEmpty) {
      final nombresCampeones = campeones.map((c) => c.nombre).toList();
      _log(
          registro,
          '${nombresCampeones.join(" y ")} gana la partida con '
          '${sala.fichasParaGanar} fichas.');
      update['estado'] = EstadoSala.finPartida;
      update['ganadores_partida'] = nombresCampeones;
    } else {
      update['estado'] = EstadoSala.finRonda;
    }
    return update;
  }

  // ==========================================================
  // UTILIDADES
  // ==========================================================

  Future<List<_EstadoJugador>> _leerJugadores(
      Transaction tx, String idSala, List<String> uids) async {
    final estados = <_EstadoJugador>[];
    for (final uid in uids) {
      final snap = await tx.get(_jugadoresRef(idSala).doc(uid));
      if (!snap.exists) continue;
      estados.add(_EstadoJugador.desde(Jugador.fromMap(uid, snap.data())));
    }
    estados.sort((a, b) => a.orden.compareTo(b.orden));
    return estados;
  }

  _EstadoJugador? _buscar(List<_EstadoJugador> estados, String uid) {
    for (final p in estados) {
      if (p.uid == uid) return p;
    }
    return null;
  }

  /// Anade la jugada al historial de la ronda.
  ///
  /// Con [completando] en true no se anade una entrada nueva: se completa la
  /// ultima, porque las cartas de dos pasos (2 y 6) se juegan y se resuelven
  /// en dos momentos distintos pero son una sola jugada.
  List<Map<String, dynamic>> _apuntarEnHistorial(
    List<UltimaJugada> historial,
    UltimaJugada jugada, {
    bool completando = false,
  }) {
    final lista = historial.map((j) => j.toMap()).toList();

    if (completando &&
        lista.isNotEmpty &&
        lista.last['uid'] == jugada.uid &&
        lista.last['carta'] == jugada.carta) {
      final anterior = (lista.last['resultado'] as String? ?? '').trim();
      lista[lista.length - 1] = UltimaJugada(
        uid: jugada.uid,
        nombre: jugada.nombre,
        carta: jugada.carta,
        resultado: [anterior, jugada.resultado]
            .where((t) => t.isNotEmpty)
            .join(' '),
      ).toMap();
      return lista;
    }

    lista.add(jugada.toMap());
    // Una ronda no da para mas de 21 jugadas, pero por si acaso.
    if (lista.length > 30) lista.removeRange(0, lista.length - 30);
    return lista;
  }

  void _log(List<String> registro, String texto) {
    registro.add(texto);
    if (registro.length > _maxRegistro) {
      registro.removeRange(0, registro.length - _maxRegistro);
    }
  }
}
