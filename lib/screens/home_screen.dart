import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../enlaces.dart';
import '../repositories/auth_repository.dart';
import '../repositories/game_repository.dart';
import '../repositories/preferencias.dart';
import '../theme/app_theme.dart';
import '../widgets/carta_widget.dart';
import 'lobby_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GameRepository _gameRepo = GameRepository();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _salaController = TextEditingController();
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();

    // De paso, tiramos las salas que se quedaron a medias. No esperamos al
    // resultado: es tarea de fondo y no debe retrasar la pantalla.
    _gameRepo.limpiarSalasAbandonadas();

    _arrancar();

    // En movil el enlace de invitacion llega como intent, no en la URL.
    Enlaces.escucharEnlacesNativos(_llegaInvitacion);
  }

  /// Un enlace de invitacion ha abierto (o traido al frente) la app.
  Future<void> _llegaInvitacion(String codigo) async {
    if (!mounted) return;

    // Si estabas en el lobby o en una partida, se vuelve al inicio: has
    // pulsado un enlace, quieres ir a esa sala.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    }

    final authRepo = Provider.of<AuthRepository>(context, listen: false);
    final uid = authRepo.usuarioActual?.uid;
    if (uid == null) return;

    _salaController.text = codigo;
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      await _unirsePartida(uid);
    } else {
      await _entrarEnSala(codigo, uid, nombre);
    }
  }

  Future<void> _arrancar() async {
    // Se propone el ultimo nombre que usaste; si nunca has puesto ninguno,
    // el de la cuenta de Google.
    final guardado = await Preferencias.nombreGuardado();
    if (!mounted) return;
    final authRepo = Provider.of<AuthRepository>(context, listen: false);
    _nombreController.text = guardado ?? authRepo.nombreSugerido;

    // Si se ha abierto con un enlace de invitacion, se entra a esa sala.
    final invitado = Enlaces.tomarSalaPendiente();
    if (invitado == null) return;
    final uid = authRepo.usuarioActual?.uid;
    if (uid == null) return;

    _salaController.text = invitado;
    if (_nombreController.text.trim().isEmpty) {
      // Sin nombre no se puede entrar: se pide, con el codigo ya puesto.
      await _unirsePartida(uid);
    } else {
      await _entrarEnSala(invitado, uid, _nombreController.text.trim());
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _salaController.dispose();
    super.dispose();
  }

  void _error(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _irAlLobby(String idSala, String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LobbyScreen(idSala: idSala, miUid: uid)),
    );
  }

  Future<void> _crearPartida(String uid) async {
    final nombre = await _hojaDatos(
      titulo: 'Crear una sala',
      subtitulo: 'Te daremos un codigo para que entren tus amigos.',
      accion: 'CREAR SALA',
    );
    if (nombre == null) return;

    setState(() => _ocupado = true);
    final idSala = await _gameRepo.crearSala(uid, nombre);
    if (!mounted) return;
    setState(() => _ocupado = false);

    if (idSala == null) {
      _error('No se pudo crear la sala. Intentalo otra vez.');
      return;
    }
    await Preferencias.guardarNombre(nombre);
    if (!mounted) return;
    _irAlLobby(idSala, uid);
  }

  Future<void> _unirsePartida(String uid) async {
    final nombre = await _hojaDatos(
      titulo: 'Unirse a una sala',
      subtitulo: 'Pide el codigo de 4 letras a quien haya creado la partida.',
      accion: 'ENTRAR',
      pedirCodigo: true,
    );
    if (nombre == null) return;

    final idSala = _salaController.text.trim().toUpperCase();
    if (idSala.isEmpty) {
      _error('Escribe el codigo de la sala');
      return;
    }

    await _entrarEnSala(idSala, uid, nombre);
  }

  /// Entra en una sala ya existente y guarda el nombre para la próxima.
  Future<void> _entrarEnSala(String idSala, String uid, String nombre) async {
    setState(() => _ocupado = true);
    final error = await _gameRepo.unirseASala(idSala, uid, nombre);
    if (!mounted) return;
    setState(() => _ocupado = false);

    if (error != null) {
      _error(error);
      return;
    }
    await Preferencias.guardarNombre(nombre);
    if (!mounted) return;
    _irAlLobby(idSala, uid);
  }

  /// Devuelve el nombre elegido, o `null` si se cancela.
  Future<String?> _hojaDatos({
    required String titulo,
    required String subtitulo,
    required String accion,
    bool pedirCodigo = false,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 18,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textoTenue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(titulo,
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(subtitulo,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textoSuave)),
            const SizedBox(height: 20),
            if (pedirCodigo) ...[
              TextField(
                controller: _salaController,
                decoration: const InputDecoration(
                  labelText: 'Codigo de la sala',
                  prefixIcon: Icon(Icons.tag, size: 20),
                  counterText: '',
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 4,
                style: const TextStyle(
                    letterSpacing: 6, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Tu nombre en la mesa',
                prefixIcon: Icon(Icons.person_outline, size: 20),
                counterText: '',
              ),
              maxLength: 14,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final nombre = _nombreController.text.trim();
                if (nombre.isEmpty) return;
                Navigator.pop(sheetContext, nombre);
              },
              child: Text(accion),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = Provider.of<AuthRepository>(context, listen: false);
    final usuario = authRepo.usuarioActual;

    return Scaffold(
      body: MesaFondo(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    const Etiqueta('marmot lovers'),
                    const Spacer(),
                    if (usuario?.email != null)
                      Flexible(
                        child: Text(
                          usuario!.email!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textoTenue),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.logout, size: 20),
                      tooltip: 'Cerrar sesion',
                      onPressed: () => authRepo.cerrarSesion(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: usuario == null
                          ? const CircularProgressIndicator(
                              color: AppColors.acento)
                          : Column(
                              children: [
                                SizedBox(
                                  height: 118,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Transform.translate(
                                        offset: const Offset(-46, 6),
                                        child: Transform.rotate(
                                          angle: -0.3,
                                          child: const CartaWidget(
                                              valor: 3, altura: 96),
                                        ),
                                      ),
                                      Transform.translate(
                                        offset: const Offset(46, 6),
                                        child: Transform.rotate(
                                          angle: 0.3,
                                          child: const CartaWidget(
                                              valor: 8, altura: 96),
                                        ),
                                      ),
                                      const CartaWidget(
                                          valor: 10, altura: 110),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 26),
                                const Text(
                                  'De 2 a 6 jugadores',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textoSuave),
                                ),
                                const SizedBox(height: 30),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.add, size: 20),
                                    label: const Text('CREAR PARTIDA'),
                                    onPressed: _ocupado
                                        ? null
                                        : () => _crearPartida(usuario.uid),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.login, size: 19),
                                    label: const Text('UNIRSE CON UN CODIGO'),
                                    onPressed: _ocupado
                                        ? null
                                        : () => _unirsePartida(usuario.uid),
                                  ),
                                ),
                                if (_ocupado) ...[
                                  const SizedBox(height: 26),
                                  const CircularProgressIndicator(
                                      color: AppColors.acento),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
