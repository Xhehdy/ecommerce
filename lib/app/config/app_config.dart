class AppConfig {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String paystackPublicKey;

  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.paystackPublicKey,
  });

  factory AppConfig.fromEnvironment() {
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const paystackPublicKey = String.fromEnvironment('PAYSTACK_PUBLIC_KEY');

    if (supabaseUrl.isEmpty ||
        supabaseAnonKey.isEmpty ||
        paystackPublicKey.isEmpty) {
      throw StateError(
        'Missing build-time config. Provide SUPABASE_URL, SUPABASE_ANON_KEY, PAYSTACK_PUBLIC_KEY via --dart-define.',
      );
    }

    return const AppConfig(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      paystackPublicKey: paystackPublicKey,
    );
  }
}

