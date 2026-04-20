import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/services/paystack_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../auth/data/models/user_profile_model.dart';
import '../../application/marketplace_providers.dart';
import '../../data/models/product_model.dart';
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
    Product product,
    UserProfile? buyerProfile,
    String? buyerEmail,
  ) async {
    if (buyerEmail == null || buyerEmail.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to start payment: missing account email.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pay with Paystack (Sandbox)'),
          content: Text(
            'You are about to pay ${formatNaira(product.price)} in Paystack sandbox mode before creating this order.',
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
      final paymentResult = await ref
          .read(paystackServiceProvider)
          .chargeSandboxPayment(
            context: context,
            amount: product.price,
            email: buyerEmail,
            fullName: buyerProfile?.fullName,
            metadata: {
              'product_id': product.id,
              'product_title': product.title,
            },
          );

      if (!paymentResult.isSuccessful) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment was cancelled. No order was created.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      await ref
          .read(marketplaceRepositoryProvider)
          .createOrderForProduct(product.id);

      ref.invalidate(productDetailsProvider(product.id));
      ref.invalidate(homeFeedProvider);
      ref.invalidate(myListingsProvider);
      ref.invalidate(purchaseOrdersProvider);
      ref.invalidate(salesOrdersProvider);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment successful${paymentResult.reference == null ? '' : ' (${paymentResult.reference})'}. Order created.',
          ),
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
    final buyerProfile = ref.watch(profileProvider).asData?.value;
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
                                        color: AppColors.surfaceMuted,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _initialsFor(sellerProfile),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: AppColors.primaryDark,
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
                            : () => _placeOrder(
                                context,
                                ref,
                                product,
                                buyerProfile,
                                currentUser?.email,
                              ),
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
