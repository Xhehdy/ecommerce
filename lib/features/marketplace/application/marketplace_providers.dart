import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/product_model.dart';
import '../data/models/category_model.dart';
import '../data/models/order_model.dart';
import '../data/models/search_models.dart';
import '../data/repositories/marketplace_repository.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return repo.fetchCategories();
});

final homeFeedProvider = FutureProvider<List<Product>>((ref) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return repo.fetchFeedProducts();
});

final myListingsProvider = FutureProvider<List<Product>>((ref) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return repo.fetchMyProducts();
});

final productDetailsProvider = FutureProvider.family<Product, String>((
  ref,
  id,
) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return repo.getProductDetails(id);
});

final favoriteProductIdsProvider = FutureProvider<Set<String>>((ref) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return repo.fetchFavoriteProductIds();
});

final favoriteProductsProvider = FutureProvider<List<Product>>((ref) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return repo.fetchFavoriteProducts();
});

final recentSearchesProvider = FutureProvider<List<RecentSearch>>((ref) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return repo.fetchRecentSearches();
});

final purchaseOrdersProvider = FutureProvider<List<MarketplaceOrder>>((ref) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return repo.fetchOrders(role: MarketplaceOrderRole.buyer);
});

final salesOrdersProvider = FutureProvider<List<MarketplaceOrder>>((ref) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return repo.fetchOrders(role: MarketplaceOrderRole.seller);
});

final searchResultsProvider =
    FutureProvider.family<List<Product>, ProductSearchFilters>((ref, filters) {
      final repo = ref.watch(marketplaceRepositoryProvider);
      return repo.searchProducts(filters);
    });
