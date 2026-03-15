import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gopost_app/auth/presentation/providers/auth_providers.dart';
import 'package:gopost_app/auth/presentation/screens/login_screen.dart';
import 'package:gopost_app/auth/presentation/screens/register_screen.dart';
import 'package:gopost_app/core/navigation/main_shell.dart';
import 'package:gopost_app/image_editor/presentation/screens/image_editor_screen.dart';
import 'package:gopost_app/image_editor/presentation/screens/template_customization_screen.dart';
import 'package:gopost_app/template_browser/presentation/screens/browse_screen.dart';
import 'package:gopost_app/go_craft/presentation/screens/go_craft_screen.dart';
import 'package:gopost_app/template_browser/presentation/screens/home_screen.dart';
import 'package:gopost_app/template_browser/presentation/screens/template_detail_screen.dart';
import 'package:gopost_app/video_editor/presentation/screens/project_list_screen.dart';
import 'package:gopost_app/video_editor/presentation/screens/video_editor_screen.dart';
import 'package:gopost_app/video_editor/presentation/screens/video_template_customization_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/auth/login',
    redirect: (context, state) {
      final canAccess = authState.canAccessApp;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!canAccess && !isAuthRoute) return '/auth/login';
      if (canAccess && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/editor/video',
        builder: (_, state) => VideoEditorScreen(
          projectId: state.uri.queryParameters['projectId'],
        ),
      ),
      GoRoute(
        path: '/editor/image',
        builder: (_, __) => const ImageEditorScreen(),
      ),
      GoRoute(
        path: '/editor/customize/:id',
        builder: (_, state) => TemplateCustomizationScreen(
          templateId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/editor/video/customize/:id',
        builder: (_, state) => VideoTemplateCustomizationScreen(
          templateId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/projects/video',
        builder: (_, __) => const ProjectListScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/templates',
            builder: (_, __) => const BrowseScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => TemplateDetailScreen(
                  id: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/create',
            builder: (_, __) => const GoCraftScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('Profile')),
            ),
          ),
        ],
      ),
    ],
  );
});
