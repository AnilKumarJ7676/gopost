import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';

/// Bottom sheet shown when a guest user tries to access a restricted feature.
/// Returns `true` if the user chooses to sign in (navigates to login).
class LoginRequiredSheet extends StatelessWidget {
  final String feature;

  const LoginRequiredSheet({super.key, required this.feature});

  static Future<bool> show(BuildContext context, {required String feature}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => LoginRequiredSheet(feature: feature),
    );
    if (result == true && context.mounted) {
      context.go('/auth/login');
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Sign In Required',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'To $feature, you need to sign in or create an account. It only takes a moment.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.base,
                  ),
                ),
                child: const Text('Sign In'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
