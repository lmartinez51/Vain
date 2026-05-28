/// @file user_provider.dart
/// @brief State management provider responsible for orchestrating Firestore user records and synchronization.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vain_app/features/auth/models/app_user.dart';

/// @brief A Provider managing the global reactive state of the authenticated AppUser against Firestore.
class UserProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool get isLoggedIn => _currentUser != null;

  // ---------------------------------------------------------
  // LOAD USER FROM FIRESTORE
  // ---------------------------------------------------------
  
  /// @brief Fetches a user document and maps it to [AppUser], managing UI loading states automatically.
  /// @param uid The Firebase Auth unique identifier to query.
  /// @return A completed [Future] once data is hydrated and listeners are notified.
  Future<void> loadUser(String uid) async {
    // 1. Evitar cargas dobles concurrentes
    if (_isLoading) return;

    try {
      _isLoading = true;
      notifyListeners();

      final doc = await _db.collection('users').doc(uid).get();

      if (!doc.exists) {
        debugPrint('⚠️ UserProvider: No user found for UID $uid');
        _currentUser = null;
        _isInitialized = true;
        _isLoading = false;
        notifyListeners();
        return;
      }

      _currentUser = AppUser.fromMap(doc.data()!);
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();

      debugPrint('👤 User loaded: ${_currentUser?.email}');
    } catch (e, st) {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error loading user: $e\n$st');
    }
  }

  /// @brief Manually toggles the initialization flag, mostly used for testing or error recovery states.
  /// @param value The target boolean initialization state.
  void setInitialized(bool value) {
    _isInitialized = value;
    notifyListeners();
  }

  // ---------------------------------------------------------
  // CLEAR USER FROM MEMORY
  // ---------------------------------------------------------
  
  /// @brief Purges the in-memory global AppUser, broadcasting the logout/cleanup state to listeners.
  void clearUser() {
    _currentUser = null;
    _isInitialized = true; // importante
    notifyListeners();
  }

  // ---------------------------------------------------------
  // UPDATE A SINGLE FIELD IN USER DOCUMENT
  // ---------------------------------------------------------
  
  /// @brief Executes a partial update on a specific key within the user's Firestore document.
  /// @param uid The target document index.
  /// @param field The dot-notated or literal string path corresponding to the Firestore field.
  /// @param value The value to apply, serialized suitably for Firebase.
  /// @return A completed [Future].
  Future<void> updateUserField(String uid, String field, dynamic value) async {
    try {
      await _db.collection('users').doc(uid).update({
        field: value,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      if (_currentUser != null) {
        final updatedMap = {
          ..._currentUser!.toMap(),
          field: value,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        };

        _currentUser = AppUser.fromMap(updatedMap);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error updating user field: $e');
    }
  }

  // ---------------------------------------------------------
  // REFRESH USER FROM DATABASE
  // ---------------------------------------------------------
  
  /// @brief Forces a hard refetch of the active user's document to sync out-of-band updates.
  /// @return A completed [Future] when the query completes.
  Future<void> refreshUser() async {
    if (_currentUser == null) return;
    await loadUser(_currentUser!.uid);
  }

  // ---------------------------------------------------------
  // SYNC PROFILE PREFERENCES
  // ---------------------------------------------------------
  
  /// @brief Specifically synchronizes the complex [ProfilePreferences] sub-map with Firestore.
  /// @param uid The parent user document.
  /// @param preferences The generated map matching the expected nested database schema.
  /// @return A completed [Future].
  Future<void> syncProfilePreferences(
      String uid, Map<String, dynamic> preferences) async {
    try {
      await _db.collection('users').doc(uid).update({
        'profilePreferences': preferences, // Nodo dedicado para Michelle
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Actualizamos el usuario local si es el mismo
      if (_currentUser != null && _currentUser!.uid == uid) {
        _currentUser = _currentUser!.copyWith(updatedAt: DateTime.now());
        notifyListeners();
      }
      debugPrint(
          '☁️ [UserProvider] Firestore sync: profilePreferences actualizado.');
    } catch (e) {
      debugPrint('❌ [UserProvider] Error syncProfilePreferences: $e');
    }
  }

  /// @brief Flips the user's root `isOnboardingComplete` flag, authorizing full application access.
  /// @param uid The target user id.
  /// @return A completed [Future].
  Future<void> completeOnboarding(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'isOnboardingComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ [UserProvider] Error completing onboarding: $e');
    }
  }
}
