# ATELIER Marketplace

ATELIER Marketplace is a Flutter + Supabase final-year project for a campus marketplace. Students can create accounts, post listings, discover products, save favorites, place basic orders, and track both purchases and sales.

## What the app currently supports

- Email sign up and sign in with Supabase Auth
- Automatic profile creation plus editable profile details
- Marketplace home feed with category browsing
- Product details, favorites, and report listing flow
- Create listing, edit listing, image upload, and mark sold/available
- Search with keyword, category, price filters, sorting, and recent searches
- Paystack sandbox checkout before order creation, plus purchase and sales history

## Stack

- Flutter
- Riverpod
- go_router
- Supabase Auth
- Supabase Postgres
- Supabase Storage

## Project structure

The codebase follows a feature-first layout.

```text
lib/
  app/
  core/
  features/
    auth/
    marketplace/
supabase/
  schema.sql
```

`marketplace_app_build_structure.md` contains the original phase plan and feature breakdown used to shape the project.

## Plan status

The original plan in `marketplace_app_build_structure.md` is not 100% complete yet.  
Core marketplace functionality and sandbox payment checkout are implemented, while admin/moderation tooling remains pending.

## Setup

1. Install Flutter and confirm `flutter doctor` is healthy.
2. Create a Supabase project.
3. Run the SQL in `supabase/schema.sql` inside the Supabase SQL editor.
4. Create any seed categories you want to demo.
5. Update the Supabase project URL and anon key in `lib/main.dart`.
6. Run `flutter pub get`.
7. Start the app with Paystack sandbox key:  
   `flutter run --dart-define=PAYSTACK_TEST_SECRET_KEY=sk_test_xxx`

## Demo routes

- `/splash`
- `/login`
- `/signup`
- `/home`
- `/search`
- `/product/:id`
- `/sell`
- `/favorites`
- `/profile`
- `/my-listings`
- `/orders`

## Notes

- The order flow now uses a Paystack sandbox checkout before creating the transaction record.
- Admin tooling is intentionally out of scope for this project version.
- The checked-in widget test is a lightweight login-screen smoke test. Full Flutter test execution on this machine still depends on the local Flutter SDK having the `flutter_tester` artifact installed.
