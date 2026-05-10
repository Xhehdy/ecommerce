import 'dart:async';

import 'package:flutter/foundation.dart';

Future<T> bootstrap<T>(Future<T> Function() runner) async {
  return runZonedGuarded(
    () async {
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        if (kDebugMode) {
          debugPrint(error.toString());
          debugPrintStack(stackTrace: stack);
        }
        return true;
      };

      return runner();
    },
    (error, stack) {
      if (kDebugMode) {
        debugPrint(error.toString());
        debugPrintStack(stackTrace: stack);
      }
    },
  )!;
}
