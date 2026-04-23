import 'package:flutter/material.dart';
import '../../app/theme/colors.dart';
import '../errors/error_mapper.dart';

class AppSnackbars {
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primary),
    );
  }

  static void showError(BuildContext context, Object error) {
    final mapped = ErrorMapper.toAppException(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mapped.message), backgroundColor: AppColors.error),
    );
  }
}

