/// @file auth_result.dart
/// @brief Generic result wrapper for authentication operations.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

/// @brief Encapsulates the outcome of an authentication request, including status and payloads.
class AuthResult {
  final bool success;
  final String? message;
  final String? code;
  final String? uid;

  /// @brief Initializes an explicit outcome state for an auth operation.
  AuthResult({
    required this.success,
    this.message,
    this.code,
    this.uid,
  });

  /// @brief Factory creating a successful authorization result.
  /// @param message Optional success message.
  /// @param uid The authenticated user ID.
  /// @return A successful [AuthResult].
  factory AuthResult.ok({String? message, String? uid}) {
    return AuthResult(success: true, message: message, uid: uid);
  }

  /// @brief Factory creating a failed authorization result.
  /// @param message The user-facing error message.
  /// @param code The system error code.
  /// @return A failed [AuthResult].
  factory AuthResult.fail({String? message, String? code}) {
    return AuthResult(success: false, message: message, code: code);
  }
}
