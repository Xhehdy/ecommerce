import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../constants/app_durations.dart';

/// A shimmering placeholder used while content is loading.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.shimmerCycle,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _controller.value, 0),
              end: Alignment(1 + 2 * _controller.value, 0),
              colors: const [
                AppColors.surfaceMuted,
                AppColors.border,
                AppColors.surfaceMuted,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// A product-card-shaped shimmer placeholder for grids.
class ProductCardShimmer extends StatelessWidget {
  const ProductCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ShimmerBox(borderRadius: 16)),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 13, width: double.infinity),
                SizedBox(height: 4),
                ShimmerBox(height: 15, width: 80),
                SizedBox(height: 4),
                ShimmerBox(height: 11, width: 100),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: ShimmerBox(height: 28, borderRadius: 999)),
                    SizedBox(width: 6),
                    ShimmerBox(height: 28, width: 28, borderRadius: 999),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
