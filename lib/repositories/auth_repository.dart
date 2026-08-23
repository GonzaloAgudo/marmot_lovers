import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  /// Valor que devuelven los métodos de login cuando el usuario cierra el
  /// diálogo de Google. No es un error: la pantalla no muestra nada.
  static const String cancelado = '__cancelado__';

  /// Solo hace falta en iOS/macOS, y únicamente si no se ha puesto la clave
  /// `GIDClientID` en `ios/Runner/Info.plist`. En Android y web se deja en
  /// `null`: Android lo saca de `google-services.json` y la web usa el popup
  /// de Firebase.
  static const String? _clientIdIos = null;

  /// Igual que el anterior: en Android sale de `google-services.json` siempre
  /// que ese archivo tenga un `oauth_client` de tipo 3 (cliente web).
  static const String? _serverClientId = null;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// `initialize` de google_sign_in debe llamarse una sola vez en toda la
  /// app, no una por instancia: por eso es estatico.
  static bool _googleIniciado = false;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get usuarioActual => _auth.currentUser;

  /// Nombre que se propone en el lobby: el de Google si lo hay, y si no la
  /// parte del correo anterior a la arroba.
  String get nombreSugerido {
    final u = _auth.currentUser;
    if (u == null) return '';
    final nombre = u.displayName?.trim();
    if (nombre != null && nombre.isNotEmpty) return nombre.split(' ').first;
    final correo = u.email;
    if (correo != null && correo.contains('@')) return correo.split('@').first;
    return '';
  }

  // ==========================================================
  // CORREO Y CONTRASENA
  // ==========================================================

  /// Devuelve `null` si va bien, o el mensaje de error para el usuario.
  Future<String?> registrarConCorreo(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _mensaje(e);
    } catch (e) {
      return 'No se pudo crear la cuenta: $e';
    }
  }

  /// Devuelve `null` si va bien, o el mensaje de error para el usuario.
  Future<String?> loginConCorreo(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _mensaje(e);
    } catch (e) {
      return 'No se pudo iniciar sesion: $e';
    }
  }

  // ==========================================================
  // GOOGLE
  // ==========================================================

  /// Entra con Google.
  ///
  /// Devuelve `null` si va bien, [cancelado] si el usuario cierra el diálogo,
  /// o el mensaje de error.
  ///
  /// En web se usa el popup de Firebase, que no necesita configurar nada más
  /// que activar el proveedor. En móvil se usa `google_sign_in`, que pide el
  /// token de identidad a Google y se lo pasa a Firebase.
  Future<String?> loginConGoogle() async {
    try {
      if (kIsWeb) {
        await _auth.signInWithPopup(GoogleAuthProvider());
        return null;
      }

      await _prepararGoogle();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        return 'Este dispositivo no admite el acceso con Google';
      }

      final cuenta = await GoogleSignIn.instance.authenticate();
      final idToken = cuenta.authentication.idToken;

      if (idToken == null) {
        return 'Google no ha devuelto el token de identidad. Revisa que '
            'google-services.json tenga un cliente web (oauth_client de '
            'tipo 3).';
      }

      await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return null;
    } on GoogleSignInException catch (e) {
      return _mensajeGoogle(e);
    } on FirebaseAuthException catch (e) {
      return _mensaje(e);
    } on UnsupportedError {
      return 'Este dispositivo no admite el acceso con Google';
    } catch (e) {
      return 'No se pudo entrar con Google: $e';
    }
  }

  /// `initialize` hay que llamarlo una sola vez y esperar a que termine antes
  /// de usar cualquier otro método del paquete.
  Future<void> _prepararGoogle() async {
    if (_googleIniciado) return;
    await GoogleSignIn.instance.initialize(
      clientId: _clientIdIos,
      serverClientId: _serverClientId,
    );
    _googleIniciado = true;
  }

  // ==========================================================
  // SALIR
  // ==========================================================

  Future<void> cerrarSesion() async {
    if (!kIsWeb && _googleIniciado) {
      // Si no se cierra también en Google, la próxima vez entra solo con la
      // última cuenta sin dejar elegir.
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }

  // ==========================================================
  // MENSAJES DE ERROR
  // ==========================================================

  String _mensajeGoogle(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return cancelado;
      case GoogleSignInExceptionCode.interrupted:
        return 'Se ha interrumpido el acceso con Google, prueba otra vez';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Falta configurar el acceso con Google: activa el proveedor '
            'en Firebase, añade la huella SHA-1 y vuelve a descargar '
            'google-services.json';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google Play Services no esta disponible en este dispositivo';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'No se ha podido mostrar el dialogo de Google';
      case GoogleSignInExceptionCode.userMismatch:
        return 'La cuenta elegida no coincide con la esperada';
      case GoogleSignInExceptionCode.unknownError:
        return e.description ?? 'Error desconocido al entrar con Google';
    }
  }

  String _mensaje(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Ese correo no es valido';
      case 'email-already-in-use':
        return 'Ese correo ya tiene cuenta, inicia sesion';
      case 'weak-password':
        return 'La contrasena debe tener al menos 6 caracteres';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contrasena incorrectos';
      case 'account-exists-with-different-credential':
        return 'Ese correo ya tiene cuenta con otro metodo. Entra como lo '
            'hiciste la primera vez.';
      case 'network-request-failed':
        return 'Sin conexion a internet';
      case 'too-many-requests':
        return 'Demasiados intentos, prueba en un rato';
      case 'operation-not-allowed':
        return 'Activa este metodo de acceso en Firebase Authentication';
      // El usuario cierra el popup de Google en web.
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'user-cancelled':
      case 'web-context-canceled':
        return cancelado;
      case 'popup-blocked':
        return 'El navegador ha bloqueado la ventana de Google. Permitela y '
            'vuelve a intentarlo.';
      case 'unauthorized-domain':
        return 'Este dominio no esta autorizado en Firebase Authentication';
      default:
        return e.message ?? 'Error de autenticacion (${e.code})';
    }
  }
}
