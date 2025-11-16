import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _handleController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isPrivate = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            handle: _handleController.text.trim().toLowerCase(),
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            address: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
            isPrivate: _isPrivate,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signup failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateHandle(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a handle';
    }
    final regex = RegExp(r'^[a-z0-9_-]{3,}$');
    if (!regex.hasMatch(value.toLowerCase())) {
      return 'Handle must be 3+ chars: a-z, 0-9, _, -';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomTextField(
                  controller: _nameController,
                  label: 'Name',
                  hint: 'Your name',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _handleController,
                  label: 'Handle (public @username)',
                  hint: 'e.g. conrad',
                  helperText: '3+ chars: a-z, 0-9, _ or -',
                  validator: _validateHandle,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _phoneController,
                  label: 'Phone (optional)',
                  hint: '+63...',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Create a password',
                  helperText: 'Minimum 6 characters',
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _addressController,
                  label: 'Address (optional)',
                  hint: 'Your address',
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Private account (not searchable)'),
                  value: _isPrivate,
                  onChanged: (value) {
                    setState(() => _isPrivate = value ?? false);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Create Account',
                  onPressed: _isLoading ? null : _handleSignup,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Back to Login',
                  onPressed: () => context.go('/login'),
                  variant: ButtonVariant.outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
