import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().signIn(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Login failed';

        // Parse error messages for better user feedback
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('handle not found')) {
          errorMessage =
              'Username not found. Please check your username or use email.';
        } else if (errorString.contains('invalid login credentials')) {
          errorMessage = 'Invalid username or password. Please try again.';
        } else if (errorString.contains('email not confirmed')) {
          errorMessage = 'Please verify your email address before logging in.';
        } else if (errorString.contains('network') ||
            errorString.contains('connection')) {
          errorMessage =
              'Network error. Please check your internet connection.';
        } else if (errorString.contains('timeout')) {
          errorMessage = 'Connection timeout. Please try again.';
        } else {
          errorMessage = 'Login failed: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  48, // padding
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.forum,
                    size: 80,
                    color: Color(0xFF002868),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Civic Chatter',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF002868),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to your account',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  CustomTextField(
                    controller: _usernameController,
                    label: 'Username or Email',
                    hint: 'yourhandle or you@example.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your username or email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: '••••••••',
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Sign In',
                    onPressed: _isLoading ? null : _handleLogin,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: 'Create Account',
                    onPressed: () => context.go('/signup'),
                    variant: ButtonVariant.outlined,
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => context.go('/debug'),
                    child: Text(
                      'Connection Issues? Run Debug Test',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
