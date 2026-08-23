import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart'; // Este archivo te lo genera FlutterFire CLI
import 'providers/style_provider.dart';
import 'repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StyleProvider()),
        // Añadimos el repositorio de autenticación
        Provider<AuthRepository>(create: (_) => AuthRepository()),
      ],
      child: const PowerHungryApp(),
    ),
  );
}

class PowerHungryApp extends StatelessWidget {
  const PowerHungryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepo = Provider.of<AuthRepository>(context, listen: false);

    return MaterialApp(
      title: 'Marmot Lovers',
      theme: AppTheme.oscuro,
      debugShowCheckedModeBanner: false,
      // Usamos el Stream del AuthRepository para saber qué pantalla mostrar
      home: StreamBuilder<User?>(
        stream: authRepo.authStateChanges,
        builder: (context, snapshot) {
          // Mientras Firebase comprueba si hay sesión guardada
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: MesaFondo(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.acento),
                ),
              ),
            );
          }
          // Si el usuario existe, va a Home, si no, va a Login
          if (snapshot.hasData) {
            return const HomeScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}