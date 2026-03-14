import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gopost_app/auth/presentation/providers/auth_providers.dart';
import 'package:gopost_app/core/theme/neon_glow.dart';

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  static const _destinations = [
    ('/', Icons.home_outlined, Icons.home, 'Home'),
    ('/templates', Icons.grid_view_outlined, Icons.grid_view, 'Templates'),
    ('/create', Icons.auto_fix_high_outlined, Icons.auto_fix_high, 'Go Craft'),
    ('/profile', Icons.person_outlined, Icons.person, 'Profile'),
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/templates')) return 1;
    if (location.startsWith('/create') || location.startsWith('/editor')) {
      return 2;
    }
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _selectedIndex(context);
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      body: Column(
        children: [
          if (authState.isGuest) _GuestBanner(onSignIn: () => context.go('/auth/login')),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          final route = _destinations[i].$1;
          context.go(route);
        },
        destinations: _destinations
            .asMap()
            .entries
            .map((entry) {
              final d = entry.value;
              final isSelected = index == entry.key;
              return NavigationDestination(
                icon: Icon(d.$2),
                selectedIcon: NeonGlowIcon(
                  isActive: isSelected,
                  child: Icon(d.$3),
                ),
                label: d.$4,
              );
            })
            .toList(),
      ),
    );
  }

}

class _GuestBanner extends StatelessWidget {
  final VoidCallback onSignIn;

  const _GuestBanner({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.tertiaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: theme.colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Browsing as guest. Sign in to export and use templates.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: onSignIn,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  'Sign In',
                  style: TextStyle(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
