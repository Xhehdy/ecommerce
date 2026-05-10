import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/models/product_model.dart';

enum CheckoutPaymentMethod { paystack, meetup }

class CheckoutSheetItem {
  final Product product;
  final int quantity;

  const CheckoutSheetItem({required this.product, required this.quantity});

  double get lineTotal => product.price * quantity;

  CheckoutSheetItem copyWith({int? quantity}) {
    return CheckoutSheetItem(
      product: product,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CheckoutSheetResult {
  final CheckoutPaymentMethod method;
  final String? meetupLocation;
  final List<CheckoutSheetItem> items;
  final double total;

  const CheckoutSheetResult({
    required this.method,
    required this.meetupLocation,
    required this.items,
    required this.total,
  });
}

Future<CheckoutSheetResult?> showMarketplaceCheckoutSheet({
  required BuildContext context,
  required List<CheckoutSheetItem> items,
  bool allowQuantityEditing = false,
}) {
  assert(items.isNotEmpty);

  return showModalBottomSheet<CheckoutSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return _MarketplaceCheckoutSheet(
        items: items,
        allowQuantityEditing: allowQuantityEditing,
      );
    },
  );
}

class _MarketplaceCheckoutSheet extends StatefulWidget {
  final List<CheckoutSheetItem> items;
  final bool allowQuantityEditing;

  const _MarketplaceCheckoutSheet({
    required this.items,
    required this.allowQuantityEditing,
  });

  @override
  State<_MarketplaceCheckoutSheet> createState() =>
      _MarketplaceCheckoutSheetState();
}

class _MarketplaceCheckoutSheetState extends State<_MarketplaceCheckoutSheet> {
  late List<CheckoutSheetItem> _items;
  final TextEditingController _customLocationController =
      TextEditingController();
  CheckoutPaymentMethod _method = CheckoutPaymentMethod.paystack;
  bool _useCustomLocation = false;

  double get _total => _items.fold(0, (total, item) => total + item.lineTotal);

  int get _itemCount => _items.fold(0, (total, item) => total + item.quantity);

  bool get _allAllowMeetup =>
      _items.every((item) => item.product.allowMeetupPayment);

  bool get _canConfirm {
    if (!_useCustomLocation) {
      return true;
    }
    return _customLocationController.text.trim().isNotEmpty;
  }

  String get _defaultMeetupLabel {
    final locations = _items
        .map((item) => item.product.location?.trim())
        .whereType<String>()
        .where((location) => location.isNotEmpty)
        .toSet();

    if (_items.length == 1) {
      return locations.isEmpty ? 'Campus pickup' : locations.single;
    }

    if (locations.length == 1) {
      return locations.single;
    }

    return locations.isEmpty
        ? 'Each seller confirms a campus pickup spot'
        : '${locations.length} seller pickup spots';
  }

  @override
  void initState() {
    super.initState();
    _items = widget.items
        .map(
          (item) =>
              CheckoutSheetItem(product: item.product, quantity: item.quantity),
        )
        .toList(growable: false);
  }

  @override
  void dispose() {
    _customLocationController.dispose();
    super.dispose();
  }

  void _setQuantity(CheckoutSheetItem item, int quantity) {
    final maxQuantity = item.product.stockQuantity < 1
        ? 1
        : item.product.stockQuantity;
    final nextQuantity = quantity.clamp(1, maxQuantity).toInt();
    setState(() {
      _items = [
        for (final current in _items)
          current.product.id == item.product.id
              ? current.copyWith(quantity: nextQuantity)
              : current,
      ];
    });
  }

  void _confirm() {
    Navigator.of(context).pop(
      CheckoutSheetResult(
        method: _method,
        meetupLocation: _useCustomLocation
            ? _customLocationController.text.trim()
            : null,
        items: _items,
        total: _total,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final buttonLabel = _method == CheckoutPaymentMethod.paystack
        ? 'Checkout with Paystack'
        : 'Confirm order';

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Checkout',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_itemCount item${_itemCount == 1 ? '' : 's'} in this checkout',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatNaira(_total),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _CheckoutSection(
                title: 'Items',
                child: Column(
                  children: [
                    for (var index = 0; index < _items.length; index++) ...[
                      _CheckoutItemRow(
                        item: _items[index],
                        allowQuantityEditing: widget.allowQuantityEditing,
                        onDecrease: () => _setQuantity(
                          _items[index],
                          _items[index].quantity - 1,
                        ),
                        onIncrease: () => _setQuantity(
                          _items[index],
                          _items[index].quantity + 1,
                        ),
                      ),
                      if (index != _items.length - 1)
                        const Divider(height: 22, color: AppColors.border),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _CheckoutSection(
                title: 'Meetup',
                child: Column(
                  children: [
                    _CheckoutOptionTile(
                      selected: !_useCustomLocation,
                      icon: Icons.storefront_outlined,
                      title: 'Seller meetup spot',
                      subtitle: _defaultMeetupLabel,
                      onTap: () => setState(() => _useCustomLocation = false),
                    ),
                    const SizedBox(height: 10),
                    _CheckoutOptionTile(
                      selected: _useCustomLocation,
                      icon: Icons.edit_location_alt_outlined,
                      title: 'Suggest a meetup spot',
                      subtitle: 'Add a campus place both sides can confirm.',
                      onTap: () => setState(() => _useCustomLocation = true),
                    ),
                    if (_useCustomLocation) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customLocationController,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Meetup location',
                          hintText: 'Library entrance, 3 PM',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _CheckoutSection(
                title: 'Payment',
                child: Column(
                  children: [
                    _CheckoutOptionTile(
                      selected: _method == CheckoutPaymentMethod.paystack,
                      icon: Icons.credit_card_outlined,
                      title: 'Pay now with Paystack',
                      subtitle: 'Pay now, then meet for handoff.',
                      onTap: () => setState(
                        () => _method = CheckoutPaymentMethod.paystack,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CheckoutOptionTile(
                      selected: _method == CheckoutPaymentMethod.meetup,
                      enabled: _allAllowMeetup,
                      icon: Icons.handshake_outlined,
                      title: 'Pay during meetup',
                      subtitle: _allAllowMeetup
                          ? 'Pay during meetup. Seller confirms receipt.'
                          : 'One selected item requires Paystack.',
                      onTap: _allAllowMeetup
                          ? () => setState(
                              () => _method = CheckoutPaymentMethod.meetup,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _CheckoutTotalBar(
                itemCount: _itemCount,
                total: _total,
                method: _method,
                meetupLabel: _useCustomLocation
                    ? _customLocationController.text.trim()
                    : _defaultMeetupLabel,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _canConfirm ? _confirm : null,
                icon: Icon(
                  _method == CheckoutPaymentMethod.paystack
                      ? Icons.lock_outline_rounded
                      : Icons.check_circle_outline,
                  size: 18,
                ),
                label: Text(buttonLabel),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CheckoutSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _CheckoutSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CheckoutItemRow extends StatelessWidget {
  final CheckoutSheetItem item;
  final bool allowQuantityEditing;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _CheckoutItemRow({
    required this.item,
    required this.allowQuantityEditing,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${formatNaira(item.product.price)} each',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              if (!allowQuantityEditing) ...[
                const SizedBox(height: 4),
                Text(
                  'Qty ${item.quantity}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatNaira(item.lineTotal),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (allowQuantityEditing) ...[
              const SizedBox(height: 8),
              _QuantityStepper(
                quantity: item.quantity,
                canDecrease: item.quantity > 1,
                canIncrease: item.quantity < item.product.stockQuantity,
                onDecrease: onDecrease,
                onIncrease: onIncrease,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _QuantityStepper({
    required this.quantity,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          tooltip: 'Decrease quantity',
          onPressed: canDecrease ? onDecrease : null,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.remove_rounded, size: 17),
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        IconButton.outlined(
          tooltip: 'Increase quantity',
          onPressed: canIncrease ? onIncrease : null,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.add_rounded, size: 17),
        ),
      ],
    );
  }
}

class _CheckoutOptionTile extends StatelessWidget {
  final bool selected;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _CheckoutOptionTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.primary : AppColors.border;
    final foreground = enabled
        ? AppColors.textPrimary
        : AppColors.textSecondary;

    return Material(
      color: selected ? AppColors.successSoft : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: selected ? 1.4 : 1),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: enabled
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutTotalBar extends StatelessWidget {
  final int itemCount;
  final double total;
  final CheckoutPaymentMethod method;
  final String meetupLabel;

  const _CheckoutTotalBar({
    required this.itemCount,
    required this.total,
    required this.method,
    required this.meetupLabel,
  });

  @override
  Widget build(BuildContext context) {
    final paymentLabel = method == CheckoutPaymentMethod.paystack
        ? 'Paystack'
        : 'Meetup payment';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$itemCount item${itemCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                formatNaira(total),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CheckoutTotalFact(
                  label: 'Meetup',
                  value: meetupLabel.isEmpty ? 'Add location' : meetupLabel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CheckoutTotalFact(
                  label: 'Payment',
                  value: paymentLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckoutTotalFact extends StatelessWidget {
  final String label;
  final String value;

  const _CheckoutTotalFact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.66),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
