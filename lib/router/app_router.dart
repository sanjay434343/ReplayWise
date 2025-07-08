import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/login_page.dart';
import '../screens/home_page.dart';
import '../screens/email_detail_page.dart';
import '../screens/settings_page.dart';
import '../services/auth_service.dart';
import '../models/email_model.dart';

class AppRouter {
  static final AuthService _authService = AuthService();

  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      // Login Route
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),

      // Home Route (original)
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const MyHomePage(title: 'ReplyWise'),
      ),

      // Email Detail Route
      GoRoute(
        path: '/email-detail',
        name: 'email-detail',
        builder: (context, state) {
          final EmailModel email = state.extra as EmailModel;
          return EmailDetailPage(email: email);
        },
      ),

      // Settings Route
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),

      // Search Route
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Text('Search Page - Coming Soon'),
          ),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Page Not Found',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'The page you are looking for does not exist.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}

// Route names for easy reference
class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/home';
  static const String emails = '/emails'; // Add this
  static const String emailDetail = '/email-detail';
  static const String settings = '/settings';
  static const String search = '/search';
}
