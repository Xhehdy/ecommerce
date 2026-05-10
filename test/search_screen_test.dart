import 'package:ecommerce/features/marketplace/application/marketplace_providers.dart';
import 'package:ecommerce/features/marketplace/presentation/screens/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'search screen shows a discovery empty state when there are no categories, recents, or suggestions',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) async => []),
            recentSearchesProvider.overrideWith((ref) async => []),
            homeFeedProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(home: SearchScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nothing to explore yet'), findsOneWidget);
      expect(
        find.text(
          'Try a keyword search, browse the latest listings, or clear filters to discover campus deals.',
        ),
        findsOneWidget,
      );
      expect(find.text('Browse latest listings'), findsOneWidget);
    },
  );
}
