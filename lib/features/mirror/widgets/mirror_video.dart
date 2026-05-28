/// @file mirror_video.dart
/// @brief Widget displaying the ghost video with a blurred background overlay for the AI mirror.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vain_app/theme/magic_theme.dart';

/// @brief A StatefulWidget displaying a looping video with customized blur masks for a mirror effect.
class GhostVideoWindow extends StatefulWidget {
  const GhostVideoWindow({super.key});

  @override
  State<GhostVideoWindow> createState() => _GhostVideoWindowState();
}

/// @brief State class for [GhostVideoWindow], managing the video controller and animation playback.
class _GhostVideoWindowState extends State<GhostVideoWindow> {
  late VideoPlayerController _controller;

  /// @brief Initializes the video controller, sets it to loop, and starts playback.
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      'assets/videos/GhostIdle.mp4',
    )
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.play();
        }
      });
  }

  /// @brief Disposes of the video controller to prevent memory leaks.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// @brief Builds the video container with shader masks and backdrop filters.
  /// @param context The current build context.
  /// @return The built [Widget].
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final boxWidth = screenWidth * 0.50;
    final boxHeight = screenHeight * 0.40;

    // ==========================================
    // 🎛️ TUS CONTROLES DE AJUSTE
    // ==========================================
    // 1. POSICIÓN (Centro de la cara)
    const Alignment facePosition = Alignment(0.0, -0.001);

    // 2. TAMAÑO GENERAL DEL ÓVALO (Zoom)
    const double clarityRadius = 0.40;

    // 3. FACTOR DE FORMA (Ancho/Alto)
    const double ovalWidthFactor = 1;

    // 4. INTENSIDAD DEL BLUR GLOBAL (Sigma X, Sigma Y)
    // Reducimos drásticamente para liberar CPU durante la conversación
    const double globalBlurSigma = 12.0;

    // 5. SUAVIDAD DEL BORDE
    // El 0.0 es el centro transparente, 0.4 es donde empieza el desvanecimiento.
    const List<double> blurTransitionStops = [0.0, 0.3, 1.0];

    // ==========================================

    return RepaintBoundary(
      child: Opacity(
        opacity: 0.95,
        child: Container(
          width: boxWidth,
          height: boxHeight,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // -----------------------------------------------------------
                // 🎥 CAPA 1: VIDEO BASE NÍTIDO (Siempre debajo, siempre visible)
                // -----------------------------------------------------------
                if (_controller.value.isInitialized)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  )
                else
                  const Center(
                      child: CircularProgressIndicator(
                          color: MagicTheme.neonPurple)),

                // Oscurecimiento suave (opcional)
                Container(color: Colors.black.withValues(alpha: 0.3)),

                // -----------------------------------------------------------
                // 🌫️ CAPA 2: BLUR MASKED (Crea la ventana de nitidez)
                // -----------------------------------------------------------
                // 1. Dibuja el óvalo transparente (la "ventana")
                Transform.scale(
                  scaleX: ovalWidthFactor, // Control de ancho/forma
                  scaleY: 1.0,
                  alignment: facePosition, // Control de posición
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return RadialGradient(
                        center: facePosition,
                        radius: clarityRadius, // Control de tamaño
                        colors: const [
                          Colors.transparent, // Centro: totalmente transparente
                          Colors.transparent,
                          Colors.black, // Borde: totalmente negro (opaco)
                        ],
                        // Invertimos el efecto: transparente en el centro, opaco en el borde
                        stops: blurTransitionStops,
                      ).createShader(rect);
                    },
                    // Esto crea una forma ovalada NEGRA con un agujero transparente en el centro.
                    blendMode: BlendMode.dstIn,
                    // 2. Aplica el blur a todo lo que está DETRÁS de esta máscara (Capa 1)
                    child: BackdropFilter(
                      // Aplicamos el BLUR fuerte AHORA
                      filter: ImageFilter.blur(
                        sigmaX: globalBlurSigma,
                        sigmaY: globalBlurSigma,
                      ),
                      // Necesitamos un Container opaco para que el BackdropFilter tenga un límite
                      // DIBUJAMOS UN CONTENEDOR BLANCO/NEGRO QUE SERÁ RECORTADO POR LA MÁSCARA NEGRA.
                      child: Container(color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
