import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Sign-up screen — mirrors login with an extra name field.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    await context.read<AuthProvider>().login(
          _nameCtrl.text.trim(),
          _emailCtrl.text.trim(),
        );
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Join TravelBuddy', style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Create your account to get started.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 40),
                TBInputField(
                  label: 'Full Name',
                  hint: 'Mansi Sharma',
                  controller: _nameCtrl,
                  validator: (v) => (v == null || v.isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 20),
                TBInputField(
                  label: 'Email Address',
                  hint: 'you@example.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                TBPrimaryButton(
                  label: 'Create Account',
                  isLoading: _loading,
                  onPressed: _signup,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
