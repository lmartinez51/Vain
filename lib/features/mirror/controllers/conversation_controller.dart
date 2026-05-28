/// @file conversation_controller.dart
/// @brief Controller managing the orchestration between audio recording, playback, and the AI client.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:vain_app/features/mirror/controllers/audio_device_manager.dart';
import 'package:vain_app/features/mirror/services/audio_recorder_service.dart';
import 'package:vain_app/features/mirror/services/realtime_audio_player.dart';
import 'package:vain_app/features/mirror/services/realtime_conversation_client.dart';

/// @brief Represents the current interaction mode of the AI conversation.
enum ConversationState {
  idle,
  listening,
  speaking,
}

/// @brief Orchestrates realtime AI sessions by tying together audio I/O, network clients, and state logic.
class ConversationController extends ChangeNotifier {
  final RealtimeConversationClient _client;
  final AudioRecorderService _audioRecorder;
  final RealtimeAudioPlayer? _audioPlayer;
  final AudioDeviceManager? _audioDeviceManager;

  bool _shouldTransmit = true;
  int _turnSizeBytes = 0;
  DateTime? _assistantStartTime;
  DateTime? _lastBargeInIgnoreUntil;

  bool get isAssistantSpeaking => _state == ConversationState.speaking;
  bool get isActive => _state != ConversationState.idle;

  ConversationState _state = ConversationState.idle;
  ConversationState get state => _state;

  void Function(ConversationState state)? onStateChanged;
  void Function(Uint8List pcm)? onAssistantAudio;
  void Function(Map<String, dynamic> data)? onUserProfileUpdate;
  void Function(Object error)? onError;

  StreamSubscription<Uint8List>? _audioSubscription;

  // 🟢 AGREGAMOS ESTE GETTER para que la UI pueda acceder a la URL desde el controller
  String? get lastGeneratedImageUrl => _client.lastGeneratedImageUrl;

  bool _isGeneratingImage = false;
  bool get isGeneratingImage => _isGeneratingImage;

  /// @brief Initializes the controller with the required realtime AI client and hardware interfaces.
  ConversationController(
    this._client, {
    required AudioRecorderService audioRecorder,
    RealtimeAudioPlayer? audioPlayer,
    AudioDeviceManager? audioDeviceManager,
  })  : _audioRecorder = audioRecorder,
        _audioPlayer = audioPlayer,
        _audioDeviceManager = audioDeviceManager {
    _bindClientCallbacks();
    // 🟢 ESTE ES EL LISTENER:
    // Cuando el cliente llame a notifyListeners() (porque llegó la imagen),
    // este bloque se ejecutará y le dirá a la UI que se redibuje.
    _client.addListener(() {
      debugPrint(
          '[ConversationController] El cliente notificó un cambio (posible imagen)');
      notifyListeners();
    });
  }

  // ─────────────────────────────────────────────
  // CICLO DE VIDA
  // ─────────────────────────────────────────────

  /// @brief Bootstraps the audio hardware and delegates session start to the AI client.
  /// @param instructions The system prompt defining AI behavior.
  /// @param userPhotoPath Optional path to the user's base photo.
  /// @param isProfileComplete Indicates if the profile DNA is fully hydrated.
  /// @return A completed [Future] when the session becomes active.
  Future<void> startConversation(
      {String? instructions,
      String? userPhotoPath,
      bool isProfileComplete = true}) async {
    if (_state != ConversationState.idle) return;
    debugPrint(
        '[ConversationController] startConversation with userPhotoPath: $userPhotoPath, complete: $isProfileComplete');

    await _audioRecorder.init();
    await _audioPlayer?.start();
    await _client.startSession(
      instructions: instructions,
      userPhotoPath: userPhotoPath,
      isProfileComplete: isProfileComplete,
    );

    _shouldTransmit = true;
    _setState(ConversationState.listening);

    await _audioRecorder.start();

    _audioSubscription = _audioRecorder.audioStream.listen(
      (pcm) {
        if (_state != ConversationState.idle && _shouldTransmit) {
          _client.sendAudioChunk(pcm);
        }
      },
      onError: _handleError,
    );
  }

  /// @brief Halts the active AI session, stops audio pipelines, and clears buffering.
  /// @return A completed [Future] when resources are cleanly released.
  Future<void> stopConversation() async {
    if (_state == ConversationState.idle) return;

    await _audioSubscription?.cancel();
    _audioSubscription = null;

    await _audioRecorder.stop();
    await _audioPlayer?.stop();
    await _client.stopSession();

    _setState(ConversationState.idle);
  }

  /// @brief Purges audio subscriptions and cleanly closes hardware interfaces.
  @override
  void dispose() {
    _audioSubscription?.cancel();
    _client.dispose();
    _audioRecorder.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // CLIENT CALLBACKS
  // ─────────────────────────────────────────────

  /// @brief Wires up the underlying RealtimeConversationClient events to internal handlers.
  void _bindClientCallbacks() {
    _client.onAssistantAudio = (pcm) {
      _turnSizeBytes += pcm.length;
      _audioPlayer?.playChunk(pcm);
      onAssistantAudio?.call(pcm);
    };

    _client.onAssistantSpeakingStart = () async {
      final bool bargeInEnabled =
          _audioDeviceManager?.areHeadphonesConnected ?? false;

      _shouldTransmit = bargeInEnabled;
      _turnSizeBytes = 0;
      _assistantStartTime = DateTime.now();

      await _audioPlayer?.stop();
      await _audioPlayer?.start();

      _setState(ConversationState.speaking);

      if (bargeInEnabled) {
        debugPrint(
            '[ConversationController] Assistant started speaking. Barge-in ENABLED (Headphones detected).');
        _lastBargeInIgnoreUntil =
            DateTime.now().add(const Duration(milliseconds: 500));

        if (_isGeneratingImage) return;
        if (!_audioRecorder.isRecording) {
          await _audioRecorder.start();
        }
      } else {
        debugPrint(
            '[ConversationController] Assistant started speaking. Barge-in DISABLED (No headphones).');
      }
    };

    _client.onResponseCreated = () async {
      final bool bargeInEnabled =
          _audioDeviceManager?.areHeadphonesConnected ?? false;

      if (bargeInEnabled) {
        if (_isGeneratingImage) return;
        debugPrint(
            '[ConversationController] Response created → keeping mic active for barge-in');
        _shouldTransmit = true;
      } else {
        debugPrint('[ConversationController] Response created → stopping mic');
        _shouldTransmit = false;
        await _audioRecorder.stop();
      }
    };

    _client.onAssistantSpeakingEnd = () async {
      // 🟢 FIX: El candado va en la línea 1. Bloquea el cambio de estado.
      if (_isGeneratingImage) return;

      if (_state == ConversationState.idle) return;

      _setState(ConversationState.listening);

      final bool bargeInEnabled =
          _audioDeviceManager?.areHeadphonesConnected ?? false;
      final double audioDurationSec = _turnSizeBytes / 48000.0;
      final int elapsedMs = _assistantStartTime != null
          ? DateTime.now().difference(_assistantStartTime!).inMilliseconds
          : 0;

      final int remainingMs = (audioDurationSec * 1000).toInt() - elapsedMs;
      final int waitMs = (remainingMs > 0 ? remainingMs : 0) + 500;

      if (!bargeInEnabled) {
        await Future.delayed(Duration(milliseconds: waitMs));

        if (_state != ConversationState.idle && !_isGeneratingImage) {
          debugPrint('[ConversationController] Restarting mic');
          await _audioRecorder.start();
          _shouldTransmit = true;
        }
      } else {
        _shouldTransmit = true;
        debugPrint(
            '[ConversationController] Assistant speaking ended. Mic was already active.');
      }
    };

    _client.onUserSpeechStarted = () async {
      if (_isGeneratingImage) return; // 🟢 FIX
      if (_lastBargeInIgnoreUntil != null &&
          DateTime.now().isBefore(_lastBargeInIgnoreUntil!)) {
        return;
      }
      debugPrint('[ConversationController] User speech started (VAD)');
      _shouldTransmit = true;
      await _audioPlayer?.stop();
      _setState(ConversationState.listening);
    };

    _client.onUserSpeechStopped = () async {
      if (_isGeneratingImage) return; // 🟢 FIX
      debugPrint('[ConversationController] User speech stopped (VAD)');
      final bool bargeInEnabled =
          _audioDeviceManager?.areHeadphonesConnected ?? false;

      if (bargeInEnabled) {
        _shouldTransmit = true;
      } else {
        _shouldTransmit = false;
        await _audioRecorder.stop();
      }
    };

    _client.onUserTranscript = (transcript) {
      debugPrint('[USER]: $transcript');
    };

    _client.onAssistantTranscript = (transcript) {
      debugPrint('[ASSISTANT]: $transcript');
    };

    _client.onUserProfileUpdate = (data) {
      debugPrint('[ConversationController] Profile update received from AI');
      onUserProfileUpdate?.call(data);
    };

    _client.onImageGenerationStarted = () async {
      debugPrint('[ConversationController] Image Generation Started');
      _shouldTransmit = false;
      await _audioRecorder.stop();
      _isGeneratingImage = true;
      notifyListeners();
    };

    _client.onImageGenerationCompleted = () async {
      debugPrint('[ConversationController] Image Generation Completed');
      _isGeneratingImage = false;

      if (_state != ConversationState.idle) {
        // 🟢 FIX: Restaurar visualmente a 'Escuchando...'
        _setState(ConversationState.listening);

        final bool bargeInEnabled =
            _audioDeviceManager?.areHeadphonesConnected ?? false;
        if (!bargeInEnabled) {
          await _audioRecorder.start();
        }
        _shouldTransmit = true;
      } else {
        notifyListeners();
      }
    };

    _client.onError = _handleError;
  }

  void _handleError(Object error) {
    _audioSubscription?.cancel();
    _audioSubscription = null;
    _setState(ConversationState.idle);
    onError?.call(error);
  }

  void _setState(ConversationState newState) {
    if (_state == newState) return;
    _state = newState;
    onStateChanged?.call(_state);
    notifyListeners();
  }
}
