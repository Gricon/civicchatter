import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/auth_error_handler.dart';

class AuthProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _init();
  }

  void _init() {
    _user = _supabase.auth.currentUser;
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      // Handle token refresh errors
      if (event == AuthChangeEvent.tokenRefreshed) {
        _user = data.session?.user;
      } else if (event == AuthChangeEvent.signedOut) {
        _user = null;
        _error = null;
      } else if (event == AuthChangeEvent.signedIn) {
        _user = data.session?.user;
        _error = null;
      } else {
        _user = data.session?.user;
      }

      notifyListeners();
    });

    // Handle session errors (like invalid refresh tokens)
    _validateSession();
  }

  Future<void> _validateSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        // Try to refresh the session to validate it
        await _supabase.auth.refreshSession();
      }
    } catch (e) {
      // If refresh fails, clear the session
      if (AuthErrorHandler.isRefreshTokenError(e)) {
        await _clearInvalidSession();
      }
    }
  }

  Future<void> _clearInvalidSession() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      // If signOut fails, manually clear the user
      _user = null;
      notifyListeners();
    }
  }

  Future<void> signIn(
      {required String username, required String password}) async {
    _setLoading(true);
    _error = null;

    try {
      // Check if username is email or handle
      final isEmail = username.contains('@');

      String? email = username;
      if (!isEmail) {
        // Look up email by handle
        final response = await _supabase
            .from('profiles_public')
            .select('id')
            .eq('handle', username.toLowerCase())
            .maybeSingle();

        if (response == null) {
          throw Exception('Handle not found');
        }

        // Get email from auth.users (need to use RPC or handle differently)
        // For now, we'll use a workaround
        final userResponse = await _supabase
            .from('profiles_private')
            .select('email')
            .eq('id', response['id'])
            .single();

        email = userResponse['email'] as String;
      }

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      _user = response.user;
      _error = null;
    } on AuthException catch (e) {
      // Handle specific auth errors
      if (e.message.contains('Invalid login credentials')) {
        _error = 'Invalid username or password';
      } else if (e.message.contains('Email not confirmed')) {
        _error = 'Please verify your email address';
      } else {
        _error = e.message;
      }
      rethrow;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String handle,
    required String name,
    String? phone,
    String? address,
    bool isPrivate = false,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      // Validate handle
      if (!_isValidHandle(handle)) {
        throw Exception('Handle must be 3+ characters (a-z, 0-9, _, -)');
      }

      // Check if handle is available
      final existing = await _supabase
          .from('profiles_public')
          .select('id')
          .eq('handle', handle.toLowerCase())
          .maybeSingle();

      if (existing != null) {
        throw Exception('Handle is already taken');
      }

      // Sign up
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'handle': handle.toLowerCase(),
          'phone': phone,
          'address': address,
          'is_private': isPrivate,
        },
      );

      if (response.user == null) {
        throw Exception('Sign up failed');
      }

      // Database trigger will automatically create profile records
      // Wait a moment for trigger to complete
      await Future.delayed(const Duration(milliseconds: 500));

      _user = response.user;
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _supabase.auth.signOut();
      _user = null;
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  bool _isValidHandle(String handle) {
    final regex = RegExp(r'^[a-z0-9_-]{3,}$');
    return regex.hasMatch(handle.toLowerCase());
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
