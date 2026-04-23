import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/payments/payments_providers.dart';
import '../../../../core/ui/snackbars.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../auth/data/models/user_profile_model.dart';
import '../../application/marketplace_providers.dart';
import '../../data/repositories/marketplace_repository.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  String _initialsFor(UserProfile? profile) {
    final source = profile?.fullName?.trim().isNotEmpty == true
        ? profile!.fullName!.trim()
        : profile?.email.trim() ?? 'Seller';
    final initials = source
        .split(RegExp(r'\s+|@'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return initials.isEmpty ? 'S' : initials;
  }

  String _sellerHeadline(UserProfile? profile) {
    final faculty = profile?.faculty?.trim();
    if (faculty != null && faculty.isNotEmpty) {
      return '$faculty student seller';
    }

    return 'Campus marketplace seller';
  }

  String _sellerTrustNote(UserProfile? profile) {
    if (profile?.matricNumber?.trim().isNotEmpty == true &&
        profile?.phone?.trim().isNotEmpty == true) {
      return 'Profile details completed for smoother buyer trust and meetup coordination.';
    }

    if (profile?.matricNumber?.trim().isNotEmpty == true) {
      return 'Seller profile includes campus identity details.';
    }

    return 'Meetup details can be confirmed after you place an order.';
  }

  Future<void> _toggleProductStatus(
    BuildContext context,
    WidgetRef ref,
    String productId,
    String currentStatus,
  ) async {
    final nextStatus = (currentStatus == 'sold' || currentStatus == 'reserved')
        ? 'available'
        : 'sold';

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

      AppSnackbars.showError(context, error);
    }
  }

  Future<void> _deleteProduct(
    BuildContext context,
    WidgetRef ref,
    String productId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(AppStrings.deleteConfirmTitle),
          ],
        ),
        content: const Text(AppStrings.deleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text(AppStrings.deleteListing),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(marketplaceRepositoryProvider).deleteProduct(productId);
      ref.invalidate(homeFeedProvider);
      ref.invalidate(myListingsProvider);

      if (!context.mounted) return;

      AppSnackbars.showSuccess(context, AppStrings.deleteSuccess);
      context.go('/home');
    } catch (error) {
      if (!context.mounted) return;
      AppSnackbars.showError(context, error);
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

      AppSnackbars.showError(context, error);
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
          title: const Text('Checkout'),
          content: const Text(
            'You will be asked to complete payment with Paystack. If you cancel, the listing becomes available again.',
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

    final repo = ref.read(marketplaceRepositoryProvider);
    final paymentsRepo = ref.read(paymentsRepositoryProvider);
    final supabase = Supabase.instance.client;
    final product = ref.read(productDetailsProvider(productId)).value;
    final email = supabase.auth.currentUser?.email;

    if (product == null) {
      if (context.mounted) {
        AppSnackbars.showError(context, StateError('Product not loaded'));
      }
      return;
    }

    if (email == null || email.isEmpty) {
      if (context.mounted) {
        AppSnackbars.showError(context, StateError('Account email is missing'));
      }
      return;
    }

    final amountKobo = (product.price * 100).round();
    String? orderId;

    if (!context.mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('Preparing checkout...')),
            ],
          ),
        );
      },
    );

    try {
      orderId = await repo.createOrderForProduct(productId);

      final accessCode = await paymentsRepo.initializePaystack(
        email: email,
        amountKobo: amountKobo,
        reference: orderId,
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      final paystack = await ref.read(paystackClientProvider.future);
      final transaction = await paystack.launch(accessCode: accessCode);

      if (transaction.status == 'cancelled' || transaction.status == 'failed') {
        await repo.cancelOrder(orderId);
        ref.invalidate(productDetailsProvider(productId));
        ref.invalidate(homeFeedProvider);
        ref.invalidate(purchaseOrdersProvider);
        ref.invalidate(salesOrdersProvider);

        if (context.mounted) {
          AppSnackbars.showSuccess(context, 'Payment cancelled.');
        }
        return;
      }

      final paid = await paymentsRepo.verifyPaystack(reference: orderId);
      if (!paid) {
        throw StateError('Payment could not be verified.');
      }

      await repo.markOrderPaid(orderId);

      ref.invalidate(productDetailsProvider(productId));
      ref.invalidate(homeFeedProvider);
      ref.invalidate(myListingsProvider);
      ref.invalidate(purchaseOrdersProvider);
      ref.invalidate(salesOrdersProvider);

      if (!context.mounted) {
        return;
      }

      AppSnackbars.showSuccess(context, 'Payment successful. Order created.');

      context.push('/orders');
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      Navigator.of(context, rootNavigator: true).maybePop();
      if (orderId != null) {
        try {
          await repo.cancelOrder(orderId);
          ref.invalidate(productDetailsProvider(productId));
          ref.invalidate(homeFeedProvider);
          ref.invalidate(purchaseOrdersProvider);
          ref.invalidate(salesOrdersProvider);
        } catch (_) {}
      }
      AppSnackbars.showError(context, error);
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

      AppSnackbars.showError(context, error);
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
    final sellerProfileAsync = product == null
        ? null
        : ref.watch(publicProfileProvider(product.sellerId));
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
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.pink : null,
              ),
              onPressed: favoriteIdsAsync.isLoading
                  ? null
                  : () => _toggleFavorite(context, ref, product.id, isFavorite),
            ),
          if (product != null && isOwner)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/product/${product.id}/edit'),
            ),
          if (product != null && isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: AppColors.error,
              onPressed: () => _deleteProduct(context, ref, product.id),
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
                height: 320,
                child: product.images.isNotEmpty
                    ? Stack(
                        children: [
                          PageView.builder(
                            itemCount: product.images.length,
                            itemBuilder: (context, index) {
                              return Image.network(
                                product.images[index].imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              );
                            },
                            onPageChanged: (index) {},
                          ),
                          if (product.images.length > 1)
                            Positioned(
                              bottom: 12,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  product.images.length,
                                  (index) => Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: index == 0
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : Container(
                        color: AppColors.surfaceMuted,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported_outlined,
                              size: 56,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No photos yet',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
                      formatNaira(product.price),
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
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
                        if (product.condition != null)
                          Chip(
                            label: Text('Condition: ${product.condition}'),
                            backgroundColor: AppColors.background,
                          ),
                        Chip(
                          label: Text(
                            product.location?.trim().isNotEmpty == true
                                ? 'Pickup: ${product.location}'
                                : 'Campus pickup',
                          ),
                          backgroundColor: AppColors.background,
                        ),
                        Chip(
                          label: Text(
                            product.createdAt == null
                                ? 'Listed recently'
                                : 'Listed ${product.createdAt!.day}/${product.createdAt!.month}/${product.createdAt!.year}',
                          ),
                          backgroundColor: AppColors.background,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: sellerProfileAsync == null
                          ? const SizedBox.shrink()
                          : sellerProfileAsync.when(
                              data: (sellerProfile) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                     Container(
                                      height: 56,
                                      width: 56,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _initialsFor(sellerProfile),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isOwner
                                                ? 'You are the seller'
                                                : sellerProfile?.displayName ??
                                                      'Marketplace seller',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _sellerHeadline(sellerProfile),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              if (sellerProfile?.matricNumber
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true)
                                                _TrustBadge(
                                                  label: 'Campus identity',
                                                  icon: Icons.verified_user,
                                                ),
                                              _TrustBadge(
                                                label:
                                                    product.location
                                                            ?.trim()
                                                            .isNotEmpty ==
                                                        true
                                                    ? 'Meetup ready'
                                                    : 'Campus pickup',
                                                icon: Icons.place_outlined,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            _sellerTrustNote(sellerProfile),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                              loading: () => const SizedBox(
                                height: 56,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              error: (_, _) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Seller details',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'This seller can still be contacted through the order flow.',
                                  ),
                                ],
                              ),
                            ),
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
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Why this listing feels safe',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 10),
                          const _DetailBullet(
                            text:
                                'Prices are shown upfront so buyers know the deal before messaging.',
                          ),
                          const _DetailBullet(
                            text:
                                'Orders create a visible transaction record for both buyer and seller.',
                          ),
                          _DetailBullet(
                            text: product.location?.trim().isNotEmpty == true
                                ? 'Preferred meetup is ${product.location}, which keeps the exchange campus-friendly.'
                                : 'This seller is set up for campus meetup or direct handover.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    if (isOwner) ...[
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.push('/product/${product.id}/edit'),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text(AppStrings.editListing),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _toggleProductStatus(
                          context,
                          ref,
                          product.id,
                          product.status,
                        ),
                        icon: Icon(
                          product.status == 'sold'
                              ? Icons.refresh_rounded
                              : Icons.sell_outlined,
                          size: 18,
                        ),
                        label: Text(
                          product.status == 'sold'
                              ? AppStrings.markAvailable
                              : AppStrings.markSold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () =>
                            _deleteProduct(context, ref, product.id),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text(AppStrings.deleteListing),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                      ),
                    ] else
                      ElevatedButton(
                        onPressed: product.status == 'available'
                            ? () => _placeOrder(context, ref, product.id)
                            : null,
                        child: Text(
                          product.status == 'reserved'
                              ? AppStrings.reserved
                              : AppStrings.placeOrder,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(ErrorMapper.toAppException(e).message)),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _TrustBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DetailBullet extends StatelessWidget {
  final String text;

  const _DetailBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(
              Icons.check_circle_outline,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
