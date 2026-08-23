import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../enlaces.dart';
import '../models/jugador.dart';
import '../models/sala.dart';
import '../repositories/game_repository.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String idSala;
  final String miUid;

  const LobbyScreen({super.key, required this.idSala, required this.miUid});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final GameRepository _repo = GameRepository();
  bool _iniciando = false;

  /// Igual que en la mesa: una sola suscripcion, creada al entrar.
  late final Stream<Sala> _salaStream = _repo.streamSala(widget.idSala);
  late final Stream<List<Jugador>> _jugadoresStream =
      _repo.streamJugadores(widget.idSala);

  Future<void> _iniciar() async {
    setState(() => _iniciando = true);
    final error = await _repo.iniciarPartida(widget.idSala);
    if (!mounted) return;
    setState(() => _iniciando = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  /// Abre el menu de compartir del sistema con el enlace de invitacion.
  /// Quien lo reciba abre la web y entra directo en la sala.
  Future<void> _compartirEnlace() async {
    final mensaje = Enlaces.mensajeInvitacion(widget.idSala);
    try {
      await Share.share(mensaje, subject: 'Partida de Marmot Lovers');
    } catch (_) {
      // Si el sistema no tiene menu de compartir, al portapapeles.
      await Clipboard.setData(ClipboardData(text: mensaje));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enlace copiado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Sala>(
      stream: _salaStream,
      builder: (context, snapSala) {
        if (snapSala.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: MesaFondo(
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.acento)),
            ),
          );
        }
        if (!snapSala.hasData) {
          return const Scaffold(
            body: MesaFondo(child: Center(child: Text('Error al cargar la sala'))),
          );
        }

        final sala = snapSala.data!;

        // Cualquier estado que no sea el lobby se juega en GameScreen:
        // jugando, fin de ronda y fin de partida.
        if (sala.estado != EstadoSala.lobby) {
          return GameScreen(idSala: widget.idSala, miUid: widget.miUid);
        }

        return Scaffold(
          body: MesaFondo(
            child: SafeArea(
              child: StreamBuilder<List<Jugador>>(
                stream: _jugadoresStream,
                builder: (context, snapJugadores) {
                  if (!snapJugadores.hasData) {
                    return const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.acento));
                  }

                  final jugadores = snapJugadores.data!;
                  final soyHost = sala.hostUid == widget.miUid;
                  final suficientes =
                      jugadores.length >= GameRepository.minJugadores;
                  final fichas = jugadores.length <= 3 ? 3 : 2;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 8, 0),
                        child: Row(
                          children: [
                            const Etiqueta('sala de espera'),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              tooltip: 'Salir',
                              onPressed: () async {
                                await _repo.abandonarSala(
                                    widget.idSala, widget.miUid);
                                if (context.mounted) Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      _tarjetaCodigo(context),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Row(
                          children: [
                            Etiqueta(
                                '${jugadores.length} de '
                                '${GameRepository.maxJugadores} jugadores'),
                            const Spacer(),
                            if (suficientes)
                              Etiqueta('$fichas fichas para ganar',
                                  color: AppColors.acento),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 18),
                          itemCount: GameRepository.maxJugadores,
                          itemBuilder: (context, index) {
                            if (index >= jugadores.length) {
                              return _sitioLibre(index);
                            }
                            return _sitioOcupado(
                                jugadores[index], sala, index);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
                        child: soyHost
                            ? SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.play_arrow, size: 20),
                                  label: Text(suficientes
                                      ? 'EMPEZAR PARTIDA'
                                      : 'FALTA ALGUIEN MAS'),
                                  onPressed: (!suficientes || _iniciando)
                                      ? null
                                      : _iniciar,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.textoTenue),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Esperando al anfitrion...',
                                    style: TextStyle(
                                        color: AppColors.textoSuave,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tarjetaCodigo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Panel(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        child: Column(
          children: [
            const Etiqueta('codigo de la sala'),
            const SizedBox(height: 8),
            Text(
              widget.idSala,
              style: const TextStyle(
                fontSize: 44,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 10,
                color: AppColors.acento,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('COMPARTIR ENLACE'),
                onPressed: _compartirEnlace,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              Enlaces.invitacion(widget.idSala),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textoTenue),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 15),
              label: const Text('Copiar solo el codigo'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.idSala));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Codigo copiado')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sitioOcupado(Jugador j, Sala sala, int index) {
    final esHost = sala.hostUid == j.uid;
    final soyYo = j.uid == widget.miUid;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.superficie.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: soyYo ? AppColors.acento : AppColors.borde,
          width: soyYo ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.asiento(index),
            ),
            child: Center(
              child: Text(
                j.nombre.isEmpty ? '?' : j.nombre[0].toUpperCase(),
                style: const TextStyle(
                    fontWeight: FontWeight.w900, color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              j.nombre,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (esHost) const Etiqueta('anfitrion'),
          if (soyYo) ...[
            if (esHost) const SizedBox(width: 8),
            const Etiqueta('tu', color: AppColors.acento),
          ],
        ],
      ),
    );
  }

  Widget _sitioLibre(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borde),
      ),
      child: const Row(
        children: [
          Icon(Icons.person_outline, size: 22, color: AppColors.textoTenue),
          SizedBox(width: 14),
          Etiqueta('sitio libre'),
        ],
      ),
    );
  }
}
