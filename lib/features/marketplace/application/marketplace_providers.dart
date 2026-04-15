import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/marketplace_repository.dart';
import '../data/models/product_model.dart';
import '../data/models/category_model.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return repo.fetchCategories();
});

final homeFeedProvider = FutureProvider<List<Product>>((ref) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return repo.fetchFeedProducts();
});
