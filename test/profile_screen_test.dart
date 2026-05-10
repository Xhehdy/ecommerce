import 'package:ecommerce/features/auth/application/auth_provider.dart';
import 'package:ecommerce/features/auth/data/models/user_profile_model.dart';
import 'package:ecommerce/features/auth/presentation/screens/profile_screen.dart';
import 'package:ecommerce/features/marketplace/application/marketplace_providers.dart';
import 'package:ecommerce/features/marketplace/data/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile screen shows saved count instead of fake reviews', (
    tester,
  ) async {
    const profile = UserProfile(
      id: 'user-1',
      email: 'tester@example.com',
      fullName: 'Test User',
      matricNumber: 'MAT123',
      faculty: 'Engineering',
      phone: '08000000000',
    );

    final savedProducts = [
      Product(
        id: 'p1',
        sellerId: 'seller-1',
        title: 'Desk Lamp',
        price: 12000,
        status: 'available',
      ),
      Product(
        id: 'p2',
        sellerId: 'seller-2',
        title: 'Notebook',
        price: 3000,
        status: 'available',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) async => profile),
          myListingsProvider.overrideWith((ref) async => savedProducts),
          purchaseOrdersProvider.overrideWith((ref) async => const []),
          salesOrdersProvider.overrideWith((ref) async => const []),
          favoriteProductsProvider.overrideWith((ref) async => savedProducts),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Rating'), findsNothing);
    expect(find.text('(12 reviews)'), findsNothing);
  });
}
