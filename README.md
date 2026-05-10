# ATELIER Marketplace

ATELIER Marketplace is a Flutter + Supabase campus marketplace. Students can create accounts, post listings, discover products, save favorites, place orders with Paystack, and track purchases and sales.

## Stack

- **Flutter** (Dart 3.11+)
- **Riverpod** for state management
- **go_router** for navigation
- **Supabase** (Auth, Postgres, Storage, Edge Functions)
- **Paystack** for payments

## How to Run

### 1. Prerequisites

- Flutter SDK installed (`flutter doctor` should be healthy)
- A [Supabase](https://supabase.com) project (free tier works)
- A [Paystack](https://paystack.com) test account (for payments)

### 2. Set up Supabase

Run migrations with dbmate:

```bash
export DATABASE_URL='postgresql://postgres.YOUR_PROJECT_REF:YOUR_DB_PASSWORD@aws-0-eu-west-1.pooler.supabase.com:6543/postgres?sslmode=require'
./dbmate-safe.sh up
```

- `db/migrations/` is the dbmate migration stream.
- `supabase/schema.sql` remains the idempotent install-from-scratch snapshot.
- Categories are auto-seeded (Electronics, Fashion, Books, etc.).

### 3. Deploy Edge Functions (for payments)

```bash
# Install the Supabase CLI if you haven't:
npm install -g supabase

# Link to your project:
supabase link --project-ref YOUR_PROJECT_REF

# Deploy the two payment functions:
supabase functions deploy paystack-initialize
supabase functions deploy paystack-verify

# Set the server-side Paystack secret:
supabase secrets set PAYSTACK_SECRET_KEY=sk_test_your_secret_key
```

### 4. Create your `.env` file

```bash
cp .env.example .env
```

Then edit `.env` with your actual values:

```env
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=eyJ...your-anon-key...
PAYSTACK_PUBLIC_KEY=pk_test_...your-paystack-public-key...
AUTH_REDIRECT_URL=http://localhost:3000/reset-password
```

You can find these in your Supabase dashboard under **Settings → API**.

### 5. Install dependencies

```bash
flutter pub get
```

### 6. Run the app

**Option A — Using `--dart-define-from-file` (recommended):**

```bash
flutter run --dart-define-from-file=.env
```

**Option B — Using individual `--dart-define` flags:**

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ... \
  --dart-define=PAYSTACK_PUBLIC_KEY=pk_test_...
```

**Option C — Run on a specific device:**

```bash
# List available devices:
flutter devices

# Run on a specific one:
flutter run -d chrome --dart-define-from-file=.env
flutter run -d macos --dart-define-from-file=.env
flutter run -d <device-id> --dart-define-from-file=.env
```

### 7. Build for release (optional)

```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols --dart-define-from-file=.env       # Android
flutter build ios --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=.env        # iOS
flutter build web --release --dart-define-from-file=.env        # Web
```

## App Routes

| Route | Screen |
|---|---|
| `/splash` | Animated splash (entry point) |
| `/login` | Sign in |
| `/signup` | Register |
| `/home` | Marketplace feed |
| `/search` | Search with filters |
| `/product/:id` | Product details |
| `/product/:id/edit` | Edit listing |
| `/sell` | Create listing |
| `/favorites` | Saved items |
| `/profile` | User profile |
| `/my-listings` | Seller's listings |
| `/orders` | Purchase & sales history |

## Project Structure

```text
lib/
  app/              # Theme, router, config, bootstrap
  core/             # Constants, errors, services, UI helpers
  features/
    auth/           # Login, signup, profile, auth providers
    marketplace/    # Home, products, orders, favorites, search
    search/         # Search feature barrel (re-exports from marketplace)
supabase/
  schema.sql        # Idempotent install-from-scratch database schema
db/
  migrations/       # dbmate migration stream
  functions/
    paystack-initialize/
    paystack-verify/
```

## Notes

- The schema is **fully idempotent** — `CREATE TABLE IF NOT EXISTS`, policies drop-then-create, functions use `CREATE OR REPLACE`. Safe to re-run.
- Orders use an atomic server-side function with `FOR UPDATE` row locking to prevent race conditions.
- Paystack checkout is server-initialized (Edge Function creates and verifies transactions).
- The app reserves listings during checkout and releases them if payment is cancelled.
- Admin tooling is intentionally out of scope for V1.
