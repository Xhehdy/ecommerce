import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/ui/snackbars.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/order_flow.dart';
import '../../application/marketplace_providers.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/marketplace_repository.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not yet';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _meetupLocationFor(MarketplaceOrder order) {
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

  String _paymentMethodFor(MarketplaceOrder order) {
    return switch (order.paymentProvider) {
      'meetup' => 'Pay on meetup',
      'paystack' => 'Paystack',
      _ => 'Not chosen',
    };
  }

  Future<void> _runOrderAction(
    BuildContext context,
    WidgetRef ref, {
    required MarketplaceOrder order,
    required OrderAction action,
  }) async {
    final repo = ref.read(marketplaceRepositoryProvider);

    final shouldConfirm =
        action == OrderAction.cancel ||
        action == OrderAction.confirmMeetupPaid ||
        action == OrderAction.markHandedOver ||
        action == OrderAction.confirmReceived;

    if (shouldConfirm) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(switch (action) {
            OrderAction.cancel => 'Cancel order?',
            OrderAction.confirmMeetupPaid => 'Confirm payment received?',
            OrderAction.markHandedOver => 'Mark as handed over?',
            OrderAction.confirmReceived => 'Confirm you received the item?',
          }),
          content: Text(switch (action) {
            OrderAction.cancel =>
              order.paymentBatchId == null
                  ? 'This releases the reserved listing back to the marketplace.'
                  : 'This cancels the whole Paystack checkout and releases every listing in that checkout.',
            OrderAction.confirmMeetupPaid =>
              'Only confirm after collecting payment during meetup.',
            OrderAction.markHandedOver =>
              'Confirm you have handed the item to the buyer.',
            OrderAction.confirmReceived =>
              'Confirm once you have received the item in good condition.',
          }),
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
        ),
      );

      if (confirmed != true) return;
    }

    try {
      switch (action) {
        case OrderAction.cancel:
          await repo.cancelOrder(order.id);
          break;
        case OrderAction.confirmMeetupPaid:
          await repo.markMeetupOrderPaid(order.id);
          break;
        case OrderAction.markHandedOver:
          await repo.markOrderHandedOver(order.id);
          break;
        case OrderAction.confirmReceived:
          await repo.markOrderReceived(order.id);
          break;
      }

      ref.invalidate(orderDetailsProvider(orderId));
      ref.invalidate(purchaseOrdersProvider);
      ref.invalidate(salesOrdersProvider);
      ref.invalidate(homeFeedProvider);
      ref.invalidate(myListingsProvider);

      if (!context.mounted) return;
      AppSnackbars.showSuccess(context, 'Order updated.');
    } catch (error) {
      if (!context.mounted) return;
      AppSnackbars.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailsProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/orders');
          },
        ),
      ),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Order not found.'));
          }

          final product = order.item?.product;
          final imageUrl = product?.images.isNotEmpty == true
              ? product!.images.first.imageUrl
              : null;
          final quantity = order.item?.quantity ?? 1;
          final meetupLocation = _meetupLocationFor(order);
          final paymentMethod = _paymentMethodFor(order);

          final actions = availableOrderActions(
            role: order.role == MarketplaceOrderRole.buyer
                ? OrderActor.buyer
                : OrderActor.seller,
            status: order.status,
          ).toList(growable: false);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppThemeValues.radius),
                  border: Border.all(color: AppColors.border, width: AppThemeValues.borderWidth),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppThemeValues.radiusSmall),
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
                            : Image.network(imageUrl, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product?.title ?? 'Order ${order.id}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.15,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatNaira(order.totalAmount),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Qty $quantity${order.item == null ? '' : ' at ${formatNaira(order.item!.price)} each'}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              orderStatusLabel(order.status).toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppThemeValues.radius),
                  border: Border.all(color: AppColors.border, width: AppThemeValues.borderWidth),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Checkout details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _TimelineRow(label: 'Meetup', value: meetupLocation),
                    const SizedBox(height: 10),
                    _TimelineRow(label: 'Payment', value: paymentMethod),
                    if (order.paymentReference?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      _TimelineRow(
                        label: 'Reference',
                        value: order.paymentReference!,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppThemeValues.radius),
                  border: Border.all(color: AppColors.border, width: AppThemeValues.borderWidth),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Timeline',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTimelineNode(
                      title: 'Order created',
                      date: order.createdAt,
                      isCompleted: true,
                      isLast: false,
                    ),
                    _buildTimelineNode(
                      title: order.paymentProvider == 'meetup' ? 'Payment during pickup' : 'Payment verified',
                      date: order.paidAt,
                      isCompleted: order.paidAt != null,
                      isLast: false,
                      pendingText: order.paymentProvider == 'meetup' ? 'Pending handoff & payment' : 'Awaiting payment',
                    ),
                    _buildTimelineNode(
                      title: 'Handed over by seller',
                      date: order.handedOverAt,
                      isCompleted: order.handedOverAt != null,
                      isLast: false,
                    ),
                    _buildTimelineNode(
                      title: 'Order completed',
                      date: order.completedAt,
                      isCompleted: order.completedAt != null,
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppThemeValues.radius),
                  border: Border.all(color: AppColors.border, width: AppThemeValues.borderWidth),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Counterparty',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      order.role == MarketplaceOrderRole.buyer
                          ? 'Seller'
                          : 'Buyer',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.counterparty?.displayName ?? 'Unknown',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              if (product != null)
                OutlinedButton.icon(
                  onPressed: () => context.go('/product/${product.id}'),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('View listing'),
                ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final action in actions) ...[
                  ElevatedButton(
                    onPressed: () => _runOrderAction(
                      context,
                      ref,
                      order: order,
                      action: action,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: action == OrderAction.cancel
                          ? AppColors.error
                          : AppColors.primaryDark,
                    ),
                    child: Text(switch (action) {
                      OrderAction.cancel => 'Cancel order',
                      OrderAction.confirmMeetupPaid => 'Confirm meetup payment',
                      OrderAction.markHandedOver => 'Mark handed over',
                      OrderAction.confirmReceived => 'Confirm received',
                    }),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
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

  Widget _buildTimelineNode({
    required String title,
    required DateTime? date,
    required bool isCompleted,
    required bool isLast,
    String pendingText = 'Pending',
  }) {
    final activeColor = AppColors.textPrimary;
    final inactiveColor = AppColors.border;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                height: 14,
                width: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? activeColor : AppColors.surface,
                  border: Border.all(
                    color: isCompleted ? activeColor : inactiveColor,
                    width: 1.5,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: isCompleted ? activeColor : inactiveColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isCompleted ? AppColors.textPrimary : AppColors.textSecondary,
                      letterSpacing: -0.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date != null ? _formatDate(date) : pendingText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String label;
  final String value;

  const _TimelineRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
