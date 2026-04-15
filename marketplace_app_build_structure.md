# Marketplace App Build Structure

## Project Decision

- **Frontend:** Flutter
- **Backend:** Supabase
- **Database:** PostgreSQL
- **Auth:** Supabase Auth
- **Storage:** Supabase Storage
- **State Management:** Riverpod
- **Routing:** go_router

This setup is best for the project because the app needs strong marketplace search, relational data structure, and room to scale cleanly.

---

## Core Build Philosophy

Build the app in **layers** and by **feature**, not by random screens.

### App layers

- **Presentation** — screens, widgets, UI states
- **Application** — controllers, providers, use-cases
- **Domain** — models and business rules
- **Data** — Supabase queries, repositories, DTOs

This makes the codebase easier to maintain as features like search, orders, favorites, and admin tools grow.

---

## Recommended Flutter Structure

```text
lib/
  app/
    app.dart
    router.dart
    theme/
      colors.dart
      text_styles.dart
      theme.dart

  core/
    constants/
    errors/
    utils/
    services/
      supabase_service.dart

  features/
    auth/
      data/
      domain/
      application/
      presentation/

    marketplace/
      data/
      domain/
      application/
      presentation/

    search/
      data/
      domain/
      application/
      presentation/

    listings/
      data/
      domain/
      application/
      presentation/

    favorites/
      data/
      domain/
      application/
      presentation/

    orders/
      data/
      domain/
      application/
      presentation/

    profile/
      data/
      domain/
      application/
      presentation/

    admin/
      data/
      domain/
      application/
      presentation/
```

This feature-first structure is cleaner than putting the whole app into large global folders like `screens`, `widgets`, and `models`.

---

## Database Structure

Design the database before building the UI.

### Main tables

- `profiles`
- `categories`
- `products`
- `product_images`
- `favorites`
- `orders`
- `order_items`
- `reports`

### Suggested schema

#### profiles
- id
- full_name
- email
- matric_number
- faculty
- phone
- avatar_url
- created_at

#### categories
- id
- name
- slug

#### products
- id
- seller_id
- category_id
- title
- description
- price
- condition
- status
- location
- created_at

#### product_images
- id
- product_id
- image_url
- sort_order

#### favorites
- user_id
- product_id

#### orders
- id
- buyer_id
- seller_id
- total_amount
- status
- created_at

#### order_items
- id
- order_id
- product_id
- price

#### reports
- id
- reporter_id
- product_id
- reason
- status
- created_at

---

## Search as a Separate Feature

Because search is important, it should be built as its own feature, not buried inside the marketplace feed.

### Search should support

- keyword search
- category filtering
- minimum and maximum price
- newest items
- cheapest items
- available items only
- recent searches

---

## Main Screens

- Splash screen
- Login
- Sign up
- Home feed
- Search
- Product details
- Add product
- Edit product
- Favorites
- Orders
- My listings
- Profile
- Admin dashboard

---

## Route Structure

```text
/splash
/login
/signup
/home
/search
/product/:id
/sell
/favorites
/orders
/profile
/my-listings
```

Keep the route map simple and stable from the beginning.

---

## Shared UI Components

Create reusable UI components early:

- app button
- product card
- search bar
- empty state
- loading state
- error state
- price tag
- category chip

This helps the app stay visually consistent.

---

## Security and Permissions

Set these up early using Supabase Row Level Security.

### Rules to enforce

- users can edit only their own profile
- sellers can edit only their own products
- users can manage only their own favorites
- orders should only be visible to the buyer and seller involved
- reports should only be visible to authorized users or admins

---

## Development Phases

### Phase 1 — Foundation

- Flutter project setup
- theme setup
- routing setup
- Supabase connection
- auth flow
- profile creation

### Phase 2 — Core Marketplace

- home feed
- categories
- product details
- create listing
- edit listing
- mark as sold
- image upload

### Phase 3 — Search and Filters

- search screen
- search results
- filter bottom sheet
- sort options
- recent searches

### Phase 4 — Engagement

- favorites
- seller profile
- report listing
- my listings

### Phase 5 — Transaction Flow

- checkout structure
- order records
- purchase history
- sales history

### Phase 6 — Admin and Moderation

- flagged listings
- report review
- user restriction tools

---

## Weekly Build Plan

### Week 1
- project setup
- theme
- routing
- Supabase connection
- auth

### Week 2
- profile onboarding
- home feed
- categories

### Week 3
- add product
- image upload
- product details

### Week 4
- search
- filters
- sorting

### Week 5
- favorites
- my listings
- edit listing

### Week 6
- orders
- transaction records
- polish
- testing

---

## Final Feature List

### Must-have Features (V1)

1. Authentication
2. Profile setup
3. Home marketplace feed
4. Search
5. Filters
6. Recent searches
7. Product details
8. Create listing
9. Edit listing
10. Upload images
11. Mark item as sold
12. Favorites
13. My listings
14. Checkout flow
15. Payment integration
16. Basic order history
17. Report listing
18. Logout

### Payment Provider

- Use **Paystack** or **Flutterwave** for payment integration.
- Final provider can be chosen based on ease of integration, local reliability, and project preference.

### Should-have Features

- Seller profile
- Sales history
- Better empty states and onboarding polish
- Recent activity

### Could-have Features

- In-app chat
- Live notifications
- Seller ratings and reviews
- Admin dashboard
- Advanced analytics
- Recommended products

### Features deferred for later

- Full in-app chat
- Advanced moderation tools
- Recommendation engine
- Deep analytics

---

## Final Working Rule

Build **feature-first**, **database-first**, and **phase-by-phase**.

That will keep the project organized and prevent major rewrites later.

---

## Immediate Next Steps

- define final feature list
- draw database schema
- define route map
- create color and theme tokens
- set up Supabase project
- build auth and profile flow
- create the base folder structure

