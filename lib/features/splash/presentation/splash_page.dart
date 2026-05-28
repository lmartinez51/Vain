/// @file splash_page.dart
/// @brief Displays the splash screen and routes the user based on authentication and onboarding status.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:vain_app/theme/magic_theme.dart';
import 'package:vain_app/features/auth/providers/user_provider.dart';

/// @brief A widget that displays the initial splash screen branding and resolves the next route.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

/// @brief State class for [SplashPage], handling animations and routing logic.
class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  /// @brief Initializes the entry animation and triggers the navigation resolution.
  @override
  void initState() {
    super.initState();

    // Controlador de animación de fade
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();

    // Ejecuta navegación después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveNavigation();
    });
  }

  /// @brief Disposes of the animation controller to prevent memory leaks.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// @brief Checks the user's authentication and onboarding status to determine the next destination.
  /// @return A completed [Future] when the navigation is resolved.
  Future<void> _resolveNavigation() async {
    // ⏱️ Animación/espera mínima para branding
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    final userProvider = context.read<UserProvider>();

    // 🕒 Esperar hasta que el estado de Auth esté resuelto
    // (Ya no usamos un while loop, sino una comprobación única
    // porque main.dart ya disparó la inicialización)
    if (!userProvider.isInitialized) {
      debugPrint('⏳ Splash: Esperando inicialización de UserProvider...');
      // Si por alguna razón tarda, podríamos re-intentar o mostrar error.
      // Aquí simplemente esperamos un poco más.
      int attempts = 0;
      while (!userProvider.isInitialized && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
    }

    if (!mounted) return;

    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      debugPrint('➡️ Splash: No user -> /login');
      _go('/login');
    } else if (!currentUser.isOnboardingComplete) {
      debugPrint('➡️ Splash: Profile incomplete -> /profile');
      _go('/profile');
    } else {
      debugPrint('➡️ Splash: All good -> /mirror');
      _go('/mirror');
    }
  }

  /// @brief Navigates to a new route, replacing the current one.
  /// @param route The named route definition.
  /// @param arguments Optional route arguments.
  void _go(String route, {Object? arguments}) {
    Navigator.of(context).pushReplacementNamed(
      route,
      arguments: arguments,
    );
  }

  /// @brief Builds the splash UI with a gradient background and a faded logo.
  /// @param context The current build context.
  /// @return The built [Widget].
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              MagicTheme.backgroundBlack,
              Color(0xFF1A0028),
              MagicTheme.neonPurple,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/vain_logo_transparent.png',
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(
                    'VAIN',
                    style: MagicTheme.titleStyle,
                  ),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(
                  strokeWidth: 3,
                  color: MagicTheme.neonPurple,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
