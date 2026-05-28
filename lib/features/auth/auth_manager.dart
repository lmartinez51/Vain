/// @file auth_manager.dart
/// @brief Core service wrapping Firebase Authentication operations and Firestore auto-provisioning.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vain_app/features/auth/models/profile_preferences.dart';

import 'providers/user_provider.dart';
import 'models/app_user.dart';
import 'models/auth_result.dart';

/// @brief Contains low-level authentication logic, interfacing directly with Firebase APIs.
class AuthManager {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final UserProvider userProvider;
  final String? serverClientId;

  AuthManager({required this.userProvider, this.serverClientId});

  // ---------------------------------------------------------
  //  GOOGLE SIGN-IN
  // ---------------------------------------------------------
  
  /// @brief Executes the OAuth Google Sign-In flow using native popup parameters.
  /// @return A completed [Future] yielding the [AuthResult].
  Future<AuthResult> signInWithGoogle() async {
    try {
      debugPrint('🔄 Starting Google Sign-In...');

      final GoogleAuthProvider googleProvider = GoogleAuthProvider();

      // Optional scopes
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      googleProvider.setCustomParameters({
        'prompt': 'select_account',
      });

      final credential = await _auth.signInWithProvider(googleProvider);
      final user = credential.user;

      if (user == null) {
        return AuthResult.fail(
          message: 'Google sign-in failed: Firebase returned null user',
        );
      }

      //debugPrint('✓ Firebase user authenticated: ${user.email}');
      debugPrint('✓ Firebase user: ${user.displayName}');

      // Create Firestore doc if new user
      await _createOrUpdateUserDocument(user);

      // Load profile
      await userProvider.loadUser(user.uid);

      return AuthResult.ok(
        message:
            'Google sign-in successful: ${user.displayName ?? ''} (${user.email ?? ''})',
        uid: user.uid,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(
        message: e.message,
        code: e.code,
      );
    } catch (e) {
      return AuthResult.fail(message: 'Unknown error: $e');
    }
  }

  // ---------------------------------------------------------
  //  EMAIL + PASSWORD SIGN-IN
  // ---------------------------------------------------------
  
  /// @brief Executes a standard email and password authentication attempt against Firebase.
  /// @param email The target user email.
  /// @param password The target user password.
  /// @return A completed [Future] yielding the [AuthResult].
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return AuthResult.fail(message: 'Email login failed.');
      }
      debugPrint('✓ Firebase user logged in: ${user.displayName}');
      await userProvider.loadUser(user.uid);
      return AuthResult.ok(message: 'Welcome back!', uid: user.uid);
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(message: e.message, code: e.code);
    } catch (e) {
      return AuthResult.fail(message: 'Unknown error: $e');
    }
  }

  // ---------------------------------------------------------
  //  CREATE ACCOUNT (EMAIL)
  // ---------------------------------------------------------
  
  /// @brief Pre-registers a new user in Firebase Auth and establishes their Firestore document.
  /// @param email The new user's email.
  /// @param password The new user's password.
  /// @return A completed [Future] yielding the [AuthResult].
  Future<AuthResult> createAccountWithEmail(
      String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      final user = credential.user;
      if (user == null) {
        return AuthResult.fail(message: 'Could not create user.');
      }

      await _createOrUpdateUserDocument(user);
      await userProvider.loadUser(user.uid);

      return AuthResult.ok(
          message: 'Account created successfully.', uid: user.uid);
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(message: e.message, code: e.code);
    } catch (e) {
      return AuthResult.fail(message: 'Unknown error: $e');
    }
  }

  // ---------------------------------------------------------
  //  SEND PASSWORD RESET
  // ---------------------------------------------------------
  
  /// @brief Requests a Firebase Auth password reset email for the given address.
  /// @param email The target email address.
  /// @return A completed [Future] yielding the [AuthResult].
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);

      return AuthResult.ok(message: 'Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(message: e.message, code: e.code);
    } catch (e) {
      return AuthResult.fail(message: 'Unknown error: $e');
    }
  }

  // ---------------------------------------------------------
  //  DELETE ACCOUNT
  // ---------------------------------------------------------
  
  /// @brief Permanently destroys the user's Firestore record and Firebase Auth instance. Requires recent authentication.
  /// @return A completed [Future] yielding the [AuthResult].
  Future<AuthResult> deleteAccount() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return AuthResult.fail(message: 'No user is currently signed in.');
      }

      final uid = user.uid;

      // Delete Firestore profile
      await _db.collection('users').doc(uid).delete();

      // Delete FirebaseAuth account
      await user.delete();

      // Clear provider
      userProvider.clearUser();

      return AuthResult.ok(message: 'Account deleted successfully.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return AuthResult.fail(
          message: 'Please reauthenticate before deleting your account.',
          code: e.code,
        );
      }
      return AuthResult.fail(message: e.message, code: e.code);
    } catch (e) {
      return AuthResult.fail(message: 'Unknown error: $e');
    }
  }

  // ---------------------------------------------------------
  //  SIGN OUT
  // ---------------------------------------------------------
  
  /// @brief Invalidates the local Firebase Auth session.
  /// @return A completed [Future].
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      userProvider.clearUser();
    } catch (e) {
      debugPrint('Error during signOut: $e');
    }
  }

  // ---------------------------------------------------------
  //  CREATE PROFILE DOC IN FIRESTORE
  // ---------------------------------------------------------
  
  /// @brief Synchronizes a [FirebaseAuth] instance with an [AppUser] Firestore document, handling creation or delta updates.
  /// @param user The authenticated Firebase user payload.
  /// @return A completed [Future] once Firestore acknowledges the write.
  Future<void> _createOrUpdateUserDocument(User user) async {
    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();

    final now = DateTime.now();

    // Datos provenientes de FirebaseAuth
    final String? displayName = user.displayName;
    final String? photo = user.photoURL;
    final String email = user.email ?? "";

    if (!doc.exists) {
      // ---------------------------------------------------------
      // USER DOES NOT EXIST → CREATE NEW DOCUMENT
      // ---------------------------------------------------------
      final newUser = AppUser(
        uid: user.uid,
        email: email,
        name: displayName,
        // Inicializamos el nickname con el primer nombre del displayName o el displayName completo
        nickname: displayName?.split(' ').first,
        photoUrls: photo != null ? [photo] : [],
        interests: [],
        personalBackground: null,
        gender: null,
        createdAt: now,
        updatedAt: now,
        profilePreferences: ProfilePreferences.empty(),
      );

      await docRef.set(newUser.toMap());
      debugPrint("📌 New user created in Firestore: ${user.uid}");
    } else {
      // ---------------------------------------------------------
      // USER EXISTS → UPDATE ONLY BASIC FIELDS
      // ---------------------------------------------------------
      final existing = AppUser.fromMap(doc.data()!);

      final updated = existing.copyWith(
        name: displayName ?? existing.name,
        // No sobreescribimos el nickname si ya existe, ya que el usuario pudo haberlo personalizado
        nickname: existing.nickname ?? displayName?.split(' ').first,
        photoUrls: photo != null
            ? [photo, ...existing.photoUrls.take(2)]
            : existing.photoUrls,
        updatedAt: now,
      );

      await docRef.update(updated.toMap());
      debugPrint("🔄 Firestore user updated: ${user.uid}");
    }
  }
}
