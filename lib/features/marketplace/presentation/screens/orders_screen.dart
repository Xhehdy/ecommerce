import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_mapper.dart';
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
          title: const Text(AppStrings.orders),
          bottom: TabBar(
            tabs: const [
              Tab(text: AppStrings.purchases),
              Tab(text: AppStrings.sales),
            ],
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        bottomNavigationBar: const MarketplaceBottomNavBar(
          currentTab: MarketplaceTab.orders,
        ),
        body: TabBarView(
          children: [
            _OrdersList(
              ordersAsync: ref.watch(purchaseOrdersProvider),
              emptyTitle: AppStrings.noPurchases,
              emptyMessage:
                  'Place an order from a product page and it will show up here.',
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
              emptyTitle: AppStrings.noSales,
              emptyMessage:
                  'When someone orders one of your listings, it will appear here.',
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
  final String counterpartyLabel;
  final String actionLabel;
  final String actionRoute;
  final Future<void> Function(WidgetRef ref) onRefresh;

  const _OrdersList({
    required this.ordersAsync,
    required this.emptyTitle,
    required this.emptyMessage,
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
                const SizedBox(height: 40),
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
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        emptyMessage,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
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
            separatorBuilder: (_, __) => const SizedBox(height: 14),
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
              final statusLabel = order.isPending
                  ? 'AWAITING PAYMENT'
                  : order.status.replaceAll('_', ' ').toUpperCase();

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: product != null
                      ? () => context.push('/product/${product.id}')
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                height: 84,
                                width: 84,
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
                                    product?.title ?? 'Order ${order.id}',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    formatNaira(order.totalAmount),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$counterpartyLabel: ${order.counterparty?.displayName ?? 'Unknown'}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    createdAtLabel,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: order.isPending
                                ? Colors.orange.shade50
                                : AppColors.successSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: order.isPending
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
    );
  }
}
