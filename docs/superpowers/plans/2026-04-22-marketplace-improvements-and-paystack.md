# Marketplace Improvements + Paystack Checkout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (recommended) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve app quality (config, routing, error handling, UX/accessibility) and add Paystack payments for orders with a secure server-initialized flow.

**Architecture:** Introduce a small config layer (`AppConfig`) for build-time secrets, centralize error-to-message mapping, make `GoRouter` auth redirects reactive via auth state stream, and implement Paystack via Supabase Edge Functions (server initializes + verifies Paystack transactions; the client only uses Paystack public key + access_code).

**Tech Stack:** Flutter, Riverpod, go_router, Supabase (Postgres + Edge Functions), Paystack Flutter SDK (`paystack_flutter_sdk`)

---

## File Map

**Create**
- `lib/app/bootstrap.dart`
- `lib/app/config/app_config.dart`
- `lib/app/config/app_config_provider.dart`
- `lib/core/errors/app_exception.dart`
- `lib/core/errors/error_mapper.dart`
- `lib/core/ui/snackbars.dart`
- `lib/core/ui/network_image.dart`
- `lib/core/payments/paystack_client.dart`
- `lib/core/payments/payments_repository.dart`

**Modify**
- `lib/main.dart`
- `lib/app/router.dart`
- `lib/features/marketplace/presentation/screens/product_detail_screen.dart`
- `lib/features/marketplace/presentation/screens/create_listing_screen.dart`
- `lib/features/marketplace/data/repositories/marketplace_repository.dart`
- `lib/features/marketplace/data/models/order_model.dart`
- `supabase/schema.sql`
- `pubspec.yaml`
- `android/app/src/main/kotlin/com/example/ecommerce/MainActivity.kt` (only if Paystack SDK requires it for this project setup)

**Create (Supabase Edge Functions)**
- `supabase/functions/paystack-initialize/index.ts`
- `supabase/functions/paystack-verify/index.ts`

---

### Task 1: Build-Time Config + Bootstrap

**Files:**
- Create: `lib/app/config/app_config.dart`
- Create: `lib/app/config/app_config_provider.dart`
- Create: `lib/app/bootstrap.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Add AppConfig**

```dart
// lib/app/config/app_config.dart
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

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty || paystackPublicKey.isEmpty) {
      throw StateError('Missing build-time config. Provide SUPABASE_URL, SUPABASE_ANON_KEY, PAYSTACK_PUBLIC_KEY via --dart-define.');
    }

    return const AppConfig(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      paystackPublicKey: paystackPublicKey,
    );
  }
}
```

- [ ] **Step 2: Add Riverpod provider for AppConfig**

```dart
// lib/app/config/app_config_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_config.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});
```

- [ ] **Step 3: Add bootstrap() to wire global error hooks**

```dart
// lib/app/bootstrap.dart
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
  });
}
```

- [ ] **Step 4: Update main() to use AppConfig + bootstrap**

```dart
// lib/main.dart (conceptual)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap(() async {
    final config = AppConfig.fromEnvironment();
    await Supabase.initialize(url: config.supabaseUrl, anonKey: config.supabaseAnonKey);
    runApp(const ProviderScope(child: MyApp()));
  });
}
```

---

### Task 2: Error Model + SnackBar Helpers

**Files:**
- Create: `lib/core/errors/app_exception.dart`
- Create: `lib/core/errors/error_mapper.dart`
- Create: `lib/core/ui/snackbars.dart`
- Modify: `lib/features/marketplace/presentation/screens/product_detail_screen.dart`
- Modify: `lib/features/marketplace/presentation/screens/create_listing_screen.dart`

- [ ] **Step 1: Add AppException**

```dart
// lib/core/errors/app_exception.dart
enum AppErrorKind { auth, network, validation, notFound, conflict, unknown }

class AppException implements Exception {
  final AppErrorKind kind;
  final String message;
  final Object? cause;

  const AppException(this.kind, this.message, {this.cause});

  @override
  String toString() => message;
}
```

- [ ] **Step 2: Add ErrorMapper**

```dart
// lib/core/errors/error_mapper.dart
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_exception.dart';

class ErrorMapper {
  static AppException toAppException(Object error) {
    if (error is AppException) return error;
    if (error is AuthException) return AppException(AppErrorKind.auth, error.message, cause: error);
    if (error is PostgrestException) return AppException(AppErrorKind.network, error.message, cause: error);
    if (error is StorageException) return AppException(AppErrorKind.network, error.message, cause: error);
    return AppException(AppErrorKind.unknown, 'Something went wrong. Please try again.', cause: error);
  }
}
```

- [ ] **Step 3: Add SnackBar helpers**

```dart
// lib/core/ui/snackbars.dart
import 'package:flutter/material.dart';
import '../../app/theme/colors.dart';
import '../errors/error_mapper.dart';

class AppSnackbars {
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primary),
    );
  }

  static void showError(BuildContext context, Object error) {
    final mapped = ErrorMapper.toAppException(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mapped.message), backgroundColor: AppColors.error),
    );
  }
}
```

- [ ] **Step 4: Replace raw `$error` SnackBars in key flows**
  - `CreateListingScreen` submit errors use `AppSnackbars.showError(context, e)`
  - `ProductDetailScreen` action errors use `AppSnackbars.showError(context, error)`

---

### Task 3: Reactive Auth Routing + Router Error Page

**Files:**
- Modify: `lib/app/router.dart`
- Create: `lib/app/router_error_screen.dart` (optional small screen, or inline builder)

- [ ] **Step 1: Wire GoRouterRefreshStream to Supabase auth state**

```dart
final authChanges = Supabase.instance.client.auth.onAuthStateChange;
refreshListenable: GoRouterRefreshStream(authChanges),
```

- [ ] **Step 2: Add errorBuilder**

```dart
errorBuilder: (context, state) => Scaffold(
  body: Center(child: Text(state.error?.toString() ?? 'Page not found')),
),
```

---

### Task 4: UX/Accessibility Polish (Listing + Images + Validation)

**Files:**
- Create: `lib/core/ui/network_image.dart`
- Modify: `lib/features/marketplace/presentation/screens/create_listing_screen.dart`

- [ ] **Step 1: Add a reusable network image widget (placeholder + error)**

```dart
// lib/core/ui/network_image.dart
import 'package:flutter/material.dart';

class AppNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const AppNetworkImage({super.key, required this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(child: Icon(Icons.broken_image_outlined));
      },
    );
  }
}
```

- [ ] **Step 2: Replace `GestureDetector` icon-only actions with `IconButton` where possible**
  - Image remove “X” becomes `IconButton(tooltip: 'Remove photo', ...)`

- [ ] **Step 3: Harden listing price validation**
  - Validator uses `double.tryParse`
  - Prevents submission with a field-level error instead of a generic toast

---

### Task 5: Paystack Payments (Secure Flow)

**Goal Flow:**
1) Create pending order (reserves product)  
2) Initialize Paystack on server (Edge Function; uses secret key) and return `access_code`  
3) Launch Paystack SDK with `access_code`  
4) Verify payment on server (Edge Function) and mark order paid in DB

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/payments/paystack_client.dart`
- Create: `lib/core/payments/payments_repository.dart`
- Modify: `lib/features/marketplace/data/repositories/marketplace_repository.dart`
- Modify: `lib/features/marketplace/presentation/screens/product_detail_screen.dart`
- Modify: `lib/features/marketplace/data/models/order_model.dart`
- Modify: `supabase/schema.sql`
- Create: `supabase/functions/paystack-initialize/index.ts`
- Create: `supabase/functions/paystack-verify/index.ts`

- [ ] **Step 1: Add dependency**

```yaml
dependencies:
  paystack_flutter_sdk: ^0.0.1-alpha.2
```

- [ ] **Step 2: Update DB schema + RPC**
  - Add `products.status` value `reserved`
  - Add `orders` fields: `payment_provider`, `payment_reference`, `paid_at`
  - Replace `create_marketplace_order` with:
    - `create_marketplace_order_pending(target_product_id uuid)` (sets product reserved, order status `pending_payment`)
    - `mark_marketplace_order_paid(target_order_id uuid)` (sets `paid`, sets product sold)
    - `cancel_marketplace_order(target_order_id uuid)` (sets `cancelled`, sets product available)
  - Update `products` SELECT RLS policy to allow buyers with an order to read reserved/sold products referenced by their orders

- [ ] **Step 3: Implement Supabase Edge Function: paystack-initialize**

```ts
// supabase/functions/paystack-initialize/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async (req) => {
  const secretKey = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "";
  if (!secretKey) return new Response(JSON.stringify({ error: "Missing PAYSTACK_SECRET_KEY" }), { status: 500 });

  const { email, amountKobo, reference } = await req.json();

  const response = await fetch("https://api.paystack.co/transaction/initialize", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${secretKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ email, amount: amountKobo, reference }),
  });

  const json = await response.json();
  if (!response.ok || !json?.status) {
    return new Response(JSON.stringify({ error: json?.message ?? "Unable to initialize payment" }), { status: 400 });
  }

  return new Response(JSON.stringify({ accessCode: json.data.access_code, reference: json.data.reference }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

- [ ] **Step 4: Implement Supabase Edge Function: paystack-verify**

```ts
// supabase/functions/paystack-verify/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async (req) => {
  const secretKey = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "";
  if (!secretKey) return new Response(JSON.stringify({ error: "Missing PAYSTACK_SECRET_KEY" }), { status: 500 });

  const { reference } = await req.json();
  const response = await fetch(`https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`, {
    headers: { Authorization: `Bearer ${secretKey}` },
  });

  const json = await response.json();
  if (!response.ok || !json?.status) {
    return new Response(JSON.stringify({ error: json?.message ?? "Unable to verify payment" }), { status: 400 });
  }

  const paid = json.data?.status === "success";
  return new Response(JSON.stringify({ paid, rawStatus: json.data?.status }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

- [ ] **Step 5: Client-side Paystack client**

```dart
// lib/core/payments/paystack_client.dart
import 'package:paystack_flutter_sdk/paystack_flutter_sdk.dart';

class PaystackClient {
  final Paystack _paystack = Paystack();

  Future<void> initialize({required String publicKey}) async {
    await _paystack.initialize(publicKey, false);
  }

  Future<TransactionResponse> launch({required String accessCode}) {
    return _paystack.launch(accessCode);
  }
}
```

- [ ] **Step 6: PaymentsRepository (initialize + verify via Supabase functions)**

```dart
// lib/core/payments/payments_repository.dart
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
      body: {'email': email, 'amountKobo': amountKobo, 'reference': reference},
    );
    return (res.data as Map)['accessCode'] as String;
  }

  Future<bool> verifyPaystack({required String reference}) async {
    final res = await _client.functions.invoke('paystack-verify', body: {'reference': reference});
    return (res.data as Map)['paid'] as bool;
  }
}
```

- [ ] **Step 7: Update marketplace repo + UI to use payment flow**
  - `create_marketplace_order_pending(productId)` returns `orderId`
  - Initialize Paystack with `reference = orderId`
  - Launch SDK
  - Verify and mark paid; else cancel

---

### Task 6: Verification

**Commands:**
- [ ] Run: `flutter pub get`
- [ ] Run: `flutter analyze`
- [ ] Run: `flutter test`

**Manual QA:**
- [ ] Signup/login redirects react immediately (no app restart)
- [ ] Create listing validation prevents invalid prices
- [ ] Product details: paystack payment success creates a paid order and marks listing sold
- [ ] Payment cancel keeps listing available again and order cancelled
