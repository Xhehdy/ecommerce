import 'package:ecommerce/features/auth/presentation/screens/login_screen.dart';
import 'package:ecommerce/features/auth/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login screen renders the core auth UI', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('ATELIER.'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Access your exclusive marketplace.'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('splash screen renders launch branding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SplashScreen())),
    );

    expect(find.text('ATELIER.'), findsOneWidget);
    expect(find.text('Campus Marketplace'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
