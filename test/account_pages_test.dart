import 'package:ecommerce/features/marketplace/presentation/screens/notifications_screen.dart';
import 'package:ecommerce/features/marketplace/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settings screen shows route-backed account shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Saved items'), findsOneWidget);
  });

  testWidgets('notifications screen shows quick links to real pages', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));

    expect(find.text('Open orders'), findsOneWidget);
    expect(find.text('View saved items'), findsOneWidget);
  });
}
