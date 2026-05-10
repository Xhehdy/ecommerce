import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/payments/payments_providers.dart';
import '../../../../core/ui/network_image.dart';
import '../../../../core/ui/shimmer.dart';
import '../../../../core/ui/snackbars.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../application/marketplace_providers.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../widgets/checkout_sheet.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final Set<String> _selectedProductIds = <String>{};
  final Map<String, int> _quantitiesByProductId = <String, int>{};
  String? _checkoutMode;

  bool get _isCheckingOut => _checkoutMode != null;

  int _quantityFor(Product product) {
    final savedQuantity = _quantitiesByProductId[product.id] ?? 1;
    final maxQuantity = product.stockQuantity < 1 ? 1 : product.stockQuantity;
    return savedQuantity.clamp(1, maxQuantity).toInt();
  }

  List<Product> _selectedProducts(List<Product> products) {
    return products
        .where((product) => _selectedProductIds.contains(product.id))
        .toList(growable: false);
  }

  double _selectedTotal(List<Product> products) {
    return _selectedProducts(products).fold<double>(
      0,
      (total, product) => total + (product.price * _quantityFor(product)),
    );
  }

  void _setSelected(Product product, bool selected) {
    if (!product.canOrder) {
      return;
    }

    setState(() {
      if (selected) {
        _selectedProductIds.add(product.id);
        _quantitiesByProductId.putIfAbsent(product.id, () => 1);
      } else {
        _selectedProductIds.remove(product.id);
      }
    });
  }

  void _selectAllAvailable(List<Product> products) {
    final availableIds = products
        .where((product) => product.canOrder)
        .map((product) => product.id)
        .toSet();

    setState(() {
      if (_selectedProductIds.containsAll(availableIds) &&
          availableIds.isNotEmpty) {
        _selectedProductIds.clear();
        return;
      }

      _selectedProductIds
        ..clear()
        ..addAll(availableIds);
      for (final product in products.where((product) => product.canOrder)) {
        _quantitiesByProductId.putIfAbsent(product.id, () => 1);
      }
    });
  }

  void _increaseQuantity(Product product) {
    setState(() {
      final quantity = _quantityFor(product);
      if (quantity < product.stockQuantity) {
        _quantitiesByProductId[product.id] = quantity + 1;
      }
    });
  }

  void _decreaseQuantity(Product product) {
    setState(() {
      final quantity = _quantityFor(product);
      if (quantity > 1) {
        _quantitiesByProductId[product.id] = quantity - 1;
      }
    });
  }

  void _invalidateCheckoutState(List<Product> products) {
    for (final product in products) {
      ref.invalidate(productDetailsProvider(product.id));
    }
    ref.invalidate(homeFeedProvider);
    ref.invalidate(favoriteProductsProvider);
    ref.invalidate(favoriteProductIdsProvider);
    ref.invalidate(purchaseOrdersProvider);
    ref.invalidate(salesOrdersProvider);
  }

  bool _validateSelectedStock(List<Product> selectedProducts) {
    final unavailable = selectedProducts
        .where((product) => !product.canOrder)
        .toList(growable: false);
    if (unavailable.isNotEmpty) {
      AppSnackbars.showError(
        context,
        StateError('${unavailable.first.title} is no longer available.'),
      );
      return false;
    }

    for (final product in selectedProducts) {
      if (_quantityFor(product) > product.stockQuantity) {
        AppSnackbars.showError(
          context,
          StateError('${product.title} has only ${product.stockLabel}.'),
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _openCheckout(List<Product> products) async {
    final selectedProducts = _selectedProducts(products);
    if (selectedProducts.isEmpty) {
      return;
    }

    if (!_validateSelectedStock(selectedProducts)) {
      return;
    }

    final checkout = await showMarketplaceCheckoutSheet(
      context: context,
      items: selectedProducts
          .map(
            (product) => CheckoutSheetItem(
              product: product,
              quantity: _quantityFor(product),
            ),
          )
          .toList(growable: false),
    );

    if (checkout == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final checkoutProducts = checkout.items
        .map((item) => item.product)
        .toList(growable: false);

    if (checkout.method == CheckoutPaymentMethod.meetup) {
      await _checkoutWithMeetup(checkout);
      return;
    }

    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      AppSnackbars.showError(context, StateError('Account email is missing'));
      return;
    }

    setState(() => _checkoutMode = 'paystack');
    final repo = ref.read(marketplaceRepositoryProvider);
    final paymentsRepo = ref.read(paymentsRepositoryProvider);
    MarketplacePaymentBatch? batch;
    var preparingDialogOpen = false;

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
              Expanded(child: Text('Preparing Paystack checkout...')),
            ],
          ),
        );
      },
    );
    preparingDialogOpen = true;

    try {
      batch = await repo.createPaystackPaymentBatch(
        checkout.items
            .map(
              (item) => MarketplaceCheckoutItemRequest(
                productId: item.product.id,
                quantity: item.quantity,
              ),
            )
            .toList(growable: false),
        meetupLocation: checkout.meetupLocation,
      );

      final accessCode = await paymentsRepo.initializePaystack(
        email: email,
        amountKobo: (batch.totalAmount * 100).round(),
        reference: batch.reference,
      );

      if (mounted && preparingDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        preparingDialogOpen = false;
      }

      final paystack = await ref.read(paystackClientProvider.future);
      final transaction = await paystack.launch(accessCode: accessCode);

      if (transaction.status == 'cancelled' || transaction.status == 'failed') {
        await repo.cancelPaymentBatch(batch.id);
        _invalidateCheckoutState(checkoutProducts);

        if (!mounted) {
          return;
        }

        setState(() => _checkoutMode = null);
        AppSnackbars.showSuccess(context, 'Payment cancelled.');
        return;
      }

      final paid = await paymentsRepo.verifyPaystack(
        reference: batch.reference,
      );
      if (!paid) {
        throw StateError('Payment could not be verified.');
      }

      await repo.markPaymentBatchPaid(batch.id);
      _invalidateCheckoutState(checkoutProducts);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedProductIds.clear();
        _checkoutMode = null;
      });

      AppSnackbars.showSuccess(
        context,
        batch.orderIds.length == 1
            ? 'Payment successful. Order created.'
            : 'Payment successful. ${batch.orderIds.length} orders created.',
      );

      if (batch.orderIds.length == 1) {
        context.go('/orders/${batch.orderIds.single}');
      } else {
        context.go('/orders');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (preparingDialogOpen) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }

      if (batch != null) {
        try {
          await repo.cancelPaymentBatch(batch.id);
          _invalidateCheckoutState(checkoutProducts);
        } catch (_) {}
      }

      if (!mounted) {
        return;
      }

      setState(() => _checkoutMode = null);
      AppSnackbars.showError(context, error);
    }
  }

  Future<void> _checkoutWithMeetup(CheckoutSheetResult checkout) async {
    final selectedProducts = checkout.items
        .map((item) => item.product)
        .toList(growable: false);
    if (selectedProducts.isEmpty) {
      return;
    }

    if (!_validateSelectedStock(selectedProducts)) {
      return;
    }

    final meetupBlocked = selectedProducts
        .where((product) => !product.allowMeetupPayment)
        .toList(growable: false);
    if (meetupBlocked.isNotEmpty) {
      AppSnackbars.showError(
        context,
        StateError(
          '${meetupBlocked.first.title} only supports Paystack checkout.',
        ),
      );
      return;
    }

    setState(() => _checkoutMode = 'meetup');
    final repo = ref.read(marketplaceRepositoryProvider);
    final orderIds = <String>[];

    try {
      for (final item in checkout.items) {
        final orderId = await repo.createMeetupOrderForProduct(
          item.product.id,
          quantity: item.quantity,
          meetupLocation: checkout.meetupLocation,
        );
        orderIds.add(orderId);
      }

      _invalidateCheckoutState(selectedProducts);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedProductIds.clear();
        _checkoutMode = null;
      });

      AppSnackbars.showSuccess(
        context,
        orderIds.length == 1
            ? 'Meetup order created.'
            : '${orderIds.length} meetup orders created.',
      );

      if (orderIds.length == 1) {
        context.go('/orders/${orderIds.single}');
      } else {
        context.go('/orders');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _checkoutMode = null);
      AppSnackbars.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(favoriteProductsProvider);
    final products = favoritesAsync.asData?.value ?? const <Product>[];
    final selectedProducts = _selectedProducts(products);
    final selectedTotal = _selectedTotal(products);
    final availableCount = products.where((product) => product.canOrder).length;
    final allAvailableSelected =
        availableCount > 0 &&
        _selectedProductIds.containsAll(
          products
              .where((product) => product.canOrder)
              .map((product) => product.id),
        );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(AppStrings.saved),
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
          if (products.isNotEmpty)
            TextButton(
              onPressed: availableCount == 0
                  ? null
                  : () => _selectAllAvailable(products),
              child: Text(allAvailableSelected ? 'Clear' : 'Select all'),
            ),
        ],
      ),
      bottomNavigationBar: selectedProducts.isEmpty
          ? null
          : _SavedCheckoutBar(
              selectedCount: selectedProducts.length,
              total: selectedTotal,
              isCheckingOut: _isCheckingOut,
              onCheckout: () => _openCheckout(products),
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(favoriteProductsProvider);
          ref.invalidate(favoriteProductIdsProvider);
        },
        child: favoritesAsync.when(
          data: (products) {
            if (products.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(28),
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
                            Icons.favorite_border_rounded,
                            size: 32,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.noFavorites,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the heart on a product to save it here.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => context.go('/home'),
                          child: const Text(AppStrings.browseListings),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: _SavedSummary(
                          savedCount: products.length,
                          selectedCount: selectedProducts.length,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    selectedProducts.isEmpty ? 24 : 130,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                          children: [
                            for (final product in products) ...[
                              _SavedCheckoutCard(
                                product: product,
                                selected: _selectedProductIds.contains(
                                  product.id,
                                ),
                                quantity: _quantityFor(product),
                                onSelected: (selected) =>
                                    _setSelected(product, selected),
                                onIncrease: () => _increaseQuantity(product),
                                onDecrease: () => _decreaseQuantity(product),
                                onOpen: () =>
                                    context.go('/product/${product.id}'),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => _buildShimmerGrid(),
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

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisExtent: 245,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => const ProductCardShimmer(),
    );
  }
}

class _SavedSummary extends StatelessWidget {
  final int savedCount;
  final int selectedCount;

  const _SavedSummary({required this.savedCount, required this.selectedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
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
                  '$savedCount saved item${savedCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  selectedCount == 0
                      ? 'Pick the items you want to checkout now.'
                      : '$selectedCount selected for checkout.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
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

class _SavedCheckoutCard extends StatelessWidget {
  final Product product;
  final bool selected;
  final int quantity;
  final ValueChanged<bool> onSelected;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onOpen;

  const _SavedCheckoutCard({
    required this.product,
    required this.selected,
    required this.quantity,
    required this.onSelected,
    required this.onIncrease,
    required this.onDecrease,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final conditionText = product.condition?.trim();
    final skuText = product.sku?.trim();
    final locationText = product.location?.trim();

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: product.canOrder ? () => onSelected(!selected) : onOpen,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 104,
                  width: 92,
                  child: product.images.isNotEmpty
                      ? AppNetworkImage(url: product.images.first.imageUrl)
                      : Container(
                          color: AppColors.surfaceMuted,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_camera_back_outlined,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'No photo',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Checkbox(
                          value: selected,
                          onChanged: product.canOrder
                              ? (value) => onSelected(value ?? false)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatNaira(product.price),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MiniPill(
                          label: product.canOrder
                              ? product.stockLabel
                              : 'Unavailable',
                          icon: Icons.inventory_2_outlined,
                          warning: !product.canOrder,
                        ),
                        _MiniPill(
                          label: product.allowMeetupPayment
                              ? 'Pay on meetup'
                              : 'Paystack only',
                          icon: product.allowMeetupPayment
                              ? Icons.handshake_outlined
                              : Icons.credit_card_outlined,
                        ),
                        if (conditionText != null && conditionText.isNotEmpty)
                          _MiniPill(
                            label: conditionText,
                            icon: Icons.verified_outlined,
                          ),
                        if (skuText != null && skuText.isNotEmpty)
                          _MiniPill(
                            label: 'SKU: $skuText',
                            icon: Icons.qr_code_2_outlined,
                          ),
                        _MiniPill(
                          label: locationText != null && locationText.isNotEmpty
                              ? locationText
                              : 'Campus pickup',
                          icon: Icons.place_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: onOpen,
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Details'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                        const Spacer(),
                        _QuantityButton(
                          icon: Icons.remove_rounded,
                          enabled: selected && quantity > 1,
                          onPressed: onDecrease,
                          tooltip: 'Decrease quantity',
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '$quantity',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        _QuantityButton(
                          icon: Icons.add_rounded,
                          enabled: selected && quantity < product.stockQuantity,
                          onPressed: onIncrease,
                          tooltip: 'Increase quantity',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool warning;

  const _MiniPill({
    required this.label,
    required this.icon,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: warning ? AppColors.warningSoft : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: warning ? Colors.orange.shade900 : AppColors.primaryDark,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: warning
                      ? Colors.orange.shade900
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  final String tooltip;

  const _QuantityButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 18),
    );
  }
}

class _SavedCheckoutBar extends StatelessWidget {
  final int selectedCount;
  final double total;
  final bool isCheckingOut;
  final VoidCallback onCheckout;

  const _SavedCheckoutBar({
    required this.selectedCount,
    required this.total,
    required this.isCheckingOut,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$selectedCount selected',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  formatNaira(total),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: isCheckingOut ? null : onCheckout,
              icon: isCheckingOut
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
              label: Text(isCheckingOut ? 'Working...' : 'Checkout'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
