/// @file secure_storage_service.dart
/// @brief Provides a secure abstraction layer for persisting sensitive data locally.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vain_app/features/profile/models/user_profile.dart';

/// @brief A singleton wrapper around [FlutterSecureStorage] handling keystore operations safely across platforms.
class SecureStorageService {
  // Instancia única de FlutterSecureStorage
  final _storage = const FlutterSecureStorage();

  // --- Claves ---
  static const _apiKey = 'user_api_key';
  static const _profileCompletedKey = 'profile_completed';
  static const _profileKey = 'user_profile';

  // ─────────────────────────────
  // 👤 PERFIL
  // ─────────────────────────────

  /// @brief Serializes and securely stores the user's profile metadata.
  /// @param profile The [UserProfile] instance to save.
  /// @return A completed [Future] when the write finishes.
  Future<void> saveUserProfile(UserProfile profile) async {
    await _storage.write(
      key: _profileKey,
      value: profile.toJson(),
    );
  }

  /// @brief Retrieves and deserializes the securely stored user profile.
  /// @return A completed [Future] with the [UserProfile], or null if not found.
  Future<UserProfile?> readUserProfile() async {
    final json = await _storage.read(key: _profileKey);
    if (json == null) return null;
    return UserProfile.fromJson(json);
  }

  /// @brief Purges the stored user profile from the device secure storage.
  /// @return A completed [Future] upon successful deletion.
  Future<void> deleteUserProfile() async {
    await _storage.delete(key: _profileKey);
  }

  /// @brief Persists the user's onboarding completion status securely.
  /// @param completed True if the user has verified their profile setup.
  /// @return A completed [Future].
  Future<void> saveProfileCompleted(bool completed) async {
    await _storage.write(
      key: _profileCompletedKey,
      value: completed.toString(),
    );
  }

  /// @brief Checks if the user has already navigated the onboarding flow.
  /// @return A completed [Future] containing the boolean status.
  Future<bool> readProfileCompleted() async {
    final value = await _storage.read(key: _profileCompletedKey);
    return value == 'true';
  }

  /// @brief Clears the onboarding completion flag, typically used during logout or debug.
  /// @return A completed [Future].
  Future<void> deleteProfileCompleted() async {
    await _storage.delete(key: _profileCompletedKey);
  }

  // ─────────────────────────────
  // 🔑 API KEY (si decides usarlo)
  // ─────────────────────────────

  /// @brief Persists a sensitive API key to the keystore.
  /// @param key The string literal of the key to store.
  /// @return A completed [Future].
  Future<void> saveApiKey(String key) async {
    await _storage.write(key: _apiKey, value: key);
  }

  /// @brief Retrieves the stored API key from the secure vault.
  /// @return A completed [Future] containing the key or null.
  Future<String?> readApiKey() async {
    return await _storage.read(key: _apiKey);
  }

  /// @brief Removes the API key from secure storage to prevent unauthorized use across sessions.
  /// @return A completed [Future].
  Future<void> deleteApiKey() async {
    await _storage.delete(key: _apiKey);
  }
}
