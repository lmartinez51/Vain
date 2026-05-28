import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:vain_app/features/auth/services/secure_storage_service.dart';
import 'package:vain_app/features/profile/providers/profile_provider.dart';
import 'package:vain_app/features/splash/presentation/splash_page.dart';
import 'package:vain_app/theme/magic_theme.dart';

import 'features/auth/presentation/login_page.dart';
import 'features/mirror/mirror_page.dart';
import 'features/profile/profile_page.dart';
import 'package:vain_app/features/profile/services/face_analysis_service.dart';

import 'features/auth/providers/user_provider.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/controllers/login_controller.dart';
import 'features/auth/auth_manager.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

/// 🔍 Route observer global
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Env
  await dotenv.load(fileName: ".env");

  // Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final secureStorage = SecureStorageService();
  final faceAnalysisService = FaceAnalysisService();
  final profileProvider = ProfileProvider(secureStorage, faceAnalysisService);
  final userProvider = UserProvider();

  // 🔐 Carga inicial de datos
  await profileProvider.loadProfile();

  // 🔐 Sincronización centralizada con FirebaseAuth
  // No llamamos a loadUser manualmente aquí; el listener se encargará
  // incluso del estado inicial (currentUser) al suscribirse.
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user == null) {
      debugPrint('👤 Auth State: No user (null)');
      userProvider.clearUser();
      // Opcional: Limpiar perfil también si se desea seguridad estricta
    } else {
      debugPrint('👤 Auth State: User detected (${user.uid})');
      await userProvider.loadUser(user.uid);

      // 🌉 TRICKLE DOWN: Una vez que UserProvider tiene la data de Firestore,
      // se la pasamos a ProfileProvider para que la persista localmente.
      if (userProvider.currentUser != null) {
        await profileProvider.updateFromPreferences(
            userProvider.currentUser!.profilePreferences);
      }
    }
  });

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: userProvider),
      ChangeNotifierProvider.value(value: profileProvider),
      Provider<AuthManager>(
        create: (_) => AuthManager(
          userProvider: userProvider,
        ),
      ),
      ChangeNotifierProvider<AuthController>(
        create: (context) => AuthController(
          authManager: context.read<AuthManager>(),
          userProvider: userProvider,
          profileProvider: profileProvider, // ✅ directo
          storageService: secureStorage,
        ),
      ),
      ChangeNotifierProvider<LoginController>(
        create: (context) => LoginController(
          authController: context.read<AuthController>(),
        ),
      ),
    ],
    child: const VainApp(),
  ));
}

class VainApp extends StatelessWidget {
  const VainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAIN',
      debugShowCheckedModeBanner: false,
      theme: MagicTheme.themeData,
      navigatorObservers: [routeObserver],
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashPage(),
        '/login': (context) => const LoginPage(),
        '/profile': (context) => const ProfilePage(),
        '/mirror': (context) => const MirrorPage(),
      },
    );
  }
}
