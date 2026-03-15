import 'package:flutter/material.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';

class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.g_mobiledata, size: 24),
          label: const Text('Continue with Google'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {},
          icon: Icon(Icons.apple, size: 24, color: theme.colorScheme.onSurface),
          label: const Text('Continue with Apple'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }
}
