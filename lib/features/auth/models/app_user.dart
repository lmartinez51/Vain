/// @file app_user.dart
/// @brief Data model representing an authenticated user and their metadata within the application.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vain_app/features/auth/models/profile_preferences.dart';

/// @brief Core user model containing authentication details, profile preferences, and application-specific metadata.
class AppUser {
  final String uid;
  final String email;
  final String? name; // Full name from Firebase
  final String? nickname; // Display name for AI context
  final List<String> photoUrls;
  final List<String> interests;
  final String? personalBackground;
  final String? gender;
  final bool isOnboardingComplete;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProfilePreferences profilePreferences;

  AppUser({
    required this.uid,
    required this.email,
    this.name,
    this.nickname,
    this.photoUrls = const [],
    this.interests = const [],
    this.personalBackground,
    this.gender,
    this.isOnboardingComplete = false,
    required this.createdAt,
    required this.updatedAt,
    required this.profilePreferences,
  });

  /// @brief Safely parses a dynamic value into a strictly typed [List<String>], avoiding Firebase schema mismatch errors.
  /// @param value The raw dynamic data from Firestore.
  /// @return A guaranteed valid list of strings.
  static List<String> _safeList(dynamic value) {
    if (value == null) return [];

    if (value is String) {
      // Firestore devolvió string donde debería ir lista
      return [value];
    }

    if (value is Iterable) {
      // Asegura que todos sean String
      return value.whereType<String>().toList();
    }

    return [];
  }

  /// @brief Instantiates an [AppUser] from a raw Firestore dictionary with resilient fallbacks.
  /// @param map The raw key-value mapping from the database.
  /// @return A strongly-typed [AppUser] instance.
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'],
      nickname: map['nickname'],
      photoUrls: _safeList(map['photoUrls']),
      interests: _safeList(map['interests']),
      personalBackground: map['personalBackground'],
      gender: map['gender'],
      isOnboardingComplete: map['isOnboardingComplete'] ?? false,
      // 🟢 MAPEADO DEL NODO DESDE FIRESTORE
      profilePreferences: map['profilePreferences'] != null
          ? ProfilePreferences.fromMap(
              Map<String, dynamic>.from(map['profilePreferences']))
          : ProfilePreferences.empty(),

      // Manejo seguro de timestamps
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
              DateTime.now(),

      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
              DateTime.now(),
    );
  }

  /// @brief Serializes the current user state into a Map suitable for Firestore writes.
  /// @return A dictionary representing the user document (excluding primary key/UID).
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'nickname': nickname,
      'photoUrls': photoUrls,
      'interests': interests,
      'personalBackground': personalBackground,
      'gender': gender,
      'isOnboardingComplete': isOnboardingComplete,
      'profilePreferences': profilePreferences.toMap(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// @brief Creates a cloned instance of the user with specific overridden properties.
  /// @return A new [AppUser] reflecting the updated state.
  AppUser copyWith({
    String? name,
    String? nickname,
    List<String>? photoUrls,
    List<String>? interests,
    String? personalBackground,
    String? gender,
    bool? isOnboardingComplete,
    DateTime? updatedAt,
    ProfilePreferences? profilePreferences,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      photoUrls: photoUrls ?? this.photoUrls,
      interests: interests ?? this.interests,
      personalBackground: personalBackground ?? this.personalBackground,
      gender: gender ?? this.gender,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
      profilePreferences: profilePreferences ?? this.profilePreferences,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
