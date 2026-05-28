/// @file visual_brief.dart
/// @brief Data model for defining the visual parameters of AI image generation.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'package:flutter/foundation.dart';

/// @brief Represents the style instructions and technical constraints for AI image generation.
@immutable
class VisualBrief {
  /// @brief The user's skin type (e.g., Oily, Dry).
  final String? skinType;
  
  /// @brief The user's skin tone depth.
  final String? skinTone;
  
  /// @brief The underlying hue of the user's skin.
  final String? underTone;
  
  /// @brief The geometric shape of the user's face.
  final String faceShape;
  
  /// @brief The user's eye shape.
  final String? eyeShape;
  
  /// @brief List of prominent facial features to consider.
  final List<String> keyFeatures;
  
  /// @brief The event or context for the makeup look.
  final String occasion;
  
  /// @brief Aesthetic direction and makeup colors.
  final String makeupDirection;
  
  /// @brief Recommended hairstyle.
  final String hairDirection;
  
  /// @brief Style constraints to ensure realism.
  final List<String> styleConstraints;
  
  /// @brief Additional notes for the image generator.
  final String? optionalNotes;

  /// @brief Initializes a new instance of [VisualBrief].
  const VisualBrief({
    this.skinType,
    this.skinTone,
    this.underTone,
    required this.faceShape,
    this.eyeShape,
    required this.keyFeatures,
    required this.occasion,
    required this.makeupDirection,
    required this.hairDirection,
    required this.styleConstraints,
    this.optionalNotes,
  });

  /// @brief Throws an exception if any required properties are missing or empty.
  void validate() {
    if (faceShape.isEmpty) {
      throw Exception('faceShape no puede estar vacío');
    }
    if (keyFeatures.isEmpty) {
      throw Exception('keyFeatures no puede estar vacío');
    }
    if (occasion.isEmpty) {
      throw Exception('occasion no puede estar vacío');
    }
    if (makeupDirection.isEmpty) {
      throw Exception('makeupDirection no puede estar vacío');
    }
    if (hairDirection.isEmpty) {
      throw Exception('hairDirection no puede estar vacío');
    }
    if (styleConstraints.isEmpty) {
      throw Exception('styleConstraints no puede estar vacío');
    }
  }

  /// @brief Serializes the brief to a JSON map for API consumption.
  /// @return A JSON map representing the brief.
  Map<String, dynamic> toJson() => {
        if (skinType != null) 'skin_type': skinType,
        if (skinTone != null) 'skin_tone': skinTone,
        if (underTone != null) 'under_tone': underTone,
        'face_shape': faceShape,
        if (eyeShape != null) 'eye_shape': eyeShape,
        'key_features': keyFeatures,
        'occasion': occasion,
        'makeup_direction': makeupDirection,
        'hair_direction': hairDirection,
        'style_constraints': styleConstraints,
        if (optionalNotes != null) 'optional_notes': optionalNotes,
      };

  /// @brief Deserializes a [VisualBrief] instance from a JSON map.
  /// @param json The JSON map to parse.
  /// @return A completed [VisualBrief] instance.
  factory VisualBrief.fromJson(Map<String, dynamic> json) {
    return VisualBrief(
      skinType: json['skin_type'] as String?,
      skinTone: json['skin_tone'] as String?,
      underTone: json['under_tone'] as String?,
      faceShape: json['face_shape'] as String? ?? '',
      eyeShape: json['eye_shape'] as String?,
      keyFeatures:
          List<String>.from(json['key_features'] as List<dynamic>? ?? []),
      occasion: json['occasion'] as String? ?? '',
      makeupDirection: json['makeup_direction'] as String? ?? '',
      hairDirection: json['hair_direction'] as String? ?? '',
      styleConstraints:
          List<String>.from(json['style_constraints'] as List<dynamic>? ?? []),
      optionalNotes: json['optional_notes'] as String?,
    );
  }
}
