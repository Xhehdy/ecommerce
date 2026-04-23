enum AppErrorKind { auth, network, validation, notFound, conflict, unknown }

class AppException implements Exception {
  final AppErrorKind kind;
  final String message;
  final Object? cause;

  const AppException(this.kind, this.message, {this.cause});

  @override
  String toString() => message;
}

