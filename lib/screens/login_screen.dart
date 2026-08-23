import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/boton_google.dart';
import '../widgets/carta_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _cargandoGoogle = false;
  bool _verContrasena = false;

  Future<void> _manejarAccion(bool esRegistro) async {
    final authRepo = Provider.of<AuthRepository>(context, listen: false);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _mostrar('Rellena el correo y la contrasena');
      return;
    }

    setState(() => _isLoading = true);

    final error = esRegistro
        ? await authRepo.registrarConCorreo(email, password)
        : await authRepo.loginConCorreo(email, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Si va bien, el StreamBuilder de main.dart nos lleva a HomeScreen.
    if (error != null) _mostrar(error);
  }

  Future<void> _entrarConGoogle() async {
    final authRepo = Provider.of<AuthRepository>(context, listen: false);

    setState(() => _cargandoGoogle = true);
    final error = await authRepo.loginConGoogle();
    if (!mounted) return;
    setState(() => _cargandoGoogle = false);

    if (error != null) _mostrar(error);
  }

  void _mostrar(String mensaje) {
    // Cerrar el diálogo de Google no es un error: no molestamos con un aviso.
    if (mensaje == AuthRepository.cancelado) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MesaFondo(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    // Abanico de cartas como logo.
                    SizedBox(
                      height: 132,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.translate(
                            offset: const Offset(-52, 8),
                            child: Transform.rotate(
                              angle: -0.32,
                              child: const CartaWidget(valor: 1, altura: 108),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(52, 8),
                            child: Transform.rotate(
                              angle: 0.32,
                              child: const CartaWidget(valor: 4, altura: 108),
                            ),
                          ),
                          const CartaWidget(valor: 10, altura: 122),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'MARMOT LOVERS',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.5,
                        color: AppColors.texto,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Solo una carta en la mano. Gana la mas alta.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textoSuave),
                    ),
                    const SizedBox(height: 34),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Correo electronico',
                        prefixIcon: Icon(Icons.alternate_email, size: 20),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Contrasena',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _verContrasena
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 19,
                          ),
                          onPressed: () =>
                              setState(() => _verContrasena = !_verContrasena),
                        ),
                      ),
                      obscureText: !_verContrasena,
                      onSubmitted: (_) => _manejarAccion(false),
                    ),
                    const SizedBox(height: 26),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child:
                            CircularProgressIndicator(color: AppColors.acento),
                      )
                    else
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _cargandoGoogle
                                  ? null
                                  : () => _manejarAccion(false),
                              child: const Text('ENTRAR'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _cargandoGoogle
                                  ? null
                                  : () => _manejarAccion(true),
                              child: const Text('Crear una cuenta nueva'),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 22),
                    const _Separador(),
                    const SizedBox(height: 18),
                    BotonGoogle(
                      cargando: _cargandoGoogle,
                      onPressed: _isLoading ? null : _entrarConGoogle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Linea con la palabra "o" en medio.
class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Expanded(child: Divider(color: AppColors.borde)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('o',
                style: TextStyle(color: AppColors.textoTenue, fontSize: 12)),
          ),
          Expanded(child: Divider(color: AppColors.borde)),
        ],
      );
}
