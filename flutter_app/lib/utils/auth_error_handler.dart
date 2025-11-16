import 'package:supabase_flutter/supabase_flutter.dart';

class AuthErrorHandler {
  static bool isAuthError(dynamic error) {
    if (error is AuthException) {
      return true;
    }

    final errorString = error.toString().toLowerCase();
    return errorString.contains('refresh token') ||
        errorString.contains('invalid token') ||
        errorString.contains('jwt') ||
        errorString.contains('unauthorized');
  }

  static bool isRefreshTokenError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('refresh token not found') ||
        errorString.contains('invalid refresh token');
  }

  static Future<void> handleAuthError(dynamic error) async {
    if (isRefreshTokenError(error)) {
      // Clear the invalid session
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        // Ignore signOut errors
      }
    }
  }

  static String getUserFriendlyMessage(dynamic error) {
    if (error is AuthException) {
      if (error.message.contains('Invalid login credentials')) {
        return 'Invalid username or password';
      } else if (error.message.contains('Email not confirmed')) {
        return 'Please verify your email address';
      } else if (error.message.contains('refresh token')) {
        return 'Your session has expired. Please sign in again.';
      }
      return error.message;
    }

    final errorString = error.toString();
    if (errorString.contains('Refresh Token Not Found') ||
        errorString.contains('Invalid Refresh Token')) {
      return 'Your session has expired. Please sign in again.';
    }

    return errorString;
  }
}
