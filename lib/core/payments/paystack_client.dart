import 'package:paystack_flutter_sdk/paystack_flutter_sdk.dart';

class PaystackClient {
  final Paystack _paystack = Paystack();

  Future<void> initialize({
    required String publicKey,
    bool enableLogging = false,
  }) async {
    await _paystack.initialize(publicKey, enableLogging);
  }

  Future<dynamic> launch({required String accessCode}) {
    return _paystack.launch(accessCode);
  }
}

