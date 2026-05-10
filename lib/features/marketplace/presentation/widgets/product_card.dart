import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/ui/network_image.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/models/product_model.dart';

class ProductCard extends StatefulWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tapController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final statusLabel = product.canOrder
        ? _statusLabel(product.status)
        : 'Out of stock';
    final statusBackground = product.canOrder
        ? _statusBackground(product.status)
        : AppColors.warningSoft;
    final statusForeground = product.canOrder
        ? _statusForeground(product.status)
        : Colors.orange.shade900;
    final conditionText = product.condition?.trim();
    final locationText = product.location?.trim();
    final skuText = product.sku?.trim();
    final metaText = [
      if (conditionText != null && conditionText.isNotEmpty) conditionText,
      if (skuText != null && skuText.isNotEmpty) skuText,
      if (locationText != null && locationText.isNotEmpty)
        'Pickup at $locationText'
      else
        'Campus pickup',
    ].join(' · ');

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(scale: _scaleAnimation.value, child: child);
      },
      child: GestureDetector(
        onTapDown: (_) => _tapController.forward(),
        onTapUp: (_) {
          _tapController.reverse();
          context.go('/product/${product.id}');
        },
        onTapCancel: () => _tapController.reverse(),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Image ──
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: AppColors.surfaceMuted,
                      child: product.images.isNotEmpty
                          ? AppNetworkImage(url: product.images.first.imageUrl)
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.photo_camera_back_outlined,
                                  color: AppColors.textSecondary,
                                  size: 32,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'No photo',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    // ── Status badge ──
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusBackground,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusForeground,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Info ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatNaira(product.price),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metaText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ── Bottom row ──
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              product.status == 'available'
                                  ? product.stockLabel
                                  : 'Unavailable',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          height: 28,
                          width: 28,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Icon(
                            Icons.arrow_outward_rounded,
                            size: 14,
                            color: AppColors.textPrimary,
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
      ),
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'sold' => 'Sold',
      'reserved' => 'Reserved',
      _ => 'Available',
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
      'sold' => Colors.orange.shade900,
      'reserved' => const Color(0xFF2F4A9E),
      _ => AppColors.primaryDark,
    };
  }
}
