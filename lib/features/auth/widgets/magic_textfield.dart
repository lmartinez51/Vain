/// @file magic_textfield.dart
/// @brief A custom styled text input field matching the application's magical aesthetic.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'package:flutter/material.dart';
import '../../../theme/magic_theme.dart';

/// @brief A generic stylized text input field with deep purple backgrounds and glowing neon borders.
class MagicTextField extends StatelessWidget {
  final String labelText;
  final String hintText;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final void Function(String)? onChanged;

  /// @brief Initializes a new instance of [MagicTextField] with specific styling parameters.
  const MagicTextField({
    super.key,
    required this.labelText,
    required this.hintText,
    this.obscureText = false,
    this.suffixIcon,
    this.controller,
    this.validator,
    this.keyboardType,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  /// @brief Builds the stylized text field wrapped in glowing container decorations.
  /// @param context The current build context.
  /// @return The built [Widget].
  @override
  Widget build(BuildContext context) {
    return Container(
      // 1. EL CONTENEDOR ENVOLVENTE
      decoration: BoxDecoration(
        color: MagicTheme.deepPurple
            .withValues(alpha: 0.6), // Fondo semitransparente oscuro
        borderRadius: BorderRadius.circular(10),
        // 2. EL GLOW (Resplandor exterior)
        boxShadow: [
          BoxShadow(
            color: MagicTheme.neonPurple
                .withValues(alpha: 0.4), // Color de resplandor
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 0),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4), // Sombra de profundidad
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
        // 3. EL BORDE METÁLICO (Efecto 'marco')
        border: Border.all(
          color: MagicTheme.goldMain.withValues(alpha: 0.7),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4.0),

      // 4. EL CAMPO DE FORMULARIO REAL
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        textCapitalization: textCapitalization,
        style: MagicTheme.inputTextStyle, // Texto de entrada blanco
        cursorColor: MagicTheme.goldMain, // Cursor dorado
        onChanged: onChanged,
        decoration: InputDecoration(
          // Quitamos el borde nativo del input porque ya lo maneja el Container
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          filled: false, // Ya tenemos color en el contenedor padre
          contentPadding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 4.0),
          // Etiqueta (Email/Password) con estilo dorado
          labelText: labelText,
          labelStyle: MagicTheme.labelStyle,

          suffixIcon: suffixIcon,
          hintText: hintText,
          // Estilo del hint (opcional, si no hay valor)
          hintStyle: MagicTheme.inputTextStyle.copyWith(
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
