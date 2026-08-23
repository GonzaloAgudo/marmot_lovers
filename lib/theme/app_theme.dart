import 'package:flutter/material.dart';

/// Paleta del juego: mesa de fieltro verde oscuro con acento ambar.
class AppColors {
  AppColors._();

  static const fondo = Color(0xFF06130D);
  static const fieltroClaro = Color(0xFF17573E);
  static const fieltroOscuro = Color(0xFF04150E);

  static const superficie = Color(0xFF0E2A1F);
  static const superficieAlta = Color(0xFF17402F);
  static const borde = Color(0x22FFFFFF);

  static const acento = Color(0xFFF2B01E);
  static const acentoSuave = Color(0xFFFFD974);
  static const peligro = Color(0xFFE05B4A);
  static const escudo = Color(0xFF5EC8F2);
  static const secreto = Color(0xFF9C6BFF);

  static const texto = Color(0xFFF4F0E4);
  static const textoSuave = Color(0xFF9FB6A9);
  static const textoTenue = Color(0xFF6C8578);

  /// Color propio de cada jugador, por su orden en la mesa.
  static const asientos = <Color>[
    Color(0xFFE8833A),
    Color(0xFF4FA3E3),
    Color(0xFF67C27C),
    Color(0xFFD264C4),
    Color(0xFFE3C64F),
    Color(0xFF7C7BE0),
  ];

  static Color asiento(int orden) => asientos[orden % asientos.length];

  /// Color de fondo de cada carta (se usa en la carta de respaldo).
  static const cartas = <int, Color>{
    0: Color(0xFF5A6B74),
    1: Color(0xFF1C7A6B),
    2: Color(0xFF3F8A46),
    3: Color(0xFF8A7D26),
    4: Color(0xFF2A6FB8),
    5: Color(0xFF7B3FA8),
    6: Color(0xFF5340A8),
    7: Color(0xFFB43570),
    8: Color(0xFFC24A3C),
    9: Color(0xFFDE7A26),
    10: Color(0xFFE2A81C),
  };

  static Color carta(int valor) => cartas[valor] ?? const Color(0xFF3A4A42);
}

class AppTheme {
  AppTheme._();

  static ThemeData get oscuro {
    const esquema = ColorScheme.dark(
      primary: AppColors.acento,
      onPrimary: Color(0xFF1A1200),
      secondary: AppColors.escudo,
      surface: AppColors.superficie,
      onSurface: AppColors.texto,
      error: AppColors.peligro,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: AppColors.fondo,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.texto,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.textoSuave),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: AppColors.texto,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.texto,
        ),
        bodyMedium: TextStyle(color: AppColors.texto, height: 1.35),
        bodySmall: TextStyle(color: AppColors.textoSuave, height: 1.3),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.acento,
          foregroundColor: const Color(0xFF1A1200),
          disabledBackgroundColor: AppColors.superficieAlta,
          disabledForegroundColor: AppColors.textoTenue,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 0.6,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.texto,
          side: const BorderSide(color: AppColors.borde),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.acentoSuave),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.superficie,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.acento, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textoSuave),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.superficieAlta,
        contentTextStyle: const TextStyle(color: AppColors.texto),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.superficieAlta,
        labelStyle: const TextStyle(color: AppColors.texto, fontSize: 12),
        side: const BorderSide(color: AppColors.borde),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.borde, space: 1),
    );
  }
}

/// Fondo de mesa: fieltro con foco de luz en el centro.
class MesaFondo extends StatelessWidget {
  final Widget child;
  const MesaFondo({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.15),
          radius: 1.05,
          colors: [
            AppColors.fieltroClaro,
            AppColors.fieltroOscuro,
            AppColors.fondo,
          ],
          stops: [0.0, 0.62, 1.0],
        ),
      ),
      child: child,
    );
  }
}

/// Panel translucido para agrupar informacion sobre la mesa.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borde;
  final double radio;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.borde,
    this.radio = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.superficie.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: borde ?? AppColors.borde),
      ),
      child: child,
    );
  }
}

/// Fichas de victoria dibujadas como puntos: llenos los ganados.
class FichasPips extends StatelessWidget {
  final int ganadas;
  final int total;
  final double tamano;

  const FichasPips({
    super.key,
    required this.ganadas,
    required this.total,
    this.tamano = 9,
  });

  @override
  Widget build(BuildContext context) {
    final cuantas = total <= 0 ? ganadas : total;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(cuantas, (i) {
        final lograda = i < ganadas;
        return Container(
          width: tamano,
          height: tamano,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: lograda ? AppColors.acento : Colors.transparent,
            border: Border.all(
              color: lograda ? AppColors.acento : AppColors.textoTenue,
              width: 1.4,
            ),
          ),
        );
      }),
    );
  }
}

/// Etiqueta pequena en mayusculas para titulos de seccion.
class Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;
  const Etiqueta(this.texto, {super.key, this.color = AppColors.textoTenue});

  @override
  Widget build(BuildContext context) => Text(
        texto.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          color: color,
        ),
      );
}
