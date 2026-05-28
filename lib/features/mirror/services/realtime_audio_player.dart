/// @file realtime_audio_player.dart
/// @brief Service for playing real-time PCM audio streams from AI models.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';

/// @brief Interface defining the contract for a real-time audio player.
abstract class RealtimeAudioPlayer {
  /// @brief Initializes and starts the audio playback engine.
  /// @return A completed [Future] when the player is ready.
  Future<void> start();
  /// @brief Queues a PCM audio chunk for playback.
  /// @param pcm The raw 16-bit PCM audio buffer.
  void playChunk(Uint8List pcm);
  /// @brief Stops the audio playback and clears buffers.
  /// @return A completed [Future] when playback is stopped.
  Future<void> stop();
  /// @brief Releases resources associated with the audio player.
  void dispose();
}

/// @brief Concrete implementation of [RealtimeAudioPlayer] using flutter_sound.
class RealtimePlayerImpl implements RealtimeAudioPlayer {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  StreamController<FoodData>? _audioStreamController;
  StreamSubscription<FoodData>?
      _audioSubscription; // 🟢 Control de fuga de memoria

  bool _isStarted = false;
  bool _isOpen = false;
  final List<Uint8List> _pendingChunks = [];
  bool _isInitializing = false;

  /// @brief Initializes the flutter_sound player and opens the PCM stream.
  /// @return A completed [Future] when the player is successfully started.
  @override
  Future<void> start() async {
    if (_isStarted || _isInitializing) return;
    _isInitializing = true;

    try {
      if (!_isOpen) {
        await _player.openPlayer();
        _isOpen = true;
      }

      _audioStreamController = StreamController<FoodData>();

      // 🟢 Suscripción segura
      _audioSubscription = _audioStreamController!.stream.listen((foodData) {
        // Solo inyectamos al C++ si seguimos "encendidos"
        if (_isStarted && _player.foodSink != null) {
          try {
            _player.foodSink!.add(foodData);
          } catch (e) {
            debugPrint('[Player] Sink add error: $e');
          }
        }
      });

      await _player.startPlayerFromStream(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 24000,
      );

      _isStarted = true;
      _isInitializing = false;

      // Inyectar chunks que llegaron mientras encendíamos
      if (_pendingChunks.isNotEmpty) {
        for (final chunk in _pendingChunks) {
          if (!_audioStreamController!.isClosed) {
            _audioStreamController!.add(FoodData(chunk));
          }
        }
        _pendingChunks.clear();
      }
    } catch (e) {
      _isInitializing = false;
      _isStarted = false;
      debugPrint('[Player] Error starting: $e');
    }
  }

  /// @brief Appends a PCM audio chunk to the playback stream, handling buffering if initializing.
  /// @param pcm The raw 16-bit PCM audio buffer.
  @override
  void playChunk(Uint8List pcm) {
    // 🟢 Doble candado: Que esté encendido y que el Stream no esté cerrado
    if (_isStarted &&
        _audioStreamController != null &&
        !_audioStreamController!.isClosed) {
      try {
        _audioStreamController!.add(FoodData(pcm));
      } catch (e) {
        debugPrint('[Player] Error adding chunk: $e');
      }
    } else if (_isInitializing) {
      _pendingChunks.add(pcm);
    }
  }

  /// @brief Immediately stops playback, clears pending chunks, and closes the stream.
  /// @return A completed [Future] when the player is completely stopped.
  @override
  Future<void> stop() async {
    // 🟢 CIERRE INMEDIATO: Bloquea nuevos bytes de OpenAI al instante
    _isStarted = false;
    _isInitializing = false;
    _pendingChunks.clear(); // Limpiamos basura de respuestas anteriores

    try {
      // Apagamos la escucha antes de destruir la tubería
      await _audioSubscription?.cancel();
      _audioSubscription = null;

      if (_audioStreamController != null && !_audioStreamController!.isClosed) {
        await _audioStreamController!.close();
      }
      _audioStreamController = null;

      // Detenemos el motor nativo sin retrasos artificiales
      if (_isOpen) {
        await _player.stopPlayer();
      }
    } catch (e) {
      debugPrint('[Player] Error stops: $e');
    }
  }

  /// @brief Closes the player instance and cancels active subscriptions.
  @override
  void dispose() {
    _isStarted = false;
    _audioSubscription?.cancel();
    _audioStreamController?.close();
    _player.closePlayer();
  }
}
