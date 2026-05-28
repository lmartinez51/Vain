/// @file login_controller.dart
/// @brief Intermediary controller managing the UI state for login flows and communicating with the AuthController.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../models/auth_result.dart';

/// @brief UI-level controller that orchestrates form submissions, loading states, and error handling for authentication pages.
class LoginController extends ChangeNotifier {
  final AuthController authController;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  bool _disposed = false;

  // NOTA:
  // isSubmitting refleja DIRECTAMENTE el estado global del AuthController.
  bool get isSubmitting => authController.isLoading;

  LoginController({required this.authController}) {
    authController.addListener(_onAuthControllerChanged);
  }

  void _onAuthControllerChanged() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    authController.removeListener(_onAuthControllerChanged);
    super.dispose();
  }

  // ----------------------------
  //      GOOGLE SIGN IN
  // ----------------------------
  
  /// @brief Initiates the Google OAuth login flow and manages local error state.
  /// @return A completed [Future] containing the [AuthResult].
  Future<AuthResult> signInWithGoogle() async {
    _errorMessage = null;
    final result = await authController.signInWithGoogle();
    if (!result.success) _errorMessage = result.message;
    return result;
  }

  // ----------------------------
  //    EMAIL/PASSWORD LOGIN
  // ----------------------------
  
  /// @brief Authenticates a returning user with email and password credentials.
  /// @param email The user's registered email.
  /// @param password The user's secret password.
  /// @return A completed [Future] containing the [AuthResult].
  Future<AuthResult> signInWithEmail(String email, String password) async {
    _errorMessage = null;
    final result = await authController.signInWithEmail(email, password);
    if (!result.success) _errorMessage = result.message;
    return result;
  }

  // ----------------------------
  //      CREATE ACCOUNT
  // ----------------------------
  
  /// @brief Registers a new user account with Firebase authentication.
  /// @param email The new user's email.
  /// @param password The desired password.
  /// @return A completed [Future] containing the [AuthResult].
  Future<AuthResult> createAccount(String email, String password) async {
    _errorMessage = null;
    final result = await authController.createAccountWithEmail(email, password);
    if (!result.success) _errorMessage = result.message;
    return result;
  }

  // ----------------------------
  //      RESET PASSWORD
  // ----------------------------
  
  /// @brief Triggers a Firebase password reset email for the given address.
  /// @param email The email address associated with the account.
  /// @return A completed [Future] containing the [AuthResult].
  Future<AuthResult> resetPassword(String email) async {
    _errorMessage = null;
    final result = await authController.sendPasswordResetEmail(email);
    if (!result.success) _errorMessage = result.message;
    return result;
  }

  // ----------------------------
  //          LOGOUT
  // ----------------------------
  
  /// @brief Explicitly signs the user out and clears local UI state errors.
  /// @return A completed [Future].
  Future<void> signOut() async {
    clearError();
    await authController.signOut();
  }

  // ----------------------------
  //          CLEAR ERROR
  // ----------------------------
  
  /// @brief Manually clears the active error message and triggers a UI rebuild.
  /// @return A completed [Future].
  Future<void> clearError() async {
    _errorMessage = null;
    notifyListeners();
  }
}
