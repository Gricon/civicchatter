import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/private_profile_screen.dart';
import '../screens/profile/public_profile_screen.dart';
import '../screens/friends/friends_screen.dart';
import '../screens/debates/debates_screen.dart';
import '../screens/debates/debate_detail_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/edit_profile_screen.dart';
import '../screens/settings/background_settings_screen.dart';
import '../screens/debug/debug_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuthenticated = Supabase.instance.client.auth.currentUser != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/debug';

      // Allow debug screen without auth
      if (state.matchedLocation == '/debug') {
        return null;
      }

      // If not authenticated and trying to access protected route
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // If authenticated and on auth route, go home
      if (isAuthenticated && isAuthRoute && state.matchedLocation != '/debug') {
        return '/home';
      }

      // If root, redirect based on auth
      if (state.matchedLocation == '/') {
        return isAuthenticated ? '/home' : '/login';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SignupScreen(),
        ),
      ),
      GoRoute(
        path: '/',
        redirect: (context, state) {
          final isAuthenticated =
              Supabase.instance.client.auth.currentUser != null;
          return isAuthenticated ? '/home' : '/login';
        },
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: HomeScreen(),
        ),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: PrivateProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/u/:handle',
        name: 'public-profile',
        pageBuilder: (context, state) {
          final handle = state.pathParameters['handle']!;
          return NoTransitionPage(
            child: PublicProfileScreen(handle: handle),
          );
        },
      ),
      GoRoute(
        path: '/debates',
        name: 'debates',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: DebatesScreen(),
        ),
      ),
      GoRoute(
        path: '/friends',
        name: 'friends',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: FriendsScreen(),
        ),
      ),
      GoRoute(
        path: '/debates/:id',
        name: 'debate-detail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return NoTransitionPage(
            child: DebateDetailScreen(debateId: id),
          );
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/edit-profile',
        name: 'edit-profile',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: EditProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/background',
        name: 'background-settings',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: BackgroundSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/debug',
        name: 'debug',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: DebugScreen(),
        ),
      ),
    ],
  );
}
