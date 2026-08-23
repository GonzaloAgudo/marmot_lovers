import 'package:shared_preferences/shared_preferences.dart';

/// Ajustes que se recuerdan entre partidas en este dispositivo.
class Preferencias {
  Preferencias._();

  static const _claveNombre = 'nombre_jugador';
  static const _claveAviso = 'aviso_turno';

  /// El último nombre con el que entraste a una sala, o `null` si nunca has
  /// puesto ninguno en este dispositivo.
  static Future<String?> nombreGuardado() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nombre = prefs.getString(_claveNombre)?.trim();
      return (nombre == null || nombre.isEmpty) ? null : nombre;
    } catch (_) {
      return null;
    }
  }

  /// Si hay que vibrar y dar un destello cuando te toca el turno.
  /// Está activado salvo que lo desactives.
  static Future<bool> avisoTurno() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_claveAviso) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> guardarAvisoTurno(bool activo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_claveAviso, activo);
    } catch (_) {}
  }

  /// Guarda el nombre para proponerlo la próxima vez.
  static Future<void> guardarNombre(String nombre) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claveNombre, limpio);
    } catch (_) {
      // Si no se puede guardar, simplemente no se recuerda.
    }
  }
}
