import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paystack_for_flutter/paystack_for_flutter.dart';

import '../config/payment_config.dart';

final paystackServiceProvider = Provider<PaystackService>((ref) {
  return PaystackService();
});

enum PaystackPaymentStatus { successful, cancelled, timedOut }

class PaystackPaymentResult {
  final PaystackPaymentStatus status;
  final String? reference;

  const PaystackPaymentResult({
    required this.status,
    this.reference,
  });

  bool get isSuccessful => status == PaystackPaymentStatus.successful;

  bool get isTimedOut => status == PaystackPaymentStatus.timedOut;
}

class PaystackService {
  static const _paymentFlowTimeout = Duration(minutes: 5);

  Future<PaystackPaymentResult> chargeSandboxPayment({
    required BuildContext context,
    required double amount,
    required String email,
    String? fullName,
    Map<String, dynamic> metadata = const {},
  }) async {
    final normalizedSecretKey = paystackSandboxSecretKey.trim();
    if (normalizedSecretKey.isEmpty) {
      throw StateError(
        'Paystack sandbox key missing. Pass --dart-define=PAYSTACK_TEST_SECRET_KEY=sk_test_xxx when running the app.',
      );
    }

    if (!normalizedSecretKey.startsWith('sk_test_')) {
      throw StateError(
        'Only Paystack sandbox keys are allowed in this app flow. Use a key that starts with sk_test_.',
      );
    }

    final lowestUnitAmount = (amount * 100).round();
    if (lowestUnitAmount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    final emailAddress = email.trim();
    if (emailAddress.isEmpty) {
      throw ArgumentError('A valid customer email is required.');
    }

    final firstName = _extractFirstName(fullName);
    final lastName = _extractLastName(fullName);
    final completer = Completer<PaystackPaymentResult>();

    await PaystackFlutter().pay(
      context: context,
      secretKey: normalizedSecretKey,
      callbackUrl: paystackCallbackUrl,
      amount: lowestUnitAmount.toDouble(),
      email: emailAddress,
      firstName: firstName,
      lastName: lastName,
      currency: Currency.NGN,
      paymentOptions: const [
        PaymentOption.card,
        PaymentOption.bankTransfer,
        PaymentOption.ussd,
      ],
      metaData: metadata,
      onSuccess: (paystackCallback) {
        if (!completer.isCompleted) {
          completer.complete(
            PaystackPaymentResult(
              status: PaystackPaymentStatus.successful,
              reference: paystackCallback.reference,
            ),
          );
        }
      },
      onCancelled: (paystackCallback) {
        if (!completer.isCompleted) {
          completer.complete(
            PaystackPaymentResult(
              status: PaystackPaymentStatus.cancelled,
              reference: paystackCallback.reference,
            ),
          );
        }
      },
    );

    return completer.future.timeout(
      _paymentFlowTimeout,
      onTimeout: () =>
          const PaystackPaymentResult(status: PaystackPaymentStatus.timedOut),
    );
  }

  String _extractFirstName(String? fullName) {
    final normalized = fullName?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'Campus';
    }
    return normalized.split(RegExp(r'\s+')).first;
  }

  String _extractLastName(String? fullName) {
    final normalized = fullName?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'Buyer';
    }

    final parts = normalized.split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return 'Buyer';
    }

    return parts.sublist(1).join(' ');
  }
}
