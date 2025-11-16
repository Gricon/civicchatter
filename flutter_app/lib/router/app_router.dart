import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/private_profile_screen.dart';
import '../screens/profile/public_profile_screen.dart';
import '../screens/debates/debates_screen.dart';
import '../screens/debates/debate_detail_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/edit_profile_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = Supabase.instance.client.auth.currentUser != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';

      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      if (isAuthenticated && isAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/',
        redirect: (context, state) => '/home',
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const PrivateProfileScreen(),
      ),
      GoRoute(
        path: '/u/:handle',
        name: 'public-profile',
        builder: (context, state) {
          final handle = state.pathParameters['handle']!;
          return PublicProfileScreen(handle: handle);
        },
      ),
      GoRoute(
        path: '/debates',
        name: 'debates',
        builder: (context, state) => const DebatesScreen(),
      ),
      GoRoute(
        path: '/debates/:id',
        name: 'debate-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return DebateDetailScreen(debateId: id);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/edit-profile',
        name: 'edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
    ],
  );
}
