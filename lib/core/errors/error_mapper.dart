import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_exception.dart';

class ErrorMapper {
  static AppException toAppException(Object error) {
    if (error is AppException) {
      return error;
    }
    if (error is StateError) {
      return AppException(
        AppErrorKind.validation,
        error.message ?? 'Invalid input. Please check and try again.',
        cause: error,
      );
    }
    if (error is FormatException) {
      return AppException(
        AppErrorKind.validation,
        error.message,
        cause: error,
      );
    }
    if (error is AuthException) {
      return AppException(AppErrorKind.auth, error.message, cause: error);
    }
    if (error is PostgrestException) {
      return AppException(AppErrorKind.network, error.message, cause: error);
    }
    if (error is StorageException) {
      return AppException(AppErrorKind.network, error.message, cause: error);
    }
    return AppException(
      AppErrorKind.unknown,
      'Something went wrong. Please try again.',
      cause: error,
    );
  }
}
