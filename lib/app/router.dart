import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/marketplace/presentation/screens/home_screen.dart';
import '../../features/marketplace/presentation/screens/product_detail_screen.dart';
import '../../features/marketplace/presentation/screens/create_listing_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';

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
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) => ProductDetailScreen(
          productId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/sell',
        builder: (context, state) => const CreateListingScreen(),
      ),
    ],
  );
});
