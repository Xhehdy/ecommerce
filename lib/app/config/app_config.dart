class AppConfig {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String paystackPublicKey;
  final String? authRedirectUrl;

  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.paystackPublicKey,
    this.authRedirectUrl,
  });

  factory AppConfig.fromEnvironment() {
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const paystackPublicKey = String.fromEnvironment('PAYSTACK_PUBLIC_KEY');
    const authRedirectUrl = String.fromEnvironment('AUTH_REDIRECT_URL');

    if (supabaseUrl.isEmpty ||
        supabaseAnonKey.isEmpty ||
        paystackPublicKey.isEmpty) {
      throw StateError(
        'Missing build-time config. Provide SUPABASE_URL, SUPABASE_ANON_KEY, PAYSTACK_PUBLIC_KEY via --dart-define.',
      );
    }

    return AppConfig(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      paystackPublicKey: paystackPublicKey,
      authRedirectUrl: authRedirectUrl.isEmpty ? null : authRedirectUrl,
    );
  }
}
