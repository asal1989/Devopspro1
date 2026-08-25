import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

/// Optional sign-in. Scanning, editing, OCR, and PDF creation all work
/// without an account — this screen is only reached from Settings for
/// users who want cloud backup.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Padding(
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
              onPressed: () => _mockSignIn(context, 'Google'),
              icon: const Icon(Icons.g_mobiledata_rounded),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _mockSignIn(context, 'Apple'),
              icon: const Icon(Icons.apple_rounded),
              label: const Text('Continue with Apple'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _mockSignIn(context, 'Email'),
              icon: const Icon(Icons.email_rounded),
              label: const Text('Continue with Email'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: () => context.pop(), child: const Text('Continue without an account')),
          ],
        ),
      ),
    );
  }

  void _mockSignIn(BuildContext context, String method) {
    context.read<SettingsProvider>().signIn('${method.toLowerCase()}.user@example.com');
    context.pop();
  }
}
