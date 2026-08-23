import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/carta.dart';
import '../providers/style_provider.dart';
import '../theme/app_theme.dart';

/// Iconos de apoyo para la carta de respaldo (cuando no hay PNG del estilo).
const Map<int, IconData> _iconos = {
  0: Icons.smart_toy,
  1: Icons.rice_bowl,
  2: Icons.pest_control_rodent,
  3: Icons.cruelty_free,
  4: Icons.shield,
  5: Icons.auto_fix_high,
  6: Icons.pets,
  7: Icons.shuffle,
  8: Icons.swap_horiz,
  9: Icons.report_gmailerrorred,
  10: Icons.military_tech,
};

/// Dibuja una carta con la proporcion de una carta real.
///
/// Si el PNG del estilo activo no existe, pinta una carta de respaldo con el
/// numero, el icono y el nombre, asi nunca se rompe por un asset que falte.
class CartaWidget extends StatelessWidget {
  /// `null` = carta boca abajo.
  final int? valor;
  final double altura;
  final bool seleccionada;
  final bool atenuada;
  final bool compacta;
  final VoidCallback? onTap;

  /// Mantener pulsada una carta siempre la amplía, aunque al tocarla se haga
  /// otra cosa (por ejemplo elegirla para jugar).
  final VoidCallback? onLongPress;

  const CartaWidget({
    super.key,
    required this.valor,
    this.altura = 140,
    this.seleccionada = false,
    this.atenuada = false,
    this.compacta = false,
    this.onTap,
    this.onLongPress,
  });

  static const double ratio = 0.68;

  @override
  Widget build(BuildContext context) {
    final style = Provider.of<StyleProvider>(context);
    final ancho = altura * ratio;

    Widget carta = Container(
      height: altura,
      width: ancho,
      decoration: BoxDecoration(
        // Color de base: mientras carga el PNG se ve la carta, no un hueco.
        color: valor == null
            ? const Color(0xFF241A44)
            : AppColors.carta(valor!),
        borderRadius: BorderRadius.circular(altura * 0.09),
        border: Border.all(
          color: seleccionada ? AppColors.acento : Colors.white24,
          width: seleccionada ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: seleccionada
                ? AppColors.acento.withValues(alpha: 0.45)
                : Colors.black.withValues(alpha: 0.45),
            blurRadius: seleccionada ? 16 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        style.rutaCarta(valor ?? -1),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _respaldo(ancho),
      ),
    );

    if (atenuada) {
      carta = Opacity(opacity: 0.35, child: carta);
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: carta,
    );
  }

  Widget _respaldo(double ancho) {
    if (valor == null) return _dorso(ancho);

    final v = valor!;
    final base = AppColors.carta(v);
    final escala = altura / 150;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, Colors.white, 0.18)!,
            base,
            Color.lerp(base, Colors.black, 0.42)!,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Icono grande de fondo.
          Positioned(
            right: -ancho * 0.18,
            bottom: -altura * 0.06,
            child: Icon(
              _iconos[v] ?? Icons.help_outline,
              size: altura * 0.62,
              color: Colors.white.withValues(alpha: 0.13),
            ),
          ),
          // Numero arriba a la izquierda.
          Positioned(
            top: altura * 0.05,
            left: altura * 0.05,
            child: Text(
              '$v',
              style: TextStyle(
                fontSize: (altura * 0.2).clamp(11, 34),
                height: 1,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: const [
                  Shadow(color: Colors.black45, blurRadius: 3),
                ],
              ),
            ),
          ),
          if (!compacta)
            Positioned(
              left: 5,
              right: 5,
              bottom: 6 * escala,
              child: Container(
                padding: EdgeInsets.symmetric(
                    vertical: 3 * escala, horizontal: 4 * escala),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  Cartas.nombreCorto(v),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: (altura * 0.072).clamp(7, 12),
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dorso(double ancho) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E1F52), Color(0xFF160F2A)],
        ),
      ),
      child: Center(
        child: Container(
          margin: EdgeInsets.all(altura * 0.07),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(altura * 0.05),
            border: Border.all(
              color: AppColors.acento.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.pets,
              size: altura * 0.34,
              color: AppColors.acento.withValues(alpha: 0.42),
            ),
          ),
        ),
      ),
    );
  }
}

/// Version pequena para los montones de cartas ya jugadas.
class CartaMini extends StatelessWidget {
  final int valor;
  final double altura;

  /// Para poder ampliar cualquier carta que esté sobre la mesa.
  final VoidCallback? onTap;

  const CartaMini({
    super.key,
    required this.valor,
    this.altura = 40,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 3),
        child: CartaWidget(
          valor: valor,
          altura: altura,
          compacta: true,
          onTap: onTap,
        ),
      );
}

/// Mazo dibujado como varias cartas apiladas con el contador encima.
class MazoApilado extends StatelessWidget {
  final int cantidad;
  final double altura;
  const MazoApilado({super.key, required this.cantidad, this.altura = 76});

  @override
  Widget build(BuildContext context) {
    final capas = cantidad.clamp(0, 3);
    return SizedBox(
      height: altura,
      width: altura * CartaWidget.ratio + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = capas - 1; i >= 0; i--)
            Positioned(
              top: i * 2.5,
              left: i * 2.5,
              child: CartaWidget(valor: null, altura: altura),
            ),
          if (capas == 0)
            Container(
              height: altura,
              width: altura * CartaWidget.ratio,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(altura * 0.09),
                border: Border.all(color: Colors.white24),
                color: Colors.black.withValues(alpha: 0.25),
              ),
              child: const Center(
                child: Icon(Icons.block, color: AppColors.textoTenue, size: 20),
              ),
            ),
          Positioned(
            bottom: -2,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.fondo,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borde),
              ),
              child: Text(
                '$cantidad',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.texto,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
