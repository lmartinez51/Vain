/// @file auth_controller.dart
/// @brief Highest-level authentication coordinator, managing state across auth, user, and profile domains.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'package:flutter/material.dart';
import 'package:vain_app/features/auth/auth_manager.dart';
import 'package:vain_app/features/auth/providers/user_provider.dart';
import 'package:vain_app/features/auth/models/auth_result.dart';
import 'package:vain_app/features/auth/services/secure_storage_service.dart';
import 'package:vain_app/features/profile/providers/profile_provider.dart';

/// @brief Orchestrator that binds Firebase Authentication with app-specific logic like syncing the [UserProvider].
class AuthController extends ChangeNotifier {
  final AuthManager authManager;
  final UserProvider userProvider;
  final ProfileProvider profileProvider;
  final SecureStorageService _storageService;

  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => userProvider.isLoggedIn;

  AuthController({
    required this.authManager,
    required this.userProvider,
    required this.profileProvider,
    required SecureStorageService storageService,
  }) : _storageService = storageService;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _setLoading(bool value) {
    if (_disposed) return;
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    if (_disposed) return;
    _errorMessage = message;
    notifyListeners();
  }

  // ----------------------------
  //      SIGN IN WITH GOOGLE
  // ----------------------------
  
  /// @brief Triggers the Google Sign-In flow and hydrates the user data upon success.
  /// @return A completed [Future] containing the [AuthResult].
  Future<AuthResult> signInWithGoogle() async {
    try {
      _setLoading(true);
      _setError(null);

      final result = await authManager.signInWithGoogle();

      if (!result.success) {
        _setError(result.message);
      } else {
        await userProvider.loadUser(result.uid!); // <-- FIX
      }

      return result;
    } catch (e) {
      _setError(e.toString());
      return AuthResult.fail(message: _errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // ----------------------------
  //    SIGN IN WITH EMAIL/PASS
  // ----------------------------
  
  /// @brief Authenticates via email/password and hydrates the target profile.
  /// @param email User's email address.
  /// @param password User's secret password.
  /// @return A completed [Future] containing the [AuthResult].
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      _setError(null);

      final result = await authManager.signInWithEmail(email, password);

      if (!result.success) {
        _setError(result.message);
      } else {
        await userProvider.loadUser(result.uid!); // <-- FIX
      }

      return result;
    } catch (e) {
      _setError(e.toString());
      return AuthResult.fail(message: _errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // ----------------------------
  //     CREATE ACCOUNT EMAIL
  // ----------------------------
  
  /// @brief Registers a new email account without performing immediate deep hydration.
  /// @param email The target email to register.
  /// @param password The target password.
  /// @return A completed [Future] containing the [AuthResult].
  Future<AuthResult> createAccountWithEmail(
      String email, String password) async {
    try {
      _setLoading(true);
      _setError(null);

      final result = await authManager.createAccountWithEmail(email, password);

      if (!result.success) {
        _setError(result.message);
      }

      return result;
    } catch (e) {
      _setError(e.toString());
      return AuthResult.fail(message: _errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // ----------------------------
  //     RESET PASSWORD
  // ----------------------------
  
  /// @brief Dispatches a password reset email via Firebase Auth.
  /// @param email The target address.
  /// @return A completed [Future] containing the [AuthResult].
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      _setLoading(true);
      _setError(null);

      final result = await authManager.sendPasswordResetEmail(email);

      if (!result.success) {
        _setError(result.message);
      }

      return result;
    } catch (e) {
      _setError(e.toString());
      return AuthResult.fail(message: _errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // ----------------------------
  //            LOGOUT
  // ----------------------------
  
  /// @brief Completes a global sign-out, clearing Firebase session, in-memory providers, and secure disk caches.
  /// @return A completed [Future] post-execution.
  Future<void> signOut() async {
    try {
      _setLoading(true);
      _setError(null);

      // 1️⃣ Firebase
      await authManager.signOut();

      // 2️⃣ Providers en memoria
      userProvider.clearUser();
      await profileProvider.clearProfile();

      // 3️⃣ Secure storage
      await _storageService.deleteUserProfile();
      await _storageService.deleteProfileCompleted();
    } catch (e, st) {
      debugPrint('❌ Error during signOut: $e\n$st');
    } finally {
      _setLoading(false);
    }
  }
}
