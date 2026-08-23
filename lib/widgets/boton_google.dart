import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Botón de "Continuar con Google", con el aspecto que pide Google para el
/// botón (fondo blanco, texto oscuro, marca a la izquierda).
///
/// La marca es el logotipo oficial de `assets/google/logo.svg`. Si el asset
/// fallara por lo que sea, se dibuja una "G" en el azul de Google en su lugar,
/// para que el botón nunca salga vacío.
class BotonGoogle extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool cargando;
  final String texto;

  const BotonGoogle({
    super.key,
    required this.onPressed,
    this.cargando = false,
    this.texto = 'Continuar con Google',
  });

  static const Color _azul = Color(0xFF4285F4);
  static const Color _textoBoton = Color(0xFF3C4043);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: cargando ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (cargando)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: _azul),
                  )
                else
                  const _Marca(),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textoBoton,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 22,
        height: 22,
        child: SvgPicture.asset(
          'assets/google/logo.svg',
          fit: BoxFit.contain,
          placeholderBuilder: (_) => const _MarcaLetra(),
        ),
      );
}

/// Respaldo por si el SVG no carga.
class _MarcaLetra extends StatelessWidget {
  const _MarcaLetra();

  @override
  Widget build(BuildContext context) => const Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 21,
            height: 1,
            fontWeight: FontWeight.w700,
            color: BotonGoogle._azul,
          ),
        ),
      );
}
