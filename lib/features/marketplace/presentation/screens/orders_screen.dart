import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../application/marketplace_providers.dart';
import '../../data/models/order_model.dart';
import '../widgets/marketplace_navigation.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Orders'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Purchases'),
              Tab(text: 'Sales'),
            ],
          ),
        ),
        bottomNavigationBar: const MarketplaceBottomNavBar(
          currentTab: MarketplaceTab.orders,
        ),
        body: TabBarView(
          children: [
            _OrdersList(
              ordersAsync: ref.watch(purchaseOrdersProvider),
              emptyTitle: 'No purchases yet',
              emptyMessage:
                  'Place an order from a product page and it will show up here.',
              secondaryMessage:
                  'Browse the marketplace, compare listings, and your next order will be tracked here from the moment you confirm.',
              counterpartyLabel: 'Seller',
              actionLabel: 'Browse Listings',
              actionRoute: '/home',
              onRefresh: (ref) async {
                ref.invalidate(purchaseOrdersProvider);
                await ref.read(purchaseOrdersProvider.future);
              },
            ),
            _OrdersList(
              ordersAsync: ref.watch(salesOrdersProvider),
              emptyTitle: 'No sales yet',
              emptyMessage:
                  'When someone orders one of your listings, it will appear here.',
              secondaryMessage:
                  'Strong photos, clear pricing, and a complete profile make buyers trust your listings faster.',
              counterpartyLabel: 'Buyer',
              actionLabel: 'Open My Listings',
              actionRoute: '/my-listings',
              onRefresh: (ref) async {
                ref.invalidate(salesOrdersProvider);
                await ref.read(salesOrdersProvider.future);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersList extends ConsumerWidget {
  final AsyncValue<List<MarketplaceOrder>> ordersAsync;
  final String emptyTitle;
  final String emptyMessage;
  final String secondaryMessage;
  final String counterpartyLabel;
  final String actionLabel;
  final String actionRoute;
  final Future<void> Function(WidgetRef ref) onRefresh;

  const _OrdersList({
    required this.ordersAsync,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.secondaryMessage,
    required this.counterpartyLabel,
    required this.actionLabel,
    required this.actionRoute,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => onRefresh(ref),
      child: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
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
                          Icons.receipt_long_outlined,
                          size: 36,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        emptyTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        emptyMessage,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        secondaryMessage,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => context.go(actionRoute),
                        child: Text(actionLabel.toUpperCase()),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final order = orders[index];
              final product = order.item?.product;
              final imageUrl = product?.images.isNotEmpty == true
                  ? product!.images.first.imageUrl
                  : null;
              final createdAt = order.createdAt;
              final createdAtLabel = createdAt == null
                  ? 'Unknown date'
                  : '${createdAt.day}/${createdAt.month}/${createdAt.year}';
              final statusLabel = order.status == 'pending'
                  ? 'Awaiting meetup'
                  : order.status.replaceAll('_', ' ').toUpperCase();

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 84,
                              width: 84,
                              child: imageUrl == null
                                  ? Container(
                                      color: AppColors.background,
                                      child: const Icon(
                                        Icons.image_not_supported_outlined,
                                        color: AppColors.textSecondary,
                                      ),
                                    )
                                  : Image.network(imageUrl, fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product?.title ?? 'Order ${order.id}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  formatNaira(order.totalAmount),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$counterpartyLabel: ${order.counterparty?.displayName ?? 'Unknown'}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Created: $createdAtLabel',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  order.role == MarketplaceOrderRole.buyer
                                      ? 'Pickup or delivery details can be coordinated after confirmation.'
                                      : 'Keep the buyer updated so this sale feels reliable.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: order.status == 'pending'
                              ? Colors.orange.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: order.status == 'pending'
                                ? Colors.orange.shade800
                                : Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
            child: Text('Unable to load orders: $error'),
          ),
        ),
      ),
    );
  }
}
