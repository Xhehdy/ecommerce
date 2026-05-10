# Project Testing Challenges

This note records the main errors and rough edges found while testing the
ATELIER Marketplace app end to end. It is written as a practical handover log:
what happened, why it mattered, what was fixed, and what still needs another
check.

## Supabase Was Paused During E2E Testing

During signup and order-flow testing, the Supabase project was paused. The app
could open locally, but auth and database-backed actions could not complete.
After the project was resumed, auth health became reachable again.

Impact:
- Signup/login could not be trusted until the backend was fully awake.
- Early failed requests looked like app bugs even though the backend was not
ready yet.

Resolution:
- Retried the flow after Supabase resumed.
- Signup eventually succeeded after the service finished coming back up.

Status:
- Resolved, but this is worth mentioning because paused backend services can
create misleading app errors during demos.

## Signup Initially Returned A Database Error

After Supabase came back online, the first signup attempt returned a database
error while finding/creating the user. A later retry succeeded.

Impact:
- New-account testing was blocked briefly.
- It showed that auth recovery after a paused database can be uneven for a few
minutes.

Resolution:
- Retried once the project was fully resumed.
- Later test accounts were created successfully.

Status:
- Resolved during testing.

## Create Listing UI Showed An Error After Creating The Listing

A seller filled the Create Listing form and submitted it, but the app displayed
a generic error message: "Something went wrong. Please try again." After the
dbmate migration, the same issue happened again during browser testing. A direct
database check showed the product row was actually created successfully.

Impact:
- The UI did not expose the real failure reason.
- The seller could think listing creation failed and submit the same item again.
- This could create duplicate listings or duplicate SKU errors later.

Cause:
- The app was opened directly on `/sell`.
- After successfully creating the listing, the screen called `context.pop()`.
- Because there was no previous page in the browser history stack, navigation
  failed after the database insert.
- A later retest showed another post-save issue: the row inserted successfully,
  but the UI still showed the generic error because success navigation/snackbar
  work happened inside the same `try` block as the database insert.

Resolution:
- Updated Create Listing success navigation to pop only when possible.
- If the screen was opened directly, it now routes to `/my-listings` instead.
- A later retest showed that `canPop()` could still be true while the browser
  effectively stayed on `/sell`, so new listings now always route to
  `/my-listings` after success.
- The success snackbar now appears before the route change, so a successful
  insert is not reported as a failed listing creation.

Status:
- Fixed in code and retested on a fresh no-cache web build. The final retest
  created `COD-CF-940006`, redirected to `/my-listings`, and did not show the
  false error toast.

## Missing SKU And Stock Count

The original product model treated each listing as one item. That meant a seller
could not list multiple units of the same product, and an order reserved or sold
the whole listing.

Impact:
- Sellers could not represent stock properly.
- Buyers had no quantity selector at checkout.
- Orders did not record quantity.

Resolution:
- Added `products.sku`.
- Added `products.stock_quantity`.
- Added `order_items.quantity`.
- Updated order RPCs so checkout decrements stock by the selected quantity.
- Product cards/details now show stock state.
- Checkout now includes quantity controls.

Status:
- Implemented locally and applied to the live database with dbmate.

## Database Migration Workflow Was Initially Wrong

The README originally described pasting `supabase/schema.sql` into the Supabase
SQL editor. The project actually uses dbmate for live schema changes.

Impact:
- The first live-database path was blocked by Supabase CLI auth.
- The migration needed to be represented as dbmate history, not just as an
  edited schema snapshot.

Resolution:
- Added `db/migrations/20260506100000_add_listing_inventory.sql`.
- Added `dbmate-safe.sh`.
- Updated README setup instructions to use dbmate.
- Applied the migration with dbmate to the live Supabase database.

Status:
- Resolved.

## DATABASE_URL Was Missing

The `.env` file only had Flutter-facing keys: Supabase URL, anon key, and
Paystack public key. dbmate needs a Postgres `DATABASE_URL`, which was not set
in `.env` or the shell.

Impact:
- `dbmate status` and `dbmate up` could not run at first.

Resolution:
- Added a `DATABASE_URL` placeholder to `.env.example`.
- Used the Supabase pooler URL with the database password supplied during
testing.

Status:
- Resolved for the current run. The real password should stay private and not
  be committed.

## Network Sandbox Blocked Database Checks

Some terminal checks failed with DNS or network permission errors, for example
when trying to reach the Supabase Postgres pooler from the sandbox.

Impact:
- Normal DB verification commands failed until they were rerun with the right
  permission level.

Resolution:
- Reran the dbmate migration and Postgres verification with elevated network
  access.
- Verified the live DB has:
  - `products.sku`
  - `products.stock_quantity`
  - `order_items.quantity`
  - quantity-aware order RPC signatures
  - dbmate migration version `20260506100000`

Status:
- Resolved.

## Local Static Server Became Stale

The local server on port `8765` was still listening, but the browser received an
empty response from it.

Impact:
- Browser verification could not load the rebuilt app even though the port was
  occupied.

Resolution:
- Stopped the stale Python server.
- Restarted `python3 -m http.server 8765 --bind 127.0.0.1` from `build/web`.
- The app loaded again in the in-app browser.

Status:
- Resolved.

## Flutter Tooling Needed Filesystem Permission

Some Flutter/Dart commands initially failed with an SDK cache permission error
while trying to update files under the local Flutter SDK.

Impact:
- Formatting, analyze, test, and build commands could not run in the default
  sandbox.

Resolution:
- Reran the commands with the needed permission.

Status:
- Resolved. Final checks passed:
  - `flutter analyze`
  - `flutter test`
  - `flutter build web --release --dart-define-from-file=.env`

## Account UI Tests Exposed Missing Shortcuts

The test suite initially failed because account-related pages did not expose the
expected real routes:

- Settings did not show `Orders`.
- Settings did not show `Saved items`.
- Notifications did not show `Open orders`.
- Notifications did not show `View saved items`.
- Profile still showed fake rating/review content instead of a saved count.

Impact:
- The account area was incomplete for buyers trying to return to orders or
  saved items.
- The profile included unrealistic placeholder trust data.

Resolution:
- Added Orders and Saved items shortcuts to Settings.
- Added quick links to Notifications.
- Replaced fake rating/review stats with a real saved-item count.

Status:
- Resolved. Tests now pass.

## Buyer/Seller State Could Bleed Across Accounts

During E2E testing, after switching from buyer to seller, the seller Orders page
briefly showed buyer purchase data until a hard reload.

Impact:
- This could confuse users who switch accounts during testing.
- It could show stale marketplace data from the previous session.

Resolution:
- Updated auth-sensitive marketplace providers to watch auth state.
- This forces orders, listings, favorites, recent searches, and order details to
  refresh when the signed-in user changes.

Status:
- Fixed in code and retested during the order lifecycle flow.

## Profile Could Briefly Show A Missing-Profile State

During buyer-to-seller switching, the buyer Profile page briefly showed
"No profile found for this account." A hard reload immediately showed the
correct profile, and the database confirmed the profile row existed.

Impact:
- The user could lose access to sign out if the profile fetch returned null.
- It made account switching feel broken even though the backend data was
present.

Resolution:
- Login now explicitly ensures the current user's profile exists before routing
  into the app.
- The missing-profile state now shows Refresh profile and Sign out actions
  instead of a dead-end message.

Status:
- Fixed in code and retested after rebuild. The buyer profile rendered normally
  without needing a hard refresh.

## Detail Screens Did Not Always Update The Browser URL

When opening product details from Saved items and order details from Orders, the
screen changed visually but the browser hash sometimes stayed on the parent
route, such as `/favorites` or `/orders`.

Impact:
- Refreshing or sharing the URL would not return to the detail screen the user
  was viewing.
- Browser E2E checks could not reliably assert the current detail route.

Resolution:
- Product-card and order-card taps now use concrete `go_router` route changes
  for detail screens.
- Product and order detail back buttons now have safe fallback routes.

Status:
- Fixed in code and retested after rebuild. Product cards now move the browser
  URL to `/product/:id`, and order cards now move it to `/orders/:id`.

## Verification Query Used The Wrong Column Name

During database verification, one SQL check assumed `order_items.unit_price`
existed. The actual schema uses `order_items.price`, so the query failed before
being corrected.

Impact:
- The first verification query failed even though the order itself was valid.
- It was a reminder to check the real schema before writing proof queries.

Resolution:
- Checked `information_schema.columns`.
- Re-ran the proof query using `order_items.price` and computed the line total
  as `price * quantity`.

Status:
- Resolved.

## Full Pay-On-Meetup Lifecycle Was Verified

The final E2E test created a new stock-tracked listing, saved it as a buyer,
ordered quantity `2`, and then completed the meetup lifecycle.

Verified flow:
- Seller created SKU `COD-CF-940006` with stock `3`.
- Buyer searched for the SKU and saved the listing.
- Buyer opened Saved items, entered checkout, cancelled once, reopened checkout,
  selected quantity `2`, and chose Pay on meetup.
- Seller confirmed meetup payment.
- Seller marked the item handed over.
- Buyer confirmed received.

Database proof:
- Product stock became `1`.
- Order quantity was `2`.
- Total was `3600`.
- Payment provider was `meetup`.
- Final status was `completed`.
- Paid, handed-over, and completed timestamps were all present.

Status:
- Verified end to end.

## Saved Route Did Not Match The Visible Page Name

During the saved-items UX pass, opening `#/saved` showed the app's Page not
found screen even though the navigation and screen title use the word "Saved."
The real route was only `#/favorites`.

Impact:
- Users could naturally type or share the page as `/saved` and hit an error.
- It made the product language and URL structure feel inconsistent.

Resolution:
- Added `/saved` as an alias route that renders the same Saved items screen as
  `/favorites`.
- Updated app shortcuts to use `/saved` so the visible language and browser URL
  line up.

Status:
- Fixed in code. Browser verification is pending until the web build can be
  regenerated.

## Saved Items Needed A Cart-Like Checkout Flow

The Saved page originally behaved like a static wishlist grid. Competitor
review against Amazon/Jumia patterns showed that saved/cart surfaces should let
buyers review item availability, choose what to checkout, adjust quantities,
and leave other items for later.

Impact:
- Buyers could save multiple items but could not choose a subset for checkout.
- Quantity and stock were only handled after opening each product.
- The page did not feel like a real shopping flow.

Resolution:
- Converted Saved items into selectable checkout cards.
- Added per-item stock, SKU, pickup, payment method, and quantity controls.
- Added a bottom checkout summary with selected count, total, Pay on meetup,
  and single-item Paystack handoff.

Status:
- Implemented in code. Flutter analyze/build/browser verification is blocked by
  the SDK cache permission issue noted below.

## Product Detail Purchase Action Was Too Far Down The Page

The product detail page had the expected title, images, price, stock, SKU,
seller information, and description, but the purchase action appeared after the
description and trust notes.

Impact:
- On mobile, buyers had to scroll before seeing how to buy.
- Compared with Amazon/Jumia-style product pages, the offer/checkout area was
  not prominent enough.

Resolution:
- Added a checkout offer card directly after the title/price/chips section.
- The card summarizes price, stock, payment methods, pickup, and the Buy action.
- Removed the duplicate buyer CTA from the bottom of the detail content.

Status:
- Implemented, rebuilt, and visually checked in the browser.

## Paystack Multi-Item Checkout Needed A Payment Batch

While adding saved-items checkout, the current Paystack flow was reviewed. The
existing implementation creates one pending order and uses that order id as the
Paystack reference.

Impact:
- A true multi-item Paystack checkout cannot safely be added by just looping
  over orders, because one Paystack transaction would need to settle multiple
  order records.
- Without a payment group/table, partial payment and verification states would
  be ambiguous.

Resolution:
- Added a `payment_batches` table through a dbmate migration.
- A Saved-items Paystack checkout now creates one payment batch and one pending
  order per selected item, then sends the combined total to Paystack.
- When Paystack verifies, the app marks the whole batch paid and moves every
  linked order to awaiting handoff.
- If payment is cancelled, the whole batch is cancelled and stock is released.

Status:
- Implemented in source and verified by Flutter analyze, tests, web build, and
  browser UI checks.
- Applied to the live database through dbmate after adding `DATABASE_URL` to the
  local gitignored `.env`.

## Flutter SDK Cache Permission Blocked Some Commands

During the saved-items/product-detail pass, `dart format` and `flutter analyze`
failed before touching project code because the Flutter tool tried to update:

`/Users/xhehdy/Dev/flutter/bin/cache/engine.stamp`

The sandbox returned `Operation not permitted`.

Impact:
- Flutter commands need elevated execution in this workspace.

Resolution:
- Ran `dart format`, `flutter analyze`, `flutter test`, and `flutter build web`
  with approved elevated execution.

Status:
- Resolved for this pass.

## dbmate Needed DATABASE_URL And The Pooler Host

The new payment-batch migration was ready, but the first `./dbmate-safe.sh up`
failed because neither the shell nor `.env` provided `DATABASE_URL`.

After adding the direct Supabase database URL, dbmate still failed because the
direct host resolved to IPv6 and the local environment had no route to that
address.

Impact:
- The rebuilt frontend could render the multi-item Paystack checkout, but the
  live database would reject the new RPC calls until the migration was applied.

Resolution:
- Added `DATABASE_URL` to the local gitignored `.env`.
- Switched the URL to the Supabase EU West pooler host so dbmate could connect
  over an IPv4-reachable path.
- Ran `./dbmate-safe.sh up` successfully.

Status:
- Resolved. The payment-batch migration applied successfully.
- A follow-up `dbmate status` check timed out on the pooler connection, but the
  migration apply command returned success.

## Supabase Pooler Port Timeout During Checkout UX Migration

While adding the cleaner checkout flow and storing meetup locations on orders,
the first `./dbmate-safe.sh up` attempt reached the Supabase pooler host but
timed out on port `5432`.

Impact:
- The Flutter UI changes were local, but the live database still needed the new
  `orders.meetup_location` column and updated checkout RPC signatures.
- Without applying the migration, choosing a meetup location in checkout would
  not persist to orders.

Resolution:
- Switched the local gitignored `.env` `DATABASE_URL` to the pooler transaction
  port `6543`.
- Updated `.env.example` and README setup instructions to use the same working
  pooler port.
- Re-ran `./dbmate-safe.sh up` successfully for
  `20260507110000_add_order_meetup_location.sql`.

Status:
- Resolved. The meetup-location migration applied through dbmate.

## Mobile Web Viewport Was Rendering Too Wide

During the mobile viewport check, headless Chrome screenshots first looked like
the Orders and Product detail pages were clipped on the right edge.

Impact:
- The page looked fine on desktop, but mobile web could render the app as a
  wider desktop canvas and crop the visible area.
- This made tabs, bottom navigation, and long detail-page rows look broken on
  phone-sized screens.

Resolution:
- Added the missing viewport meta tag to `web/index.html`.
- Replaced the Material `NavigationBar` with a fixed four-column bottom nav so
  each tab fits inside narrow widths.
- Rebuilt the web bundle and verified with Chrome DevTools mobile emulation at
  `390x844`.

Status:
- Resolved for the checked Orders and Product detail mobile views.

## Parallel Flutter Commands Can Trip The Startup Lock

While retesting, `flutter analyze` and `flutter build web` were accidentally
started at the same time. One command failed while trying to clean a generated
iOS ephemeral file and the other waited on Flutter's startup lock.

Impact:
- The failure looked like a filesystem/project issue, but it was caused by two
  Flutter tool processes running together.

Resolution:
- Let the build finish, then reran `flutter analyze` by itself.

Status:
- Resolved. Analyze passed after rerunning serially.

## Paystack Hosted Checkout Needed A Headed Browser

The Paystack multi-item checkout test could initialize a real test transaction,
but the hosted checkout page showed Cloudflare human verification in headless
Chrome.

Impact:
- A normal headless browser could not complete the Paystack hosted page.
- The app/database side was ready, but the payment-provider handoff needed a
  more realistic browser session to finish.

Resolution:
- Used Paystack test mode and a headed Chrome DevTools session.
- Completed the hosted checkout for a `NGN 7,500` batch payment.
- Verified Paystack returned `paid=true` / `rawStatus=success`.
- Marked the payment batch paid and confirmed both linked orders moved to
  `awaiting_handoff` with meetup location `Paystack QA desk`.

Status:
- Resolved for the Paystack test-mode handoff.

## Synthetic Test Data Needed Cleanup

The end-to-end tests created temporary Codex users, products, favorites, orders,
and one payment batch in the live Supabase project.

Impact:
- Leaving that data would make the app look less polished during demos and
  could confuse later order/listing checks.

Resolution:
- Deleted Codex synthetic orders, payment batch, favorites, listings, and auth
  users.
- Verified remaining Codex synthetic counts:
  - products: `0`
  - users: `0`
  - orders: `0`

Status:
- Resolved. Paystack's external test transaction remains in Paystack test
  history, but the marketplace database is cleaned up.

## Mobile Product Detail Checkout Bar Initially Hid The Page Body

During the UI/UX pass, the new sticky product checkout bar rendered, but the
product detail body looked almost blank in mobile screenshots.

Impact:
- The listing was technically loaded, but the buyer could not immediately see
  the product title, stock, and detail content clearly.
- This made the detail page feel unfinished even though the checkout action was
  present.

Resolution:
- Moved the title, price, and stock/status summary above the gallery.
- Fixed the sticky checkout bar sizing by constraining its bottom navigation
  height instead of letting it expand.
- Rebuilt the web bundle and verified the Product detail and Checkout sheet in
  a `390x844` Chrome mobile viewport.

Status:
- Resolved for the checked Product detail mobile view.

## Supabase Auth Generated Columns Affected Temporary QA Seeding

The temporary UI QA script first tried to hand-create auth rows for screenshots.
Supabase rejected manual values for generated auth columns.

Impact:
- The first seeded screenshot run failed before the app could be opened as an
  authenticated buyer.
- This was a QA setup issue, not a marketplace app runtime bug.

Resolution:
- Switched the QA setup to create temporary users through Supabase Auth signup.
- Used SQL only for marketplace seed data, then cleaned the temporary users,
  listings, favorites, and orders after screenshots.

Status:
- Resolved for this pass.

## Current Remaining Retests

The main inventory/order lifecycle is verified, and the saved/cart/product
detail improvements are now implemented. Remaining checks:

- None from this pass.
