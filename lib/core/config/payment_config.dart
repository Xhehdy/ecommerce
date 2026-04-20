const paystackSandboxSecretKey = String.fromEnvironment(
  'PAYSTACK_TEST_SECRET_KEY',
  defaultValue: '',
);

const paystackCallbackUrl = String.fromEnvironment(
  'PAYSTACK_CALLBACK_URL',
  defaultValue: 'https://atelier.local/paystack-callback',
);
