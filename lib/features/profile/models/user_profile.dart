/// @file user_profile.dart
/// @brief Defines the data model and enumerations for the user's profile and physical attributes.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'dart:convert';

/// @brief Enumeration of supported skin tones.
enum SkinTone {
  fair,
  medium,
  olive,
  deep,
}

/// @brief Enumeration of skin undertones.
enum Undertone {
  cool,
  neutral,
  warm,
}

/// @brief Enumeration of facial skin types.
enum SkinType {
  oily,
  dry,
  combination,
  sensitive,
  normal,
}

/// @brief Enumeration of preferred makeup styles.
enum MakeupStyle {
  natural,
  elegant,
  bold,
  glam,
}

/// @brief Enumeration of detected face shapes.
enum FaceShape {
  oval,
  round,
  square,
  heart,
  diamond,
  pear,
  long,
}

/// @brief Enumeration of detected eye shapes.
enum EyeShape {
  almond,
  hooded,
  downturned,
  round,
  monolid,
  upturned,
}

/// @brief Represents the comprehensive profile of a user, combining manual and AI-analyzed attributes.
class UserProfile {
  final SkinTone? skinTone;
  final Undertone? undertone;
  final SkinType? skinType;
  final MakeupStyle? makeupStyle;
  final String? photoPath;
  final FaceShape? faceShape;
  final EyeShape? eyeShape;
  final List<String> keyFeatures;
  final bool consentGiven;

  /// @brief Constructs a new [UserProfile] instance.
  const UserProfile({
    this.skinTone,
    this.undertone,
    this.skinType,
    this.makeupStyle,
    this.photoPath,
    this.faceShape,
    this.eyeShape,
    this.keyFeatures = const [],
    this.consentGiven = false,
  });

  // User feedback: Don't make technical fields mandatory for completion,
  // as they can be filled by AI.
  /// @brief Checks if the profile has the minimum required fields (photo and consent).
  /// @return True if mandatory fields are populated.
  bool get isComplete => photoPath != null && consentGiven == true;

  /// @brief Converts the profile to a [Map] structure suitable for serialization or Firestore.
  /// @return A map containing key-value representations of the fields.
  Map<String, dynamic> toMap() => {
        'skinTone': skinTone?.name,
        'undertone': undertone?.name,
        'skinType': skinType?.name,
        'makeupStyle': makeupStyle?.name,
        'photoPath': photoPath,
        'faceShape': faceShape?.name,
        'eyeShape': eyeShape?.name,
        'keyFeatures': keyFeatures,
        'consentGiven': consentGiven,
      };

  /// @brief Creates a [UserProfile] from a map, typically fetched from Firestore.
  /// @param map The source map of profile data.
  /// @return A populated [UserProfile] instance.
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      skinTone: map['skinTone'] != null
          ? _safeParseEnum(SkinTone.values, map['skinTone'])
          : null,
      undertone: map['undertone'] != null
          ? _safeParseEnum(Undertone.values, map['undertone'])
          : null,
      skinType: map['skinType'] != null
          ? _safeParseEnum(SkinType.values, map['skinType'])
          : null,
      makeupStyle: map['makeupStyle'] != null
          ? _safeParseEnum(MakeupStyle.values, map['makeupStyle'])
          : null,
      photoPath: map['photoPath'],
      faceShape: map['faceShape'] != null
          ? _safeParseEnum(FaceShape.values, map['faceShape'])
          : null,
      eyeShape: map['eyeShape'] != null
          ? _safeParseEnum(EyeShape.values, map['eyeShape'])
          : null,
      keyFeatures: map['keyFeatures'] != null
          ? List<String>.from(map['keyFeatures'])
          : const [],
      consentGiven: map['consentGiven'] ?? false,
    );
  }

  /// @brief Safely parses an enum value from its string name.
  /// @param values The list of valid enum values.
  /// @param name The string representation to match.
  /// @return The matched enum value, or null if parsing fails.
  static T? _safeParseEnum<T extends Enum>(List<T> values, String name) {
    try {
      return values.byName(name);
    } catch (_) {
      return null;
    }
  }

  /// @brief Serializes the profile to a JSON string.
  /// @return A JSON encoded string.
  String toJson() => jsonEncode(toMap());

  /// @brief Creates a copy of the profile with selectively updated fields.
  /// @param skinTone The new skin tone.
  /// @param undertone The new undertone.
  /// @param skinType The new skin type.
  /// @param makeupStyle The new makeup style.
  /// @param photoPath The new profile photo path.
  /// @param faceShape The new face shape.
  /// @param eyeShape The new eye shape.
  /// @param keyFeatures The new key features list.
  /// @param consentGiven The updated consent flag.
  /// @return A new [UserProfile] instance with the updated values.
  UserProfile copyWith({
    SkinTone? skinTone,
    Undertone? undertone,
    SkinType? skinType,
    MakeupStyle? makeupStyle,
    String? photoPath,
    FaceShape? faceShape,
    EyeShape? eyeShape,
    List<String>? keyFeatures,
    bool? consentGiven,
  }) {
    return UserProfile(
      skinTone: skinTone ?? this.skinTone,
      undertone: undertone ?? this.undertone,
      skinType: skinType ?? this.skinType,
      makeupStyle: makeupStyle ?? this.makeupStyle,
      photoPath: photoPath ?? this.photoPath,
      faceShape: faceShape ?? this.faceShape,
      eyeShape: eyeShape ?? this.eyeShape,
      keyFeatures: keyFeatures ?? this.keyFeatures,
      consentGiven: consentGiven ?? this.consentGiven,
    );
  }

  /// @brief Deserializes a [UserProfile] from a JSON string.
  /// @param json The JSON string to parse.
  /// @return A new [UserProfile] instance.
  factory UserProfile.fromJson(String json) =>
      UserProfile.fromMap(jsonDecode(json));
}
