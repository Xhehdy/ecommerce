import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/colors.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../data/models/product_model.dart';
import 'package:go_router/go_router.dart';

final productDetailsProvider = FutureProvider.family<Product, String>((ref, id) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return repo.getProductDetails(id);
});

class ProductDetailScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productDetailsProvider(productId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: productAsync.when(
        data: (product) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 300,
                child: product.images.isNotEmpty
                    ? PageView.builder(
                        itemCount: product.images.length,
                        itemBuilder: (context, index) {
                          return Image.network(
                            product.images[index].imageUrl,
                            fit: BoxFit.cover,
                          );
                        },
                      )
                    : Container(
                        color: AppColors.border,
                        child: const Icon(Icons.image_not_supported, size: 64, color: AppColors.textSecondary),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(height: 16),
                    if (product.condition != null)
                      Chip(
                        label: Text('Condition: ${product.condition}'),
                        backgroundColor: AppColors.background,
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.description ?? 'No description provided.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: () {
                        // Dummy chat/buy functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Purchase functionality coming in Phase 5!')),
                        );
                      },
                      child: const Text('CONTACT SELLER'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load item: $e')),
      ),
    );
  }
}
