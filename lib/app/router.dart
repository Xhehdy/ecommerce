import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/marketplace/presentation/screens/home_screen.dart';
import '../../features/marketplace/presentation/screens/product_detail_screen.dart';
import '../../features/marketplace/presentation/screens/create_listing_screen.dart';
import '../../features/marketplace/presentation/screens/favorites_screen.dart';
import '../../features/marketplace/presentation/screens/help_center_screen.dart';
import '../../features/marketplace/presentation/screens/my_listings_screen.dart';
import '../../features/marketplace/presentation/screens/notifications_screen.dart';
import '../../features/marketplace/presentation/screens/orders_screen.dart';
import '../../features/marketplace/presentation/screens/order_detail_screen.dart';
import '../../features/marketplace/presentation/screens/search_screen.dart';
import '../../features/marketplace/presentation/screens/settings_screen.dart';
import 'router_error_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final supabase = Supabase.instance.client;
  final authRouterNotifier = ref.watch(authRouterNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authRouterNotifier,
    errorBuilder: (context, state) {
      return RouterErrorScreen(
        message:
            state.error?.toString() ?? 'That marketplace page is unavailable.',
      );
    },
    redirect: (context, state) {
      final session = supabase.auth.currentSession;
      final isSplash = state.matchedLocation == '/splash';
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/reset-password';

      final isPasswordRecovery =
          authRouterNotifier.lastEvent == AuthChangeEvent.passwordRecovery;

      // Let the splash screen handle its own navigation.
      if (isSplash) return null;

      if (isPasswordRecovery && state.matchedLocation != '/reset-password') {
        return '/reset-password';
      }

      if (session == null && !isAuthRoute) {
        return '/login';
      }

      if (session != null && isAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) =>
            ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/sell',
        builder: (context, state) => const CreateListingScreen(),
      ),
      GoRoute(
        path: '/product/:id/edit',
        builder: (context, state) =>
            CreateListingScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: '/saved',
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/my-listings',
        builder: (context, state) => const MyListingsScreen(),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) =>
            OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/help',
        builder: (context, state) => const HelpCenterScreen(),
      ),
    ],
  );
});

final authRouterNotifierProvider = Provider<AuthRouterNotifier>((ref) {
  return AuthRouterNotifier(Supabase.instance.client.auth.onAuthStateChange);
});

class AuthRouterNotifier extends ChangeNotifier {
  AuthRouterNotifier(Stream<AuthState> stream) {
    _subscription = stream.asBroadcastStream().listen((state) {
      lastEvent = state.event;
      lastSession = state.session;
      notifyListeners();
    });
  }

  AuthChangeEvent? lastEvent;
  Session? lastSession;

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
