import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../providers/auth_provider.dart';

/// Optional sign-in. Scanning, editing, OCR, and PDF creation all work
/// without an account — this screen is only reached from Settings for
/// users who want cloud backup. Google and email/password sign-in are
/// real (Firebase Auth, once a real project is configured — see the
/// README); Apple Sign-In needs Xcode capability/entitlement files this
/// environment can't generate, so it says so rather than pretending.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _showEmailForm = false;
  bool _isSignUp = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitGoogle(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithGoogle();
    if (!context.mounted) return;
    if (success) {
      context.pop();
    } else if (auth.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.lastError!)));
    }
  }

  Future<void> _submitEmail(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final success =
        _isSignUp ? await auth.signUpWithEmail(email, password) : await auth.signInWithEmail(email, password);
    if (!context.mounted) return;
    if (success) {
      context.pop();
    } else if (auth.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.lastError!)));
    }
  }

  void _showAppleUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Apple Sign-In needs an Xcode capability this project isn\'t scaffolded with yet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xl),
            Icon(Icons.cloud_done_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sign in to back up your documents',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Local scanning, editing, and PDF creation always work offline. '
              'Sign in only if you want your documents synced across devices.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: auth.isLoading ? null : () => _submitGoogle(context),
              icon: const Icon(Icons.g_mobiledata_rounded),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: auth.isLoading ? null : () => _showAppleUnavailable(context),
              icon: const Icon(Icons.apple_rounded),
              label: const Text('Continue with Apple'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: auth.isLoading ? null : () => setState(() => _showEmailForm = !_showEmailForm),
              icon: const Icon(Icons.email_rounded),
              label: const Text('Continue with Email'),
            ),
            if (_showEmailForm) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(
                onPressed: auth.isLoading ? null : () => _submitEmail(context),
                child: auth.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(_isSignUp ? 'Create Account' : 'Sign In'),
              ),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(_isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Sign up"),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: () => context.pop(), child: const Text('Continue without an account')),
          ],
        ),
      ),
    );
  }
}
