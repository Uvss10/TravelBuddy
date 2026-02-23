import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Login screen with email/password form and validation.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _namCtrl  = TextEditingController();
  final _mailCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _namCtrl.dispose();
    _mailCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    // Simulate network delay (replace with real auth)
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    await context.read<AuthProvider>().login(
          _namCtrl.text.trim(),
          _mailCtrl.text.trim(),
        );
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text('Welcome back 👋', style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue planning your adventures.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 40),
                TBInputField(
                  label: 'Full Name',
                  hint: 'e.g. Mansi Sharma',
                  controller: _namCtrl,
                  validator: (v) => (v == null || v.isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 20),
                TBInputField(
                  label: 'Email Address',
                  hint: 'you@example.com',
                  controller: _mailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                TBPrimaryButton(
                  label: 'Sign In',
                  isLoading: _loading,
                  onPressed: _login,
                ),
                const SizedBox(height: 16),
                TBSecondaryButton(
                  label: 'Create Account',
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.signup),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'By continuing, you agree to our Terms & Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
