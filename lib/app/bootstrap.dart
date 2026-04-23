import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<T> bootstrap<T>(Future<T> Function() runner) async {
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

  return runZonedGuarded(runner, (error, stack) {
    if (kDebugMode) {
      debugPrint(error.toString());
      debugPrintStack(stackTrace: stack);
    }
  })!;
}

