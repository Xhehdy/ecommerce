import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/ui/snackbars.dart';
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
    final nextStatus = (product.status == 'sold' || product.status == 'reserved')
        ? 'available'
        : 'sold';

    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .updateProductStatus(productId: product.id, status: nextStatus);

      ref.invalidate(myListingsProvider);
      ref.invalidate(homeFeedProvider);
      ref.invalidate(productDetailsProvider(product.id));

      if (!context.mounted) return;

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
      if (!context.mounted) return;
      AppSnackbars.showError(context, error);
    }
  }

  Future<void> _deleteProduct(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(AppStrings.deleteConfirmTitle),
        content: const Text(AppStrings.deleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text(AppStrings.deleteListing),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(marketplaceRepositoryProvider).deleteProduct(product.id);

      ref.invalidate(myListingsProvider);
      ref.invalidate(homeFeedProvider);

      if (!context.mounted) return;
      AppSnackbars.showSuccess(context, AppStrings.deleteSuccess);
    } catch (error) {
      if (!context.mounted) return;
      AppSnackbars.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(myListingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.myListings)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/sell'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
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

            final liveListings = products.where((p) => p.status != 'sold').length;
            final soldListings = products.length - liveListings;
            final portfolioValue = products.fold<double>(0, (t, p) => t + p.price);

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: products.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        _StatChip(label: 'Live', value: '$liveListings'),
                        const SizedBox(width: 12),
                        _StatChip(label: 'Sold', value: '$soldListings'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatChip(
                            label: 'Value',
                            value: formatNaira(portfolioValue),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final product = products[index - 1];
                final imageUrl = product.images.isNotEmpty
                    ? product.images.first.imageUrl
                    : null;
                final isSold = product.status == 'sold';

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
                                  height: 88,
                                  width: 88,
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
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.title,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 6),
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSold
                                            ? Colors.orange.shade50
                                            : AppColors.successSoft,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        isSold ? 'Sold' : 'Available',
                                        style: TextStyle(
                                          color: isSold
                                              ? Colors.orange.shade800
                                              : AppColors.primaryDark,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              // Delete
                              SizedBox(
                                height: 40,
                                width: 40,
                                child: IconButton.outlined(
                                  onPressed: () =>
                                      _deleteProduct(context, ref, product),
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  style: IconButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(color: AppColors.border),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => context.push(
                                    '/product/${product.id}/edit',
                                  ),
                                  child: const Text('EDIT'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _toggleProductStatus(
                                    context,
                                    ref,
                                    product,
                                  ),
                                  child: Text(
                                    isSold ? 'MARK AVAILABLE' : 'MARK SOLD',
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
              child: Text(ErrorMapper.toAppException(error).message),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
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
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
