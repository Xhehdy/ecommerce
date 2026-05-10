# Short Project Journal

While building this marketplace app, I ran into a few problems that slowed me down and made me rethink some parts of the project.

At first, I thought the app would just be a simple place where students could post items and other students could view them. Later, I realized it needed more proper features like login, user profiles, favorites, search, orders, seller listings, and payment. Because of that, I had to adjust the structure of the app as I went on.

One of the hardest parts was setting up the database in Supabase. I had to create tables for users, products, categories, images, favorites, and orders. The relationships between them were a bit confusing at first, especially because one product belongs to a seller, can have images, can be saved by users, and can also be part of an order.

Authentication also gave me some issues. Sometimes after logging in, the app would not show the correct screen immediately, or the user profile would not load fast enough. I had to keep testing the login and signup flow until the app handled the user session properly.

I also had navigation problems when I started adding more screens. Some pages were not connected well at first, and some buttons led to routes that were missing or not finished. This made me go back and clean up the routing so the app would not break when moving from one page to another.

Another frustrating issue was when the app showed a blank screen during web testing. The code was building, but the app was not displaying properly in the browser. After checking the startup process, I found that some initialization code was not running in the right order, so I had to fix how the app starts.

The payment part was also challenging because I had to connect Paystack with Supabase functions. I had to think about what happens when payment is successful, failed, or cancelled. This part made me realize that payment features need to be handled carefully because they affect both the buyer and seller.

I also struggled a bit with keeping the UI consistent. Some screens worked, but they did not look complete at first. I had to spend time improving spacing, loading states, empty states, buttons, and error messages so the app would feel more like a real product.

Testing the full app flow helped me find many small mistakes. For example, I had to test signing up, logging in, viewing products, opening product details, saving favorites, creating listings, checking orders, and going through profile pages. Some issues only appeared when I tested the app like a real user.

During the final testing, I also found some more realistic issues. The Supabase database had been paused, so signup and database actions failed at first until it fully resumed. I also discovered that listings needed SKU and stock count because one seller might have more than one unit of the same item. That meant I had to update the database, the listing form, checkout quantity, and the order flow.

Another issue was that the project was supposed to use dbmate for database changes, not just manually running SQL in Supabase. I had to add a proper migration and apply it through dbmate. I also found some account-page problems, like Settings and Notifications not linking clearly to Orders and Saved items. The profile screen also still had fake rating/review data, so I replaced that with a saved-items count.

One tricky bug happened when creating a listing. The app showed an error message, but when I checked the database, the listing had actually been created. The problem was not the insert itself. It happened because the app tried to go back after creating the listing, but the page had been opened directly, so the navigation after saving did not behave properly. I fixed it by sending the user to the listings page after a new listing is created.

When I tested the buying flow properly, I also found a few more things. The first database check I wrote used the wrong column name, so I had to check the real schema and correct the query. I also noticed that some detail pages opened visually but the browser URL still stayed on the previous page, which is not good for refreshing or sharing links, so I cleaned up that navigation. Another small issue was that the profile page briefly showed a missing-profile message during account switching, even though the profile existed after refresh, so I added a safer refresh/sign-out state.

The full pay-on-meetup flow needed careful testing too. I created a listing with SKU and stock, saved it as another user, ordered two units, then tested the seller marking payment and handover, and the buyer confirming receipt. That helped me confirm the stock reduced properly and the order moved through the right statuses.

After checking the shopping flow again, I noticed the Saved page still felt more like a wishlist than a checkout page. A buyer could save items, but could not select only some of them, change quantities, or see a total before checking out. I changed it into a more cart-like page so saved items can be selected for checkout while the other saved items stay there for later.

I also compared the product detail page with common marketplace pages like Amazon and Jumia. Our page already had the title, price, images, stock, SKU, seller, and description, but the buy button was too far down the page. I moved the checkout information closer to the top so the buyer can quickly see stock, payment method, pickup, and the main buy action.

One more small but real issue was the Saved route. The app called the page "Saved," but opening `/saved` showed a page-not-found screen because the route was only `/favorites`. I added `/saved` too, so the URL matches what users see in the app.

Paystack also needed one more careful design step. At first, Paystack worked as a one-order payment because the order id was used as the payment reference. For multiple saved items, I added a payment batch idea instead. The buyer can select more than one saved item, the app adds the prices together, Paystack charges the total, and the database still creates separate orders underneath for each item/seller.

Applying that database change also had its own small issue. The project needed the real database URL inside the local `.env` file for dbmate. The direct Supabase database host did not work from my environment because it resolved to an IPv6 address with no route, so I switched the local connection string to the Supabase pooler host and then the migration applied successfully.

Later, while cleaning up checkout, I noticed the payment choices were appearing too early. The Saved page showed Paystack and Pay on meetup buttons directly, which made the flow feel rough. I changed it so the buyer first taps Checkout, then chooses the meetup location and payment method on the checkout screen. That also meant the database needed to store the meetup location on the order.

That checkout migration had another database connection issue. The Supabase pooler host was correct, but port 5432 timed out from my environment. Switching the local `.env` database URL to the pooler transaction port fixed it, and dbmate applied the meetup-location migration.

The mobile web check also revealed a UI problem that was easy to miss on desktop. The app was missing the viewport meta tag, so phone-width screenshots behaved like a cropped desktop page. I added the viewport tag and replaced the bottom navigation with a simpler four-column layout so Orders and Product details fit properly on a narrow screen.

When I tested Paystack properly, the hosted checkout page first blocked headless browser automation with a human verification page. I had to use a normal browser session for the payment page, then the test payment went through successfully. After verifying it, I marked the payment batch as paid and checked that both orders moved to awaiting handoff.

I also cleaned up the test data afterward. The app had temporary Codex users, listings, orders, favorites, and a payment batch from testing. I removed them so the live database would not be cluttered with fake demo records.

When checking the UI again, the product detail page had another issue. I added a sticky checkout bar, but on mobile it first took too much layout space and made the rest of the detail page look blank. I fixed the sizing and moved the title, price, stock, and status higher so the buyer sees the important information immediately.

The temporary UI screenshot setup also had a Supabase Auth issue. I first tried to create auth rows directly, but some auth columns are generated by Supabase and cannot be manually inserted. I changed the test setup to create temporary users through Supabase signup, then only used SQL for the marketplace test data.

There were also testing environment problems. Some Flutter commands needed extra permission because the SDK cache could not be updated in the normal sandbox. At one point the local web server was still running but returned an empty response, so it had to be restarted before browser testing could continue. These were not all product bugs, but they were still real challenges while trying to test the app properly.

Overall, the project taught me that building an app is not just about writing code. I had to plan the database, connect the backend, manage user sessions, handle errors, test different flows, and keep improving the interface until it felt usable.
