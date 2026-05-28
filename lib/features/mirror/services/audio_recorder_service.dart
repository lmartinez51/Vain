/// @file audio_recorder_service.dart
/// @brief Service for recording audio from the device microphone in PCM16 format.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';

/// @brief Interface defining the contract for audio recording services.
abstract class AudioRecorderService {
  /// @brief Initializes the audio recording session and configures hardware permissions.
  /// @return A completed [Future] when initialization succeeds.
  Future<void> init();

  /// @brief Continuous stream of PCM16 (24kHz, mono) audio data.
  /// @return A broadcast stream emitting raw audio bytes.
  Stream<Uint8List> get audioStream;

  /// @brief Starts capturing audio from the microphone.
  /// @return A completed [Future] when recording begins.
  Future<void> start();

  /// @brief Stops the microphone capture.
  /// @return A completed [Future] when recording stops.
  Future<void> stop();

  /// @brief Indicates whether the microphone is currently active.
  /// @return True if actively recording.
  bool get isRecording;

  /// @brief Releases resources and hardware locks held by the recorder.
  /// @return A completed [Future] when resources are disposed.
  Future<void> dispose();

  /// @brief Clears the internal audio buffer without stopping the session.
  void resetBuffer();
}

/// @brief Concrete implementation of [AudioRecorderService] using flutter_sound and audio_session.
class AudioRecorderServiceImpl implements AudioRecorderService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  final StreamController<Uint8List> _audioController =
      StreamController<Uint8List>.broadcast();
  StreamSubscription? _recorderSubscription;

  bool _initialized = false;
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  // Buffer para evitar "tiny chunks" (OpenAI prefiere chunks de ~20-100ms)
  final List<int> _buffer = [];
  static const int _minChunkSize =
      1920; // ~40ms @ 24kHz PCM16 (24000 * 2 bytes * 0.04s)

  /// @brief Exposes the broadcast stream of captured audio chunks.
  /// @return A [Stream] of PCM audio buffers.
  @override
  Stream<Uint8List> get audioStream => _audioController.stream;

  // ─────────────────────────────────────────────
  // INIT - AHORA CON CONFIGURACIÓN DE AUDIO SESSION
  // ─────────────────────────────────────────────
  /// @brief Configures the iOS/Android audio session and opens the recorder.
  /// @return A completed [Future] when hardware configuration finishes.
  @override
  Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. Configura la sesión de audio ANTES de abrir el recorder
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));

      // 2. Activa la sesión
      await session.setActive(true);

      // 3. Abre el recorder
      await _recorder.openRecorder();

      // 4. Obligatorio en Android
      _recorder.setSubscriptionDuration(
        const Duration(milliseconds: 20),
      );

      _initialized = true;
      debugPrint('[AudioRecorder] Initialized with voice communication mode');
    } catch (e) {
      debugPrint('[AudioRecorder] Error during initialization: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // START MIC
  // ─────────────────────────────────────────────
  /// @brief Starts recording and continuously pushes buffered PCM data to the stream.
  /// @return A completed [Future] when the recording engine starts.
  @override
  Future<void> start() async {
    if (!_initialized) {
      throw StateError('AudioRecorderService not initialized');
    }

    if (_isRecording) {
      await stop();
    }

    _buffer.clear();
    final recordingController = StreamController<Uint8List>();

    _recorderSubscription = recordingController.stream.listen((data) {
      _buffer.addAll(data);

      if (_buffer.length >= _minChunkSize) {
        _audioController.add(Uint8List.fromList(_buffer));
        _buffer.clear();
      }
    });

    await _recorder.startRecorder(
      toStream: recordingController.sink,
      codec: Codec.pcm16,
      sampleRate: 24000,
      numChannels: 1,
      // audioSource removido - ahora lo maneja audio_session
    );

    _isRecording = true;
    debugPrint('[AudioRecorder] Recording started with buffering enabled');
  }

  // ─────────────────────────────────────────────
  // STOP MIC
  // ─────────────────────────────────────────────
  /// @brief Synchronously stops recording and flushes any remaining buffer to the stream.
  /// @return A completed [Future] when recording halts.
  @override
  Future<void> stop() async {
    if (!_isRecording) return;

    await _recorder.stopRecorder();
    await _recorderSubscription?.cancel();
    _recorderSubscription = null;

    // Flush buffer restante
    if (_buffer.isNotEmpty) {
      _audioController.add(Uint8List.fromList(_buffer));
      _buffer.clear();
    }

    _isRecording = false;
    debugPrint('[AudioRecorder] Recording stopped');
  }

  // ─────────────────────────────────────────────
  // DISPOSE - AHORA DESACTIVA LA SESIÓN
  // ─────────────────────────────────────────────
  /// @brief Completely deactivates the audio session and closes the recorder to free memory.
  /// @return A completed [Future] upon successful disposal.
  @override
  Future<void> dispose() async {
    try {
      if (_isRecording) {
        await stop();
      }

      await _recorder.closeRecorder();
      await _audioController.close();

      // Desactiva la sesión de audio
      final session = await AudioSession.instance;
      await session.setActive(false);

      _initialized = false;
      debugPrint('[AudioRecorder] Disposed and audio session deactivated');
    } catch (e) {
      debugPrint('[AudioRecorder] Error during dispose: $e');
      // Nada: dispose no debe reventar la app
    }
  }

  /// @brief Instantly empties the internal audio accumulation buffer.
  @override
  void resetBuffer() {
    _buffer.clear();
    debugPrint('[AudioRecorder] Buffer reset');
  }
}
