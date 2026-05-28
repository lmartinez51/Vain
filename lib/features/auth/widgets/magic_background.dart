/// @file magic_background.dart
/// @brief A global screen wrapper providing a stylized space/magic background.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'package:flutter/material.dart';
import '../../../theme/magic_theme.dart';

/// @brief A background widget applying a deep radial gradient and a safe-area respecting gold border.
class MagicBackground extends StatelessWidget {
  final Widget child;

  /// @brief Initializes a new instance of [MagicBackground] wrapping the provided [child].
  const MagicBackground({super.key, required this.child});

  /// @brief Builds the magical background layers beneath the wrapped child content.
  /// @param context The current build context.
  /// @return The built [Widget].
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      // 1. LA NEBULOSA (Sigue llenando TODA la pantalla, fondo absoluto)
      decoration: const BoxDecoration(
        color: MagicTheme.backgroundBlack,
        gradient: RadialGradient(
          center: Alignment(0.0, -0.3),
          radius: 1.5,
          colors: [
            Color(0xFF2E004F),
            MagicTheme.deepPurple,
            MagicTheme.backgroundBlack,
          ],
          stops: [0.0, 0.4, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // 2. EL MARCO DORADO (Ahora respeta el SafeArea)
          SafeArea(
            // maintainBottomViewPadding: true ayuda a evitar saltos raros en algunos Androids
            maintainBottomViewPadding: true,
            child: Container(
              margin: const EdgeInsets.all(12), // Margen adicional al SafeArea
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: MagicTheme.goldMain.withValues(alpha: 0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: MagicTheme.goldLight.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              // El gradiente oscuro interior para profundidad
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      MagicTheme.backgroundBlack.withValues(alpha: 0.4),
                    ],
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3. EL CONTENIDO (Login, Inputs, etc)
          // Usamos otro SafeArea para asegurar que los inputs no toquen los bordes del sistema
          SafeArea(child: child),
        ],
      ),
    );
  }
}
