import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _routeAfterSplash();
  }

  Future<void> _routeAfterSplash() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) {
      return;
    }

    final hasSession = Supabase.instance.client.auth.currentSession != null;
    context.go(hasSession ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ATELIER.',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Campus Marketplace',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 24),
            SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
