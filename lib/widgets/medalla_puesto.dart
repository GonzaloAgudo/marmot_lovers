import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Medalla del puesto en el que has quedado (1 a 6).
///
/// Si faltara el PNG, dibuja un circulo con el numero, para que la fila
/// nunca se quede coja.
class MedallaPuesto extends StatelessWidget {
  final int puesto;
  final double altura;

  const MedallaPuesto({super.key, required this.puesto, this.altura = 52});

  @override
  Widget build(BuildContext context) {
    if (puesto < 1 || puesto > 6) return SizedBox(height: altura);

    return SizedBox(
      height: altura,
      child: Image.asset(
        'assets/puestos/$puesto.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => _respaldo(),
      ),
    );
  }

  Widget _respaldo() => Container(
        width: altura * 0.72,
        height: altura * 0.72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.superficieAlta,
          border: Border.all(color: AppColors.borde),
        ),
        child: Center(
          child: Text(
            '$puesto',
            style: TextStyle(
              fontSize: altura * 0.34,
              fontWeight: FontWeight.w900,
              color: AppColors.textoSuave,
            ),
          ),
        ),
      );
}
