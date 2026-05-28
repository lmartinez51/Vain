/// @file profile_preferences.dart
/// @brief Data model encapsulating physical attributes and stylistic preferences for AI personalization.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

/// @brief Represents the physical DNA and makeup instructions attached to a user's profile.
class ProfilePreferences {
  final String? skinTone;
  final String? undertone;
  final String? skinType;
  final String? makeupStyle;
  final bool consentGiven;
  final String? faceShape;
  final String? eyeShape; // 🟢 NUEVO: Campo faltante
  final List<String> keyFeatures;
  final String? photoPath; // 🟢 NUEVO: Ruta persistida

  ProfilePreferences({
    this.skinTone,
    this.undertone,
    this.skinType,
    this.makeupStyle,
    this.consentGiven = false,
    this.faceShape,
    this.eyeShape,
    this.keyFeatures = const [],
    this.photoPath,
  });

  /// @brief Deserializes raw map data (e.g. from Firestore) into a structured [ProfilePreferences] object.
  /// @param map The source dictionary containing profile keys.
  /// @return A hydrated instance of [ProfilePreferences].
  factory ProfilePreferences.fromMap(Map<String, dynamic> map) {
    return ProfilePreferences(
      skinTone: map['skinTone'],
      undertone: map['undertone'],
      skinType: map['skinType'],
      makeupStyle: map['makeupStyle'],
      consentGiven: map['consentGiven'] ?? false,
      faceShape: map['faceShape'],
      eyeShape: map['eyeShape'],
      keyFeatures: map['keyFeatures']?.cast<String>() ?? [],
      photoPath: map['photoPath'],
    );
  }

  /// @brief Serializes the preferences instance into a map suitable for database storage.
  /// @return A key-value dictionary representing the object.
  Map<String, dynamic> toMap() {
    return {
      'skinTone': skinTone,
      'undertone': undertone,
      'skinType': skinType,
      'makeupStyle': makeupStyle,
      'consentGiven': consentGiven,
      'faceShape': faceShape,
      'eyeShape': eyeShape,
      'keyFeatures': keyFeatures,
      'photoPath': photoPath,
    };
  }

  /// @brief Generates an empty preferences schema with default baseline values.
  /// @return A blank [ProfilePreferences] instance.
  factory ProfilePreferences.empty() => ProfilePreferences();
}
