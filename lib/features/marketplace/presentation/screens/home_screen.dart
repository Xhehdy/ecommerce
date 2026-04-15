import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/colors.dart';
import '../../application/marketplace_providers.dart';
import '../widgets/product_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final feedAsync = ref.watch(homeFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ATELIER.', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => context.push('/sell'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {}, // Stub for Phase 3/4
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeFeedProvider);
          ref.invalidate(categoriesProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 70,
                child: categoriesAsync.when(
                  data: (categories) => ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Chip(
                          label: Text(category.name),
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(color: AppColors.border),
                        ),
                      );
                    },
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Center(child: Text('Failed to load categories', style: TextStyle(color: AppColors.error))),
                ),
              ),
            ),
            feedAsync.when(
              data: (products) => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return ProductCard(product: products[index]);
                    },
                    childCount: products.length,
                  ),
                ),
              ),
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error loading feed')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
