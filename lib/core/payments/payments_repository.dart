import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentsRepository {
  final SupabaseClient _client;

  const PaymentsRepository(this._client);

  Future<String> initializePaystack({
    required String email,
    required int amountKobo,
    required String reference,
  }) async {
    final res = await _client.functions.invoke(
      'paystack-initialize',
      body: {
        'email': email,
        'amountKobo': amountKobo,
        'reference': reference,
      },
    );

    final data = res.data;
    if (data is! Map) {
      throw StateError('Paystack initialize did not return valid data.');
    }

    final accessCode = data['accessCode'];
    if (accessCode is! String || accessCode.isEmpty) {
      throw StateError('Paystack initialize did not return accessCode.');
    }

    return accessCode;
  }

  Future<bool> verifyPaystack({required String reference}) async {
    final res = await _client.functions.invoke(
      'paystack-verify',
      body: {'reference': reference},
    );

    final data = res.data;
    if (data is! Map) {
      throw StateError('Paystack verify did not return valid data.');
    }

    final paid = data['paid'];
    if (paid is! bool) {
      throw StateError('Paystack verify did not return paid.');
    }

    return paid;
  }
}

