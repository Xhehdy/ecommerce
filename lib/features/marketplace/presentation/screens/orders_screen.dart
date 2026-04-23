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
          title: const Text(AppStrings.orders, style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: const TabBar(
            tabs: [
              Tab(text: AppStrings.purchases),
              Tab(text: AppStrings.sales),
            ],
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: AppColors.primaryDark,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            dividerColor: AppColors.border,
          ),
        ),
        bottomNavigationBar: const MarketplaceBottomNavBar(
          currentTab: MarketplaceTab.orders,
        ),
        body: TabBarView(
          children: [
            _OrdersList(
              ordersAsync: ref.watch(purchaseOrdersProvider),
              isPurchases: true,
              onRefresh: (ref) async {
                ref.invalidate(purchaseOrdersProvider);
                await ref.read(purchaseOrdersProvider.future);
              },
            ),
            _OrdersList(
              ordersAsync: ref.watch(salesOrdersProvider),
              isPurchases: false,
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
  final bool isPurchases;
  final Future<void> Function(WidgetRef ref) onRefresh;

  const _OrdersList({
    required this.ordersAsync,
    required this.isPurchases,
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
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
                        child: Icon(
                          isPurchases ? Icons.shopping_bag_outlined : Icons.storefront_outlined,
                          size: 32,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        isPurchases ? 'No purchases yet' : 'No sales yet',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isPurchases 
                          ? 'When you place an order, it will appear here.'
                          : 'When someone buys from you, it will appear here.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed: () => context.go(isPurchases ? '/home' : '/my-listings'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                        child: Text(isPurchases ? 'Browse listings' : 'Manage my listings'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (isPurchases)
                  _InfoTile(
                    title: 'Need help with an order?',
                    subtitle: 'Visit our Help Center for guides and support.',
                    icon: Icons.chevron_right_rounded,
                    isActionIcon: true,
                  )
                else
                  _InfoTile(
                    title: 'Tips to sell faster',
                    subtitle: 'Add clear photos, write good descriptions and set fair prices.',
                    icon: Icons.trending_up_rounded,
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
              final counterpartyLabel = isPurchases ? 'Seller' : 'Buyer';

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
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatNaira(order.totalAmount),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$counterpartyLabel: ${order.counterparty?.displayName ?? 'Unknown'}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 2),
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

class _InfoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActionIcon;

  const _InfoTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isActionIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (isActionIcon)
            Icon(icon, color: AppColors.textSecondary)
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
        ],
      ),
    );
  }
}
