import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MagicTheme {
  // --- Colores Principales ---
  static const Color backgroundBlack = Color(0xFF05000A); // Negro casi absoluto
  static const Color deepPurple = Color(0xFF1A0B2E); // Fondo profundo
  static const Color mysticPurple = Color(0xFF4A148C); // Morado vibrante
  static const Color neonPurple = Color(0xFF9D4EDD); // Resplandor
  static const Color silver = Color(0xFFC7C7C7);
  static const Color placeholder = Color(0xFF777777);
  static const Color bloodRed = Color(0xFFB60010);
  static const Color arcaneBlue = Color(0xFF00C8FF); // brillo espectral azul

  // --- Colores Metálicos (Oro) ---
  static const Color goldDark = Color(0xFF8B6914);
  static const Color goldMain = Color(0xFFFFD700);
  static const Color goldLight = Color(0xFFFFEC8B);
  // --- Gradientes Predefinidos ---

  // Gradiente para el botón de joya
  static const LinearGradient gemGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xAA9D4EDD), // Neon Purple semi-transparente
      Color(0x66C77DFF), // Azul-morado mágico suave
      Color(0x22000000), // Negro muy tenue para dar profundidad
    ],
    stops: [0.0, 0.55, 1.0],
  );

  // Gradiente para el borde dorado
  static const LinearGradient goldBorderGradient = LinearGradient(
    colors: [goldDark, goldMain, goldLight, goldMain, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- Estilos de Texto ---

  static TextStyle get titleStyle => GoogleFonts.cinzel(
        // Fuente mágica/medieval
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: goldMain,
        shadows: [
          const Shadow(color: goldDark, blurRadius: 10, offset: Offset(0, 2)),
          const Shadow(
              color: Colors.black, blurRadius: 2, offset: Offset(1, 1)),
        ],
      );

  static TextStyle get labelStyle => GoogleFonts.cinzel(
        fontSize: 14,
        color: goldLight.withValues(alpha: 0.9),
        letterSpacing: 1.2,
      );

  static TextStyle get inputTextStyle => GoogleFonts.lato(
        fontSize: 14,
        color: Colors.white.withValues(alpha: 0.9),
      );

  // --- Social brand colors (exact ARGB constants) ---
  static const Color googleBlueLight = Color.fromARGB(255, 66, 133, 244);
  static const Color googleBlueDark = Color.fromARGB(255, 66, 133, 244);

  static const Color appleGrayLight = Color.fromARGB(255, 162, 170, 173);
  static const Color appleGrayDark = Color.fromARGB(255, 162, 170, 173);

  /// Helpers that return the exact ARGB values requested. These accept an
  /// optional BuildContext for compatibility with existing call sites but
  /// currently return the exact light variants (no adaptive shifting).
  static Color googleBlue([BuildContext? _]) => googleBlueLight;

  static Color appleGray([BuildContext? _]) => appleGrayLight;

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundBlack,
      primaryColor: mysticPurple,
      colorScheme: const ColorScheme.dark(
        primary: mysticPurple,
        secondary: silver,
        //surface: inputBackground,
        error: bloodRed,
        onSurface: silver,
      ),
    );
  }
}
