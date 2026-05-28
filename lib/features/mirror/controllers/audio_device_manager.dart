/// @file audio_device_manager.dart
/// @brief Manages detection and configuration of hardware audio devices (e.g., headphones).
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// @brief A ChangeNotifier class that monitors the availability and type of connected audio devices.
class AudioDeviceManager extends ChangeNotifier {
  bool _areHeadphonesConnected = false;

  bool get areHeadphonesConnected => _areHeadphonesConnected;

  /// @brief Initializes a new instance of [AudioDeviceManager] and starts device detection.
  AudioDeviceManager() {
    initialize();
  }

  /// @brief Initializes the audio session and sets up event listeners for hardware changes.
  /// @return A completed [Future] when the session is configured.
  Future<void> initialize() async {
    try {
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
        androidWillPauseWhenDucked: true,
      ));

      // Listen for changes in audio devices
      session.devicesChangedEventStream.listen((_) async {
        await _updateHeadphoneStatus(session);
      });

      // Initialize the current state
      await _updateHeadphoneStatus(session);
    } catch (e) {
      debugPrint('Error initializing AudioDeviceManager: $e');
    }
  }

  /// @brief Checks active routes to determine if headphones (wired or Bluetooth) are connected.
  /// @param session The active [AudioSession] instance.
  /// @return A completed [Future] once the status is evaluated and published.
  Future<void> _updateHeadphoneStatus(AudioSession session) async {
    try {
      final devices = await session.getDevices();
      final bool newStatus = devices.any((device) =>
          device.type == AudioDeviceType.wiredHeadset ||
          device.type == AudioDeviceType.wiredHeadphones ||
          device.type == AudioDeviceType.bluetoothA2dp);

      // Print detected device types
      for (var device in devices) {
        debugPrint('Detected device type: ${device.type}');
      }
      if (_areHeadphonesConnected != newStatus) {
        _areHeadphonesConnected = newStatus;
        debugPrint(
            'Are Headphones Connected updated: $_areHeadphonesConnected');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating headphone status: $e');
    }
  }

  /// @brief Forces a manual re-evaluation of the current headphone connection status.
  /// @return A completed [Future] after the check is performed.
  Future<void> checkHeadphoneStatus() async {
    try {
      final session = await AudioSession.instance;
      await _updateHeadphoneStatus(session);
    } catch (e) {
      debugPrint('Error checking headphone status: $e');
    }
  }

  /// @brief Cleans up listeners and resources tied to the device manager.
  @override
  void dispose() {
    // Clean up resources if needed
    super.dispose();
  }
}
