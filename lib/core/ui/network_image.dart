import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';

class AppNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          color: AppColors.surfaceMuted,
          alignment: Alignment.center,
          child: const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppColors.surfaceMuted,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            color: AppColors.textSecondary,
          ),
        );
      },
    );
  }
}
