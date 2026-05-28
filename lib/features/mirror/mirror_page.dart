/// @file mirror_page.dart
/// @brief Main interactive mirror interface combining camera feed, audio processing, and AI conversation.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vain_app/features/auth/controllers/auth_controller.dart';
import 'package:vain_app/features/auth/providers/user_provider.dart';
import 'package:vain_app/features/mirror/controllers/audio_device_manager.dart';
import 'package:vain_app/features/mirror/controllers/conversation_controller.dart';
import 'package:vain_app/features/mirror/prompts/prompt_manager.dart';
import 'package:vain_app/features/mirror/services/audio_recorder_service.dart';
import 'package:vain_app/features/mirror/services/openai_realtime_client.dart';
import 'package:vain_app/features/mirror/services/realtime_audio_player.dart';
import 'package:vain_app/features/mirror/widgets/mirror_video.dart';
import 'package:vain_app/features/profile/providers/profile_provider.dart';
import 'package:vain_app/theme/magic_theme.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

/// @brief A StatefulWidget representing the core Magic Mirror experience.
class MirrorPage extends StatefulWidget {
  const MirrorPage({super.key});

  @override
  State<MirrorPage> createState() => _MirrorPageState();
}

/// @brief State class for [MirrorPage], managing camera, real-time sessions, and UI animations.
class _MirrorPageState extends State<MirrorPage> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;

  ConversationController? _conversationController;
  bool _isInitialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeMirror();
  }

  /// @brief Initializes profile data, connects to the AI session, and sets up camera permissions.
  /// @return A completed [Future] when the mirror is ready or fails to load.
  Future<void> _initializeMirror() async {
    try {
      final profileProvider = context.read<ProfileProvider>();

      // 1. Hidratamos los datos (Primer intento)
      await profileProvider.loadProfile();

      // 🟡 Lógica de Reintento Simple (Evita ANR)
      // Si el photoPath es null, esperamos 2s para el sync de Firestore.
      if (profileProvider.profile.photoPath == null) {
        debugPrint(
            '[MirrorPage] Photo not found, waiting 2s for Firestore sync...');
        await Future.delayed(const Duration(seconds: 2));
        await profileProvider.loadProfile(force: true); // Un reintento simple
      }

      debugPrint(
          '✅ [MirrorPage] Perfil cargado. Foto lista: ${profileProvider.profile.photoPath}');

      // 2. Validación de seguridad para photoPath (Existencia física)
      final currentPhotoPath = profileProvider.profile.photoPath;
      final bool fileExists =
          currentPhotoPath != null && File(currentPhotoPath).existsSync();

      if (!fileExists) {
        debugPrint(
            '⚠️ [MirrorPage] Foto de perfil no encontrada en disco: $currentPhotoPath');
        debugPrint(
            '🔍 [MirrorPage] Profile Dump: ${profileProvider.profile.toString()}');

        if (mounted) {
          // 🛑 Manejo de Archivo Faltante: Limpiar estado y redirigir
          debugPrint(
              '🔄 [MirrorPage] Redirigiendo a ProfilePage para corregir...');

          // Limpiamos el path fantasma
          await profileProvider.setPhotoPath(null);

          // Redirigimos
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/profile',
              arguments:
                  'Your profile photo is missing. Please take a new one to continue.',
            );
          }
        }
        return;
      }

      // 3. Inicialización de componentes dependientes
      _conversationController = ConversationController(
        OpenAIRealtimeClient(),
        audioRecorder: AudioRecorderServiceImpl(),
        audioPlayer: RealtimePlayerImpl(),
        audioDeviceManager: AudioDeviceManager(),
      );

      // 🟢 BINDING: Escuchamos actualizaciones de perfil desde la IA
      _conversationController!.onUserProfileUpdate = (data) async {
        if (!mounted) return;
        debugPrint(
            '🪄 [MirrorPage] AI actualizó el perfil. Validando cambios...');

        final provider = context.read<ProfileProvider>();
        final userProvider = context.read<UserProvider>();

        // Obtenemos el UID directo del motor de Firebase
        final uid = FirebaseAuth.instance.currentUser?.uid ??
            userProvider.currentUser?.uid;

        if (uid != null) {
          // 🟢 Le pasamos TODA la responsabilidad al Provider.
          // Él hará el Diff Check y decidirá si llama a saveProfileHybrid o no.
          await provider.updateFromPreferences(
            data,
            uid: uid,
            userProvider: userProvider,
          );
        } else {
          debugPrint(
              '❌ [MirrorPage] ERROR: Usuario desconectado, no se pudo procesar la actualización.');
        }
      };

      // 4. Permisos y Cámara
      final granted = await _requestPermissions();
      if (!granted) {
        setState(
            () => _initError = 'Se requieren permisos de cámara y micrófono.');
        return;
      }

      await _initializeCamera();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Error initializing MirrorPage: $e');
      if (mounted) {
        setState(() => _initError = 'Error al inicializar el espejo: $e');
      }
    }
  }

  // ------------------------------------------------------------
  // APP LIFECYCLE
  // ------------------------------------------------------------

  /// @brief Handles application lifecycle transitions to manage camera and audio resources.
  /// @param state The current lifecycle state.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _disposeCamera();
        // Si la app se va a background, cerramos sesión explícitamente
        if (_conversationController != null &&
            _conversationController!.state != ConversationState.idle) {
          _conversationController!.stopConversation();
        }
        break;

      case AppLifecycleState.resumed:
        // 1. Verificar si el usuario sigue ahí
        if (FirebaseAuth.instance.currentUser == null) {
          Navigator.of(context).pushReplacementNamed('/login');
          return;
        }
        // 2. Si todo bien, reiniciar recursos
        _initializeCamera();
        break;

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  // ------------------------------------------------------------
  // PERMISSIONS & CAMERA
  // ------------------------------------------------------------

  /// @brief Prompts the user for camera and microphone permissions.
  /// @return A completed [Future] containing true if both are granted, false otherwise.
  Future<bool> _requestPermissions() async {
    final camStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    return camStatus.isGranted && micStatus.isGranted;
  }

  /// @brief Sets up the camera controller selecting the front-facing lens.
  /// @return A completed [Future] when the camera stream starts.
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  /// @brief Safely releases the camera controller resources.
  void _disposeCamera() {
    _controller?.dispose();
    _controller = null;
    _isCameraInitialized = false;
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  /// @brief Builds the magic mirror visual layout, overlaying UI on top of the camera preview.
  /// @param context The current build context.
  /// @return The built [Widget] scaffold.
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (_initError != null) {
      return _buildErrorState();
    }

    if (!_isInitialized || _conversationController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: MagicTheme.neonPurple),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _conversationController!,
        builder: (_, __) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // CAMARA
              if (_isCameraInitialized && _controller != null)
                _buildCameraPreview(size)
              else
                const Center(
                  child: CircularProgressIndicator(
                    color: MagicTheme.neonPurple,
                  ),
                ),

              const IgnorePointer(child: _MagicVignette()),
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: MagicTheme.goldMain.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                ),
              ),

              // GHOST / ORB
              if (_conversationController!.state != ConversationState.idle)
                const Positioned.fill(child: GhostVideoWindow()),

              if (_conversationController!.state != ConversationState.speaking)
                MichelleOrb(
                  state: _conversationController!.state,
                  onTap: _onOrbTapped,
                ),

              // UI SYSTEM
              SafeArea(
                minimum: const EdgeInsets.all(16.0),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: _SystemArtifactButton(
                        icon: Icons.settings,
                        onPressed: () {},
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: _SystemArtifactButton(
                        icon: Icons.logout_rounded,
                        isDestructive: true,
                        onPressed: () async {
                          final authController = context.read<AuthController>();

                          await authController.signOut();

                          if (!context.mounted) return;

                          Navigator.of(context)
                              .pushNamedAndRemoveUntil('/login', (_) => false);
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: _buildStatusBadge(),
                    ),
                    // BOTÓN DE VISTA PREVIA DE ESTILO
                    if (_conversationController!.lastGeneratedImageUrl != null)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          // Aumentamos a 180 para asegurar que siempre quede por encima del Orb
                          padding: const EdgeInsets.only(bottom: 180),
                          child: _StylePreviewArtifact(
                            imageUrl:
                                _conversationController!.lastGeneratedImageUrl!,
                            onPressed: () => _showStylePreview(
                                context,
                                _conversationController!
                                    .lastGeneratedImageUrl!),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_conversationController!.isGeneratingImage)
                Positioned.fill(
                  child: _buildLoadingOverlay(size),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: MagicTheme.neonPurple, size: 64),
              const SizedBox(height: 16),
              Text(
                _initError ?? 'Error desconocido',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed('/profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MagicTheme.neonPurple,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Volver al Perfil'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(Size size) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        width: size.width,
        height: size.height,
        color: Colors.black.withValues(alpha: 0.5),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: MagicTheme.neonPurple,
              ),
              SizedBox(height: 24),
              Text(
                "Michelle está diseñando tu look...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// @brief Invokes the native share dialogue to export the generated AI image.
  /// @param path The local file path to the image.
  /// @return A completed [Future] when the share operation concludes.
  Future<void> _shareImage(String path) async {
    try {
      final file = XFile(path);
      await Share.shareXFiles([file],
          text: 'Check out my new look styled by Michelle! ✨');
    } catch (e) {
      debugPrint('Error sharing image: $e');
    }
  }

  /// @brief Displays a modal dialog with the newly generated makeup/style preview.
  /// @param context The build context for the dialog.
  /// @param url The local file path to the generated image.
  void _showStylePreview(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: MagicTheme.goldMain, width: 2),
                  ),
                  child: Builder(builder: (context) {
                    final file = File(url);
                    if (!file.existsSync()) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(50.0),
                          child: Text('❌ Imagen no encontrada',
                              style: TextStyle(color: Colors.white)),
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        Image.file(
                          file,
                          fit: BoxFit.contain,
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: _SystemArtifactButton(
                            icon: Icons.share,
                            onPressed: () => _shareImage(url),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),
              _SystemArtifactButton(
                icon: Icons.close,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// @brief Handles interactions with the AI floating orb, toggling the conversation state.
  void _onOrbTapped() {
    final userProvider = context.read<UserProvider>();
    final profileProvider = context.read<ProfileProvider>();

    final appUser = userProvider.currentUser;
    final hasPhoto = profileProvider.profile.photoPath != null;

    debugPrint('[MirrorPage] Orb tapped');

    // 1. Generamos el prompt usando el modelo que mapeamos formalmente o un fallback
    final String prompt = (appUser != null)
        ? PromptManager.sessionInitPrompt(appUser, hasPhoto)
        : PromptManager.sessionInitPromptEmpty();

    final String? photoPath = profileProvider.profile.photoPath;
    debugPrint('[MirrorPage] photoPath: $photoPath');

    if (_conversationController == null) return;

    if (_conversationController!.state == ConversationState.idle) {
      _conversationController!.startConversation(
        instructions: prompt,
        userPhotoPath: photoPath,
        isProfileComplete: profileProvider.isLocalProfileComplete,
      );
    } else {
      _conversationController!.stopConversation();
    }
  }

  Widget _buildStatusBadge() {
    if (_conversationController == null || !_conversationController!.isActive) {
      return const SizedBox.shrink();
    }

    // 🟢 FIX: Ocultar etiqueta si está generando imagen
    if (_conversationController!.isGeneratingImage) {
      return const SizedBox.shrink();
    }

    final bool assistantSpeaking = _conversationController!.isAssistantSpeaking;

    final text = assistantSpeaking ? 'Hablando…' : 'Escuchando…';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  // ------------------------------------------------------------

  Widget _buildCameraPreview(Size screenSize) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(color: Colors.black);
    }

    final previewSize = _controller!.value.previewSize!;
    final orientation = MediaQuery.of(context).orientation;

    final renderWidth = orientation == Orientation.landscape
        ? previewSize.width
        : previewSize.height;

    final renderHeight = orientation == Orientation.landscape
        ? previewSize.height
        : previewSize.width;

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: renderWidth,
          height: renderHeight,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _conversationController?.dispose();
    _controller?.dispose();
    super.dispose();
  }
} // CIERRE AQUI de _MirrorPageState

// -----------------------------------------------------------
// WIDGETS DE DISEÑO "ENCHANTED REFLECTION"
// -----------------------------------------------------------

/// Crea el efecto de oscurecimiento en los bordes para dar profundidad
/// @brief A decorative widget applying a dark radial gradient to the camera feed borders.
class _MagicVignette extends StatelessWidget {
  const _MagicVignette();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.85, // Ajusta qué tan "cerrada" es la viñeta
          colors: [
            Colors.transparent, // Centro claro
            Colors.transparent,
            Color(0x9905000A), // Negro/Morado semitransparente en bordes
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

/// Botones superiores (Settings / Logout) con estilo de cristal
/// @brief A styled button representing a system or navigation action in the mirror UI.
class _SystemArtifactButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDestructive;

  const _SystemArtifactButton({
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: MagicTheme.deepPurple.withValues(alpha: 0.3), // Cristal oscuro
          shape: BoxShape.circle,
          border: Border.all(
            color: isDestructive
                ? MagicTheme.neonPurple.withValues(alpha: 0.5)
                : MagicTheme.goldMain.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDestructive
                  ? Colors.red.withValues(alpha: 0.1)
                  : MagicTheme.goldLight.withValues(alpha: 0.1),
              blurRadius: 8,
              spreadRadius: 0,
            )
          ],
        ),
        child: Icon(
          icon,
          color: isDestructive
              ? Colors.white.withValues(alpha: 0.9)
              : MagicTheme.goldMain,
          size: 20,
        ),
      ),
    );
  }
}

/// @brief A draggable, animated glowing orb representing the AI assistant's status.
class MichelleOrb extends StatefulWidget {
  final ConversationState state;
  final VoidCallback onTap;

  const MichelleOrb({
    super.key,
    required this.state,
    required this.onTap,
  });

  @override
  State<MichelleOrb> createState() => _MichelleOrbState();
}

class _MichelleOrbState extends State<MichelleOrb>
    with SingleTickerProviderStateMixin {
  Offset? _position;

  late final AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _configureAnimations();
    _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant MichelleOrb oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.state != widget.state) {
      _configureAnimations();
    }
  }

  void _configureAnimations() {
    switch (widget.state) {
      case ConversationState.idle:
        _pulseController.duration = const Duration(seconds: 3);
        _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(_curve);
        _glowAnimation = Tween<double>(begin: 0.3, end: 0.45).animate(_curve);
        break;

      case ConversationState.listening:
        _pulseController.duration = const Duration(milliseconds: 900);
        _scaleAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(_curve);
        _glowAnimation = Tween<double>(begin: 0.45, end: 0.7).animate(_curve);
        break;

      case ConversationState.speaking:
        // Nunca debería renderizarse
        break;
    }
  }

  CurvedAnimation get _curve =>
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Seguridad extra
    if (widget.state == ConversationState.speaking) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;
    _position ??= Offset(size.width / 2 - 35, size.height - 150);

    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              _position!.dx + details.delta.dx,
              _position!.dy + details.delta.dy,
            );
          });
        },
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (_, __) {
              return Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      MagicTheme.neonPurple.withValues(alpha: 0.6),
                      MagicTheme.goldMain.withValues(alpha: 0.35),
                      MagicTheme.neonPurple.withValues(alpha: 0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: MagicTheme.neonPurple
                          .withValues(alpha: _glowAnimation.value),
                      blurRadius: 25,
                      spreadRadius: 6,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: const Center(
                      child: Icon(
                        Icons.auto_awesome,
                        color: Colors.white70,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// @brief A stylized glowing button to open the image style generation preview.
class _StylePreviewArtifact extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onPressed;

  const _StylePreviewArtifact(
      {required this.imageUrl, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: MagicTheme.neonPurple.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: MagicTheme.arcaneBlue.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome,
                color: MagicTheme.goldMain, size: 20),
            const SizedBox(width: 10),
            Text(
              "VER MI LOOK",
              style: MagicTheme.labelStyle.copyWith(
                color: Colors.white,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
