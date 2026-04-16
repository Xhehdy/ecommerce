import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../application/marketplace_providers.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/marketplace_repository.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  Future<void> _toggleProductStatus(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final nextStatus = product.status == 'sold' ? 'available' : 'sold';

    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .updateProductStatus(productId: product.id, status: nextStatus);

      ref.invalidate(myListingsProvider);
      ref.invalidate(homeFeedProvider);
      ref.invalidate(productDetailsProvider(product.id));

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(myListingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Listings')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myListingsProvider);
        },
        child: listingsAsync.when(
          data: (products) {
            if (products.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 72,
                          width: 72,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceMuted,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            size: 36,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'You have not created any listings yet.',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Post your first item to start your marketplace demo.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: () => context.push('/sell'),
                          child: const Text('CREATE LISTING'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final liveListings = products.where((product) {
              return product.status != 'sold';
            }).length;
            final soldListings = products.length - liveListings;
            final portfolioValue = products.fold<double>(0, (total, product) {
              return total + product.price;
            });

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: products.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        _ListingSummaryChip(
                          label: 'Live now',
                          value: '$liveListings',
                        ),
                        _ListingSummaryChip(
                          label: 'Sold',
                          value: '$soldListings',
                        ),
                        _ListingSummaryChip(
                          label: 'Portfolio value',
                          value: formatNaira(portfolioValue),
                        ),
                      ],
                    ),
                  );
                }

                final product = products[index - 1];
                final imageUrl = product.images.isNotEmpty
                    ? product.images.first.imageUrl
                    : null;

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => context.push('/product/${product.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  height: 92,
                                  width: 92,
                                  child: imageUrl == null
                                      ? Container(
                                          color: AppColors.surfaceMuted,
                                          child: const Icon(
                                            Icons.image_not_supported_outlined,
                                            color: AppColors.textSecondary,
                                          ),
                                        )
                                      : Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      formatNaira(product.price),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      product.condition?.trim().isNotEmpty ==
                                              true
                                          ? product.condition!
                                          : 'Ready for campus pickup',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: product.status == 'sold'
                                            ? Colors.orange.shade50
                                            : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        product.status == 'sold'
                                            ? 'Sold'
                                            : 'Available',
                                        style: TextStyle(
                                          color: product.status == 'sold'
                                              ? Colors.orange.shade800
                                              : Colors.green.shade800,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => context.push(
                                    '/product/${product.id}/edit',
                                  ),
                                  child: const Text('EDIT'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _toggleProductStatus(
                                    context,
                                    ref,
                                    product,
                                  ),
                                  child: Text(
                                    product.status == 'sold'
                                        ? 'MARK AVAILABLE'
                                        : 'MARK SOLD',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Unable to load your listings: $error'),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListingSummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _ListingSummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
