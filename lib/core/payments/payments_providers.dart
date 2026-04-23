import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import 'payments_repository.dart';
import 'paystack_client.dart';
import '../../app/config/app_config_provider.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepository(ref.watch(supabaseClientProvider));
});

final paystackClientProvider = FutureProvider<PaystackClient>((ref) async {
  final client = PaystackClient();
  final config = ref.watch(appConfigProvider);
  await client.initialize(publicKey: config.paystackPublicKey);
  return client;
});
