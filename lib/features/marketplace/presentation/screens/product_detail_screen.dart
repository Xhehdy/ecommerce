import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/colors.dart';
import '../../../auth/application/auth_provider.dart';
import '../../application/marketplace_providers.dart';
import '../../data/repositories/marketplace_repository.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  Future<void> _toggleProductStatus(
    BuildContext context,
    WidgetRef ref,
    String productId,
    String currentStatus,
  ) async {
    final nextStatus = currentStatus == 'sold' ? 'available' : 'sold';

    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .updateProductStatus(productId: productId, status: nextStatus);

      ref.invalidate(productDetailsProvider(productId));
      ref.invalidate(homeFeedProvider);
      ref.invalidate(myListingsProvider);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextStatus == 'sold'
                ? 'Listing marked as sold.'
                : 'Listing is available again.',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update listing: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    String productId,
    bool isFavorite,
  ) async {
    try {
      await ref.read(marketplaceRepositoryProvider).toggleFavorite(productId);

      ref.invalidate(favoriteProductIdsProvider);
      ref.invalidate(favoriteProductsProvider);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorite ? 'Removed from favorites.' : 'Added to favorites.',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update favorites: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _placeOrder(
    BuildContext context,
    WidgetRef ref,
    String productId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Place Order'),
          content: const Text(
            'This will create a transaction record, move the product into your purchase history, and mark the listing as sold.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .createOrderForProduct(productId);

      ref.invalidate(productDetailsProvider(productId));
      ref.invalidate(homeFeedProvider);
      ref.invalidate(myListingsProvider);
      ref.invalidate(purchaseOrdersProvider);
      ref.invalidate(salesOrdersProvider);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order created successfully.'),
          backgroundColor: AppColors.primary,
        ),
      );

      context.push('/orders');
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to place order: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _reportListing(
    BuildContext context,
    WidgetRef ref,
    String productId,
  ) async {
    final reasonController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Report Listing'),
          content: TextField(
            controller: reasonController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Describe why this listing should be reviewed',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (submitted != true) {
      reasonController.dispose();
      return;
    }

    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .reportProduct(productId: productId, reason: reasonController.text);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing report submitted.'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to submit report: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      reasonController.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productDetailsProvider(productId));
    final currentUser = ref.watch(currentUserProvider);
    final favoriteIdsAsync = ref.watch(favoriteProductIdsProvider);
    final product = productAsync.asData?.value;
    final isOwner = product != null && currentUser?.id == product.sellerId;
    final isFavorite =
        product != null &&
        (favoriteIdsAsync.asData?.value.contains(product.id) ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (product != null && !isOwner)
            IconButton(
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
              onPressed: favoriteIdsAsync.isLoading
                  ? null
                  : () => _toggleFavorite(context, ref, product.id, isFavorite),
            ),
          if (product != null && isOwner)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/product/${product.id}/edit'),
            ),
          if (product != null && !isOwner)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'report') {
                  _reportListing(context, ref, product.id);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'report',
                  child: Text('Report listing'),
                ),
              ],
            ),
        ],
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
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
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
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: product.status == 'sold'
                            ? Colors.orange.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        product.status == 'sold' ? 'Sold' : 'Available',
                        style: TextStyle(
                          color: product.status == 'sold'
                              ? Colors.orange.shade800
                              : Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                        ),
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
                    if (isOwner) ...[
                      ElevatedButton(
                        onPressed: () =>
                            context.push('/product/${product.id}/edit'),
                        child: const Text('EDIT LISTING'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _toggleProductStatus(
                          context,
                          ref,
                          product.id,
                          product.status,
                        ),
                        child: Text(
                          product.status == 'sold'
                              ? 'MARK AVAILABLE'
                              : 'MARK AS SOLD',
                        ),
                      ),
                    ] else
                      ElevatedButton(
                        onPressed: product.status == 'sold'
                            ? null
                            : () => _placeOrder(context, ref, product.id),
                        child: const Text('PLACE ORDER'),
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
