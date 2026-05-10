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

String _orderMeetupLabel(MarketplaceOrder order) {
  final orderLocation = order.meetupLocation?.trim();
  if (orderLocation != null && orderLocation.isNotEmpty) {
    return orderLocation;
  }

  final productLocation = order.item?.product?.location?.trim();
  if (productLocation != null && productLocation.isNotEmpty) {
    return productLocation;
  }

  return 'Campus pickup';
}

Color _orderAccentColor(String status) {
  return switch (status) {
    'completed' => AppColors.primaryDark,
    'cancelled' => AppColors.error,
    'pending_payment' || 'pending_meetup' => Colors.orange.shade800,
    _ => AppColors.primary,
  };
}

IconData _orderAccentIcon(String status) {
  return switch (status) {
    'pending' => Icons.location_on_outlined,
    'pending_payment' => Icons.payment_rounded,
    'pending_meetup' => Icons.location_on_outlined,
    'awaiting_handoff' => Icons.location_on_outlined,
    'handed_over' => Icons.verified_outlined,
    'completed' => Icons.check_circle_outline,
    'cancelled' => Icons.cancel_outlined,
    _ => Icons.receipt_long_outlined,
  };
}

String _orderStatusBadgeLabel(String status) {
  return switch (status) {
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    _ => 'Active',
  };
}

String _orderActionTitle(MarketplaceOrder order, bool isPurchases) {
  return switch (order.status) {
    'pending_payment' => 'Finish checkout',
    'pending' ||
    'pending_meetup' ||
    'awaiting_handoff' ||
    'handed_over' => isPurchases ? 'Track order' : 'Manage sale',
    'completed' => 'Order completed',
    'cancelled' => 'Order cancelled',
    _ => 'Review order',
  };
}

String _orderActionSubtitle(MarketplaceOrder order, bool isPurchases) {
  final meetupLabel = _orderMeetupLabel(order);

  return switch (order.status) {
    'pending_payment' => 'Complete payment to keep this order active.',
    'pending' =>
      isPurchases
          ? 'Meet seller at $meetupLabel'
          : 'Meet buyer at $meetupLabel',
    'pending_meetup' =>
      isPurchases
          ? 'Meet seller at $meetupLabel'
          : 'Meet buyer at $meetupLabel',
    'awaiting_handoff' =>
      isPurchases
          ? 'Meet seller at $meetupLabel'
          : 'Prepare handoff at $meetupLabel',
    'handed_over' =>
      isPurchases
          ? 'Confirm when the item is with you.'
          : 'Waiting for buyer confirmation.',
    'completed' => 'This order has been completed.',
    'cancelled' => 'This order has been cancelled.',
    _ => 'Open the order for details.',
  };
}

String _orderPaymentLabel(MarketplaceOrder order) {
  if (order.paymentProvider == 'paystack') {
    return 'Paystack';
  }

  if (order.status == 'pending_meetup') {
    return 'Meetup payment';
  }

  return 'Chosen at checkout';
}

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        bottomNavigationBar: const MarketplaceBottomNavBar(
          currentTab: MarketplaceTab.orders,
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _OrdersHeader(),
              const _OrdersSegmentedTabs(),
              Expanded(
                child: TabBarView(
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
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          Text(
            AppStrings.orders,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () => context.push('/notifications'),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.textPrimary,
                  size: 30,
                ),
              ),
              Positioned(
                top: 8,
                right: 10,
                child: Container(
                  height: 9,
                  width: 9,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrdersSegmentedTabs extends StatelessWidget {
  const _OrdersSegmentedTabs();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(width: 1, height: 26, color: AppColors.border),
            TabBar(
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: AppColors.primary, width: 3),
                insets: EdgeInsets.symmetric(horizontal: 48),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.primaryDark,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              tabs: const [
                _OrdersTab(
                  icon: Icons.shopping_bag_outlined,
                  label: AppStrings.purchases,
                ),
                _OrdersTab(
                  icon: Icons.storefront_outlined,
                  label: AppStrings.sales,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OrdersTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Text(label),
        ],
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 40,
                  ),
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
                          isPurchases
                              ? Icons.shopping_bag_outlined
                              : Icons.storefront_outlined,
                          size: 32,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        isPurchases ? 'No purchases yet' : 'No sales yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isPurchases
                            ? 'When you place an order, it will appear here.'
                            : 'When someone buys from you, it will appear here.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed: () =>
                            context.go(isPurchases ? '/home' : '/my-listings'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          isPurchases
                              ? 'Browse listings'
                              : 'Manage my listings',
                        ),
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
                    onTap: () => context.push('/help'),
                  )
                else
                  _InfoTile(
                    title: 'Tips to sell faster',
                    subtitle:
                        'Add clear photos, write good descriptions and set fair prices.',
                    icon: Icons.trending_up_rounded,
                  ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: orders.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 18),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _OrdersSummary(orders: orders, isPurchases: isPurchases);
              }

              final order = orders[index - 1];
              return _OrderCard(order: order, isPurchases: isPurchases);
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

class _OrderCard extends StatelessWidget {
  final MarketplaceOrder order;
  final bool isPurchases;

  const _OrderCard({required this.order, required this.isPurchases});

  @override
  Widget build(BuildContext context) {
    final product = order.item?.product;
    final imageUrl = product?.images.isNotEmpty == true
        ? product!.images.first.imageUrl
        : null;
    final createdAt = order.createdAt;
    final createdAtLabel = createdAt == null
        ? 'Unknown date'
        : '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    final statusLabel = _orderStatusBadgeLabel(order.status).toUpperCase();
    final counterpartyRoleLabel = isPurchases
        ? 'Campus seller'
        : 'Campus buyer';
    final quantity = order.item?.quantity ?? 1;
    final meetupLabel = _orderMeetupLabel(order);
    final accentColor = _orderAccentColor(order.status);
    final counterpartyName = order.counterparty?.displayName ?? 'Unknown';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.go('/orders/${order.id}'),
        child: Container(
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: SizedBox(
                        height: 104,
                        width: 104,
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
                                errorBuilder: (_, _, _) => Container(
                                  color: AppColors.surfaceMuted,
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  product?.title ?? 'Order ${order.id}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _OrderStatusBadge(
                                label: statusLabel,
                                color: accentColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formatNaira(order.totalAmount),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  counterpartyName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  counterpartyRoleLabel,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _OrderActionRow(
                title: _orderActionTitle(order, isPurchases),
                subtitle: _orderActionSubtitle(order, isPurchases),
                icon: _orderAccentIcon(order.status),
                color: accentColor,
                isDestructive: order.status == 'cancelled',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Divider(height: 22, color: AppColors.border),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                child: _OrderFactsRow(
                  facts: [
                    _OrderFact(
                      icon: Icons.inventory_2_outlined,
                      label: 'Qty',
                      value: '$quantity',
                    ),
                    _OrderFact(
                      icon: Icons.credit_card_outlined,
                      label: 'Payment',
                      value: _orderPaymentLabel(order),
                    ),
                    _OrderFact(
                      icon: Icons.location_on_outlined,
                      label: 'Meetup',
                      value: meetupLabel,
                    ),
                    _OrderFact(
                      icon: Icons.calendar_month_outlined,
                      label: 'Date',
                      value: createdAtLabel,
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

class _OrderActionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDestructive;

  const _OrderActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isDestructive,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDestructive
        ? AppColors.error.withValues(alpha: 0.08)
        : AppColors.surfaceMuted;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
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

class _OrderFactsRow extends StatelessWidget {
  final List<_OrderFact> facts;

  const _OrderFactsRow({required this.facts});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < facts.length; index++) ...[
          Expanded(child: facts[index]),
          if (index != facts.length - 1)
            Container(
              width: 1,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              color: AppColors.border,
            ),
        ],
      ],
    );
  }
}

class _OrderStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _OrderStatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _OrderFact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _OrderFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrdersSummary extends StatelessWidget {
  final List<MarketplaceOrder> orders;
  final bool isPurchases;

  const _OrdersSummary({required this.orders, required this.isPurchases});

  @override
  Widget build(BuildContext context) {
    final activeCount = orders
        .where(
          (order) => order.status != 'completed' && order.status != 'cancelled',
        )
        .length;
    final cancelledCount = orders
        .where((order) => order.status == 'cancelled')
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _SummaryMetric(
            icon: isPurchases
                ? Icons.shopping_bag_outlined
                : Icons.storefront_outlined,
            label: 'Orders',
            value: '${orders.length}',
            color: AppColors.primary,
          ),
          const _SummaryDivider(),
          _SummaryMetric(
            icon: Icons.schedule_rounded,
            label: 'Active',
            value: '$activeCount',
            color: AppColors.primary,
          ),
          const _SummaryDivider(),
          _SummaryMetric(
            icon: Icons.cancel_outlined,
            label: 'Cancelled',
            value: '$cancelledCount',
            color: AppColors.error,
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.border,
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActionIcon;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isActionIcon = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
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
        ),
      ),
    );
  }
}
