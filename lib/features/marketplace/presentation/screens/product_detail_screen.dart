import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/payments/payments_providers.dart';
import '../../../../core/ui/network_image.dart';
import '../../../../core/ui/snackbars.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../auth/data/models/user_profile_model.dart';
import '../../application/marketplace_providers.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../widgets/checkout_sheet.dart';

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

  String _statusLabel(String status) {
    return switch (status) {
      'sold' => AppStrings.sold,
      'reserved' => AppStrings.reserved,
      _ => AppStrings.available,
    };
  }

  Color _statusBackground(String status) {
    return switch (status) {
      'sold' => AppColors.warningSoft,
      'reserved' => const Color(0xFFEAF0FF),
      _ => AppColors.successSoft,
    };
  }

  Color _statusForeground(String status) {
    return switch (status) {
      'sold' => Colors.orange.shade800,
      'reserved' => const Color(0xFF2F4A9E),
      _ => AppColors.primaryDark,
    };
  }

  String _buyerActionLabel(Product product) {
    if (!product.canOrder && product.status == 'available') {
      return 'Out of stock';
    }

    return switch (product.status) {
      'sold' => AppStrings.sold,
      'reserved' => AppStrings.reserved,
      _ => 'Checkout',
    };
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
              child: const Icon(
                Icons.delete_outline,
                color: AppColors.error,
                size: 22,
              ),
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
    final product = ref.read(productDetailsProvider(productId)).value;
    if (product == null) {
      if (context.mounted) {
        AppSnackbars.showError(context, StateError('Product not loaded'));
      }
      return;
    }
    if (!product.canOrder) {
      if (context.mounted) {
        AppSnackbars.showError(context, StateError('Listing is out of stock'));
      }
      return;
    }

    final checkout = await showMarketplaceCheckoutSheet(
      context: context,
      items: [CheckoutSheetItem(product: product, quantity: 1)],
      allowQuantityEditing: true,
    );

    if (checkout == null) {
      return;
    }

    final checkoutItem = checkout.items.single;

    final repo = ref.read(marketplaceRepositoryProvider);
    final paymentsRepo = ref.read(paymentsRepositoryProvider);

    String? orderId;

    if (!context.mounted) {
      return;
    }

    if (checkout.method == CheckoutPaymentMethod.meetup) {
      try {
        orderId = await repo.createMeetupOrderForProduct(
          productId,
          quantity: checkoutItem.quantity,
          meetupLocation: checkout.meetupLocation,
        );
        ref.invalidate(productDetailsProvider(productId));
        ref.invalidate(homeFeedProvider);
        ref.invalidate(purchaseOrdersProvider);
        ref.invalidate(salesOrdersProvider);

        if (!context.mounted) {
          return;
        }

        AppSnackbars.showSuccess(context, 'Order created. Pay on meetup.');
        context.go('/orders/$orderId');
      } catch (error) {
        if (!context.mounted) return;
        AppSnackbars.showError(context, error);
      }
      return;
    }

    final supabase = Supabase.instance.client;
    final email = supabase.auth.currentUser?.email;

    if (email == null || email.isEmpty) {
      if (context.mounted) {
        AppSnackbars.showError(context, StateError('Account email is missing'));
      }
      return;
    }

    final amountKobo = (checkout.total * 100).round();

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
      orderId = await repo.createOrderForProduct(
        productId,
        quantity: checkoutItem.quantity,
        meetupLocation: checkout.meetupLocation,
      );

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

      context.go('/orders/$orderId');
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
      if (!context.mounted) {
        return;
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
        title: const Text(
          'Listing details',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/home');
          },
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
      bottomNavigationBar: product == null || isOwner
          ? null
          : _ProductCheckoutBar(
              product: product,
              actionLabel: _buyerActionLabel(product),
              onCheckout: product.canOrder
                  ? () => _placeOrder(context, ref, product.id)
                  : null,
            ),
      body: productAsync.when(
        data: (product) => SingleChildScrollView(
          padding: EdgeInsets.only(bottom: isOwner ? 28 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: _ProductImageGallery(images: product.images),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        product.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      formatNaira(product.price),
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(
                            color: AppColors.primary,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 22),
                    _ListingSnapshot(
                      statusLabel: product.canOrder
                          ? _statusLabel(product.status)
                          : 'Out of stock',
                      statusBackground: product.canOrder
                          ? _statusBackground(product.status)
                          : AppColors.warningSoft,
                      statusForeground: product.canOrder
                          ? _statusForeground(product.status)
                          : Colors.orange.shade800,
                      stockLabel: product.stockLabel,
                      conditionLabel:
                          product.condition?.trim().isNotEmpty == true
                          ? '${product.condition!.trim()} condition'
                          : 'Condition not set',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sellerProfileAsync == null
                        ? const SizedBox.shrink()
                        : sellerProfileAsync.when(
                            data: (sellerProfile) => _SellerSummaryCard(
                              initials: _initialsFor(sellerProfile),
                              title: isOwner
                                  ? 'You are the seller'
                                  : sellerProfile?.displayName ??
                                        'Marketplace seller',
                              subtitle: _sellerHeadline(sellerProfile),
                              hasCampusIdentity:
                                  sellerProfile?.matricNumber
                                      ?.trim()
                                      .isNotEmpty ==
                                  true,
                              hasMeetup:
                                  product.location?.trim().isNotEmpty == true,
                            ),
                            loading: () => const _SellerSummaryLoading(),
                            error: (_, _) => const _SellerSummaryCard(
                              initials: 'S',
                              title: 'Marketplace seller',
                              subtitle:
                                  'This seller can still be reached through checkout.',
                              hasCampusIdentity: false,
                              hasMeetup: false,
                            ),
                          ),
                    const SizedBox(height: 22),
                    _ProductDetailsSection(product: product),
                    const SizedBox(height: 28),
                    _DescriptionSection(
                      description:
                          product.description ?? AppStrings.noDescription,
                    ),
                    const SizedBox(height: 24),
                    _SafetyCard(
                      meetupText: product.location?.trim().isNotEmpty == true
                          ? 'Preferred campus meetup for safe exchange'
                          : 'Campus meetup can be confirmed before handoff',
                    ),
                    if (isOwner) ...[
                      const SizedBox(height: 28),
                      _OwnerActions(
                        product: product,
                        onEdit: () =>
                            context.push('/product/${product.id}/edit'),
                        onToggleStatus: () => _toggleProductStatus(
                          context,
                          ref,
                          product.id,
                          product.status,
                        ),
                        onDelete: () =>
                            _deleteProduct(context, ref, product.id),
                      ),
                    ] else ...[
                      const SizedBox(height: 24),
                      _CheckoutOfferCard(
                        product: product,
                        actionLabel: _buyerActionLabel(product),
                        onCheckout: product.canOrder
                            ? () => _placeOrder(context, ref, product.id)
                            : null,
                      ),
                    ],
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

class _SellerSummaryCard extends StatelessWidget {
  final String initials;
  final String title;
  final String subtitle;
  final bool hasCampusIdentity;
  final bool hasMeetup;

  const _SellerSummaryCard({
    required this.initials,
    required this.title,
    required this.subtitle,
    required this.hasCampusIdentity,
    required this.hasMeetup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (hasCampusIdentity)
                      _TrustBadge(
                        label: 'Campus identity',
                        icon: Icons.verified_user,
                      ),
                    _TrustBadge(
                      label: hasMeetup ? 'Meetup ready' : 'Campus pickup',
                      icon: Icons.place_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
            size: 30,
          ),
        ],
      ),
    );
  }
}

class _SellerSummaryLoading extends StatelessWidget {
  const _SellerSummaryLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 114,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  final String description;

  const _DescriptionSection({required this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.description,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
              size: 30,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            height: 1.45,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SafetyCard extends StatelessWidget {
  final String meetupText;

  const _SafetyCard({required this.meetupText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why this listing feels safe',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          const _DetailBullet(text: 'Upfront pricing with no hidden fees'),
          const _DetailBullet(text: 'Visible transaction record'),
          _DetailBullet(text: meetupText),
        ],
      ),
    );
  }
}

class _OwnerActions extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  const _OwnerActions({
    required this.product,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manage listing',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: onEdit,
          child: const Text(AppStrings.editListing),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: onToggleStatus,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryDark,
            side: const BorderSide(color: AppColors.primaryDark, width: 1.2),
          ),
          child: Text(
            product.status == 'sold'
                ? AppStrings.markAvailable
                : AppStrings.markSold,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onDelete,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(AppStrings.deleteListing),
          ),
        ),
      ],
    );
  }
}

class _CheckoutOfferCard extends StatelessWidget {
  final Product product;
  final String actionLabel;
  final VoidCallback? onCheckout;

  const _CheckoutOfferCard({
    required this.product,
    required this.actionLabel,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final pickupLabel = product.location?.trim().isNotEmpty == true
        ? product.location!.trim()
        : 'Campus pickup';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offer summary',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatNaira(product.price),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Choose quantity, meetup location, and payment method before confirming.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 480) {
                return Column(
                  children: [
                    _OfferFact(
                      icon: Icons.inventory_2_outlined,
                      label: 'Stock',
                      value: product.stockLabel,
                      warning: !product.canOrder,
                    ),
                    const SizedBox(height: 10),
                    _OfferFact(
                      icon: Icons.tune_rounded,
                      label: 'Payment',
                      value: 'Choose at checkout',
                    ),
                    const SizedBox(height: 10),
                    _OfferFact(
                      icon: Icons.place_outlined,
                      label: 'Pickup',
                      value: pickupLabel,
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _OfferFact(
                          icon: Icons.inventory_2_outlined,
                          label: 'Stock',
                          value: product.stockLabel,
                          warning: !product.canOrder,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _OfferFact(
                          icon: Icons.tune_rounded,
                          label: 'Payment',
                          value: 'Choose at checkout',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _OfferFact(
                    icon: Icons.place_outlined,
                    label: 'Pickup',
                    value: pickupLabel,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onCheckout,
            icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _OfferFact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool warning;

  const _OfferFact({
    required this.icon,
    required this.label,
    required this.value,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning ? AppColors.warningSoft : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: warning ? Colors.orange.shade900 : AppColors.primaryDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: warning
                        ? Colors.orange.shade900
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingSnapshot extends StatelessWidget {
  final String statusLabel;
  final Color statusBackground;
  final Color statusForeground;
  final String stockLabel;
  final String conditionLabel;

  const _ListingSnapshot({
    required this.statusLabel,
    required this.statusBackground,
    required this.statusForeground,
    required this.stockLabel,
    required this.conditionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _ListingChip(
            icon: Icons.check_circle,
            label: statusLabel,
            backgroundColor: statusBackground,
            foregroundColor: statusForeground,
          ),
          const SizedBox(width: 10),
          _ListingChip(icon: Icons.inventory_2_outlined, label: stockLabel),
          const SizedBox(width: 10),
          _ListingChip(icon: Icons.local_offer_outlined, label: conditionLabel),
        ],
      ),
    );
  }
}

class _ListingChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const _ListingChip({
    required this.icon,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = foregroundColor ?? AppColors.primaryDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fgColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCheckoutBar extends StatelessWidget {
  final Product product;
  final String actionLabel;
  final VoidCallback? onCheckout;

  const _ProductCheckoutBar({
    required this.product,
    required this.actionLabel,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatNaira(product.price),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.stockLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: product.canOrder
                              ? AppColors.textSecondary
                              : Colors.orange.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 168,
                  child: ElevatedButton.icon(
                    onPressed: onCheckout,
                    icon: const Icon(
                      Icons.shopping_cart_checkout_rounded,
                      size: 18,
                    ),
                    label: FittedBox(child: Text(actionLabel)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductDetailsSection extends StatelessWidget {
  final Product product;

  const _ProductDetailsSection({required this.product});

  String get _pickupLabel {
    final location = product.location?.trim();
    return location == null || location.isEmpty ? 'Campus pickup' : location;
  }

  String get _listedLabel {
    final date = product.createdAt;
    if (date == null) return 'Recently';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final sku = product.sku?.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ProductDetailTile(
                  icon: Icons.place_outlined,
                  label: 'Pickup',
                  value: _pickupLabel,
                ),
              ),
              const _ProductDetailDivider(),
              Expanded(
                child: _ProductDetailTile(
                  icon: Icons.credit_card_outlined,
                  label: 'Payment',
                  value: product.allowMeetupPayment
                      ? 'Paystack or meetup'
                      : 'Paystack only',
                ),
              ),
            ],
          ),
          const Divider(height: 26, color: AppColors.border),
          Row(
            children: [
              Expanded(
                child: _ProductDetailTile(
                  icon: Icons.calendar_month_outlined,
                  label: 'Listed',
                  value: _listedLabel,
                ),
              ),
              const _ProductDetailDivider(),
              Expanded(
                child: _ProductDetailTile(
                  icon: Icons.view_week_outlined,
                  label: 'SKU',
                  value: sku == null || sku.isEmpty ? 'Not set' : sku,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductDetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProductDetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primaryDark, size: 23),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductDetailDivider extends StatelessWidget {
  const _ProductDetailDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 58,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: AppColors.border,
    );
  }
}

class _ProductImageGallery extends StatefulWidget {
  final List<ProductImage> images;

  const _ProductImageGallery({required this.images});

  @override
  State<_ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<_ProductImageGallery> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final galleryHeight = MediaQuery.sizeOf(context).width < 480
        ? 260.0
        : 340.0;

    if (widget.images.isEmpty) {
      return Container(
        height: galleryHeight,
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
      );
    }

    return SizedBox(
      height: galleryHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return AppNetworkImage(url: widget.images[index].imageUrl);
            },
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == _currentPage ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: index == _currentPage
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryDark),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
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
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
