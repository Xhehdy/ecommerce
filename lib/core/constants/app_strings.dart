/// User-facing strings used throughout the ATELIER marketplace.
///
/// Keeping these in one file makes future i18n trivial and keeps screens
/// free of long inline string literals.
class AppStrings {
  // ── Brand ────────────────────────────────────────────────
  static const String appName = 'ATELIER Marketplace';
  static const String brandMark = 'ATELIER.';
  static const String tagline = 'Campus marketplace';

  // ── Auth ─────────────────────────────────────────────────
  static const String signIn = 'Sign In';
  static const String signUp = 'Register';
  static const String signInSubtitle = 'Access your exclusive marketplace.';
  static const String signUpSubtitle = 'Create an account to join the marketplace.';
  static const String signInAction = 'SIGN IN';
  static const String signUpAction = 'CREATE ACCOUNT';
  static const String signOutAction = 'SIGN OUT';
  static const String noAccount = "Don't have an account? ";
  static const String hasAccount = 'Already have an account? ';

  // ── Splash ───────────────────────────────────────────────
  static const String splashSubtitle = 'Buy & sell on campus';

  // ── Profile ──────────────────────────────────────────────
  static const String profileTitle = 'Profile';
  static const String saveProfile = 'SAVE PROFILE';
  static const String profileBio = 'A complete profile makes your listings feel safer and more credible to buyers on campus.';
  static const String marketplaceIdentity = 'Marketplace Identity';
  static const String identityHint = 'Use your real details so buyers know who they are dealing with.';

  // ── Home ─────────────────────────────────────────────────
  static const String welcomeBack = 'Welcome back';
  static const String campusHero = 'Fresh campus finds, ready for quick meetups and safer student-to-student selling.';
  static const String browseByCategory = 'Browse by Category';
  static const String latestListings = 'Latest Listings';
  static const String searchPlaceholder = 'Search for phones, clothes, textbooks...';

  // ── Product ──────────────────────────────────────────────
  static const String details = 'Details';
  static const String description = 'Description';
  static const String noDescription = 'No description provided.';
  static const String available = 'Available';
  static const String sold = 'Sold';
  static const String reserved = 'RESERVED';
  static const String placeOrder = 'PLACE ORDER';
  static const String editListing = 'EDIT LISTING';
  static const String markSold = 'MARK AS SOLD';
  static const String markAvailable = 'MARK AVAILABLE';

  // ── Delete ───────────────────────────────────────────────
  static const String deleteListing = 'DELETE LISTING';
  static const String deleteConfirmTitle = 'Delete Listing';
  static const String deleteConfirmMessage = 'This listing and its images will be permanently removed. This action cannot be undone.';
  static const String deleteSuccess = 'Listing deleted.';

  // ── Listings ─────────────────────────────────────────────
  static const String myListings = 'My Listings';
  static const String createListing = 'Create Listing';
  static const String editListingTitle = 'Edit Listing';
  static const String submitListing = 'SUBMIT LISTING';
  static const String saveChanges = 'SAVE CHANGES';

  // ── Search ───────────────────────────────────────────────
  static const String search = 'Search';
  static const String searchProducts = 'Search products';
  static const String recentSearches = 'Recent Searches';
  static const String noRecentSearches = 'No recent searches yet';
  static const String noResults = 'No results matched your search.';

  // ── Favorites ────────────────────────────────────────────
  static const String saved = 'Saved';
  static const String noFavorites = 'You have not saved any products yet.';
  static const String browseListings = 'BROWSE LISTINGS';

  // ── Orders ───────────────────────────────────────────────
  static const String orders = 'Orders';
  static const String purchases = 'Purchases';
  static const String sales = 'Sales';
  static const String noPurchases = 'No purchases yet';
  static const String noSales = 'No sales yet';

  // ── Checkout ─────────────────────────────────────────────
  static const String checkoutTitle = 'Checkout';
  static const String checkoutMessage = 'You will be asked to complete payment with Paystack. If you cancel, the listing becomes available again.';
  static const String paymentSuccess = 'Payment successful. Order created.';
  static const String paymentCancelled = 'Payment cancelled.';

  // ── Report ───────────────────────────────────────────────
  static const String reportListing = 'Report Listing';
  static const String reportSubmitted = 'Listing report submitted.';

  // ── Conditions ───────────────────────────────────────────
  static const List<String> productConditions = [
    'New',
    'Like New',
    'Good',
    'Fair',
    'Poor',
  ];
}
