import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/order_model.dart';
import '../models/search_models.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepository(ref.watch(supabaseClientProvider));
});

class MarketplaceRepository {
  final SupabaseClient _supabase;

  MarketplaceRepository(this._supabase);

  Future<List<Category>> fetchCategories() async {
    final response = await _supabase
        .from('categories')
        .select()
        .order('name', ascending: true);
    return response.map((json) => Category.fromJson(json)).toList();
  }

  Future<List<Product>> fetchFeedProducts() async {
    final response = await _supabase
        .from('products')
        .select('*, product_images(*)')
        .eq('status', 'available')
        .order('created_at', ascending: false);

    return response.map((json) => Product.fromJson(json)).toList();
  }

  Future<List<Product>> fetchMyProducts() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('User not authenticated');
    }

    final response = await _supabase
        .from('products')
        .select('*, product_images(*)')
        .eq('seller_id', user.id)
        .order('created_at', ascending: false);

    return response.map((json) => Product.fromJson(json)).toList();
  }

  Future<Product> getProductDetails(String productId) async {
    final response = await _supabase
        .from('products')
        .select('*, product_images(*)')
        .eq('id', productId)
        .single();
    return Product.fromJson(response);
  }

  Future<Product> createProduct({
    required String title,
    required double price,
    String? description,
    int? categoryId,
    String? condition,
    List<File> images = const [],
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final productResponse = await _supabase
        .from('products')
        .insert({
          'seller_id': user.id,
          'category_id': categoryId,
          'title': title,
          'description': description,
          'price': price,
          'condition': condition,
          'status': 'available',
        })
        .select()
        .single();

    final product = Product.fromJson(productResponse);

    if (images.isNotEmpty) {
      await _uploadProductImages(product.id, images);
    }

    return getProductDetails(product.id);
  }

  Future<Product> updateProduct({
    required String productId,
    required String title,
    required double price,
    String? description,
    int? categoryId,
    String? condition,
    List<File> images = const [],
  }) async {
    await _supabase
        .from('products')
        .update({
          'category_id': categoryId,
          'title': title,
          'description': description,
          'price': price,
          'condition': condition,
        })
        .eq('id', productId);

    if (images.isNotEmpty) {
      await _uploadProductImages(productId, images);
    }

    return getProductDetails(productId);
  }

  Future<void> updateProductStatus({
    required String productId,
    required String status,
  }) async {
    await _supabase
        .from('products')
        .update({'status': status})
        .eq('id', productId);
  }

  Future<void> deleteProduct(String productId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('User not authenticated');
    }

    // Remove images from Supabase Storage.
    try {
      final storageFiles = await _supabase.storage
          .from('product-images')
          .list(path: productId);
      if (storageFiles.isNotEmpty) {
        final paths = storageFiles
            .map((file) => '$productId/${file.name}')
            .toList(growable: false);
        await _supabase.storage.from('product-images').remove(paths);
      }
    } catch (_) {
      // Storage cleanup is best-effort; the DB row must still be removed.
    }

    // Cascade removes product_images via FK constraint.
    await _supabase.from('products').delete().eq('id', productId);
  }

  Future<String> createOrderForProduct(String productId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('User not authenticated');
    }

    final response = await _supabase.rpc(
      'create_marketplace_order_pending',
      params: {'target_product_id': productId},
    );

    if (response is! String || response.isEmpty) {
      throw StateError('Order creation did not return a valid order id.');
    }

    return response;
  }

  Future<void> markOrderPaid(String orderId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('User not authenticated');
    }

    await _supabase.rpc(
      'mark_marketplace_order_paid',
      params: {'target_order_id': orderId},
    );
  }

  Future<void> cancelOrder(String orderId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('User not authenticated');
    }

    await _supabase.rpc(
      'cancel_marketplace_order',
      params: {'target_order_id': orderId},
    );
  }

  Future<List<MarketplaceOrder>> fetchOrders({
    required MarketplaceOrderRole role,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('User not authenticated');
    }

    final orderRows = await _supabase
        .from('orders')
        .select()
        .eq(
          role == MarketplaceOrderRole.buyer ? 'buyer_id' : 'seller_id',
          user.id,
        )
        .order('created_at', ascending: false);

    if (orderRows.isEmpty) {
      return const <MarketplaceOrder>[];
    }

    final orderIds = orderRows
        .map((json) => json['id'] as String)
        .toList(growable: false);
    final counterpartyIds = orderRows
        .map(
          (json) => role == MarketplaceOrderRole.buyer
              ? json['seller_id'] as String
              : json['buyer_id'] as String,
        )
        .toSet()
        .toList(growable: false);

    final orderItemRows = await _supabase
        .from('order_items')
        .select()
        .inFilter('order_id', orderIds);

    final productIds = orderItemRows
        .map((json) => json['product_id'] as String)
        .toSet()
        .toList(growable: false);

    final productsResponse = productIds.isEmpty
        ? const []
        : await _supabase
              .from('products')
              .select('*, product_images(*)')
              .inFilter('id', productIds);

    final profileRows = counterpartyIds.isEmpty
        ? const []
        : await _supabase
              .from('profiles')
              .select('id, email, full_name')
              .inFilter('id', counterpartyIds);

    final productsById = {
      for (final json in productsResponse)
        (json['id'] as String): Product.fromJson(json),
    };
    final orderItemsByOrderId = <String, MarketplaceOrderItem>{};
    for (final itemJson in orderItemRows) {
      final productId = itemJson['product_id'] as String;
      orderItemsByOrderId[itemJson['order_id']
          as String] = MarketplaceOrderItem.fromJson(
        itemJson,
        product: productsById[productId],
      );
    }

    final counterpartiesById = {
      for (final json in profileRows)
        (json['id'] as String): OrderCounterparty.fromJson(json),
    };

    return orderRows
        .map((json) {
          final counterpartyId = role == MarketplaceOrderRole.buyer
              ? json['seller_id'] as String
              : json['buyer_id'] as String;

          return MarketplaceOrder.fromJson(
            json,
            role: role,
            counterparty: counterpartiesById[counterpartyId],
            item: orderItemsByOrderId[json['id'] as String],
          );
        })
        .toList(growable: false);
  }

  Future<List<Product>> searchProducts(ProductSearchFilters filters) async {
    var query = _supabase.from('products').select('*, product_images(*)');

    if (filters.availableOnly) {
      query = query.eq('status', 'available');
    }

    final normalizedQuery = _sanitizeSearchTerm(filters.query);
    if (normalizedQuery.isNotEmpty) {
      query = query.or(
        'title.ilike.%$normalizedQuery%,description.ilike.%$normalizedQuery%',
      );
    }

    if (filters.categoryId != null) {
      query = query.eq('category_id', filters.categoryId!);
    }

    if (filters.minPrice != null) {
      query = query.gte('price', filters.minPrice!);
    }

    if (filters.maxPrice != null) {
      query = query.lte('price', filters.maxPrice!);
    }

    final orderedQuery = switch (filters.sortOption) {
      ProductSortOption.newest => query.order('created_at', ascending: false),
      ProductSortOption.priceLowToHigh => query.order('price', ascending: true),
      ProductSortOption.priceHighToLow => query.order(
        'price',
        ascending: false,
      ),
    };

    final response = await orderedQuery;
    return response.map((json) => Product.fromJson(json)).toList();
  }

  Future<Set<String>> fetchFavoriteProductIds() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return <String>{};
    }

    final response = await _supabase
        .from('favorites')
        .select('product_id')
        .eq('user_id', user.id);

    return response.map((json) => json['product_id'] as String).toSet();
  }

  Future<List<Product>> fetchFavoriteProducts() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('User not authenticated');
    }

    final favoriteRows = await _supabase
        .from('favorites')
        .select('product_id, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    if (favoriteRows.isEmpty) {
      return const <Product>[];
    }

    final productIds = favoriteRows
        .map((json) => json['product_id'] as String)
        .toList();

    final productsResponse = await _supabase
        .from('products')
        .select('*, product_images(*)')
        .inFilter('id', productIds);

    final productsById = {
      for (final json in productsResponse)
        (json['id'] as String): Product.fromJson(json),
    };

    return productIds
        .map((productId) => productsById[productId])
        .whereType<Product>()
        .toList();
  }

  Future<void> toggleFavorite(String productId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('User not authenticated');
    }

    final existingFavorite = await _supabase
        .from('favorites')
        .select('product_id')
        .eq('user_id', user.id)
        .eq('product_id', productId)
        .maybeSingle();

    if (existingFavorite == null) {
      await _supabase.from('favorites').insert({
        'user_id': user.id,
        'product_id': productId,
      });
      return;
    }

    await _supabase
        .from('favorites')
        .delete()
        .eq('user_id', user.id)
        .eq('product_id', productId);
  }

  Future<void> reportProduct({
    required String productId,
    required String reason,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('User not authenticated');
    }

    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw ArgumentError('Reason is required.');
    }

    await _supabase.from('reports').insert({
      'reporter_id': user.id,
      'product_id': productId,
      'reason': normalizedReason,
    });
  }

  Future<List<RecentSearch>> fetchRecentSearches() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const <RecentSearch>[];
    }

    final response = await _supabase
        .from('recent_searches')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(10);

    final seenSignatures = <String>{};
    final results = <RecentSearch>[];

    for (final json in response) {
      final recentSearch = RecentSearch.fromJson(json);
      if (seenSignatures.add(recentSearch.signature)) {
        results.add(recentSearch);
      }
    }

    return results;
  }

  Future<void> saveRecentSearch(ProductSearchFilters filters) async {
    final user = _supabase.auth.currentUser;
    if (user == null || !filters.hasActiveFilters) {
      return;
    }

    await _supabase.from('recent_searches').insert({
      'user_id': user.id,
      'query': filters.query.trim(),
      'category_id': filters.categoryId,
      'min_price': filters.minPrice,
      'max_price': filters.maxPrice,
      'sort_by': filters.sortOption.storageValue,
      'available_only': filters.availableOnly,
    });
  }

  Future<void> clearRecentSearches() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return;
    }

    await _supabase
        .from('recent_searches')
        .delete()
        .eq('user_id', user.id);
  }

  Future<void> _uploadProductImages(String productId, List<File> images) async {
    for (int i = 0; i < images.length; i++) {
      final file = images[i];
      final fileExt = file.path.split('.').last;
      // create safe unique name
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';
      final filePath = '$productId/$fileName';

      await _supabase.storage.from('product-images').upload(filePath, file);

      final imageUrl = _supabase.storage
          .from('product-images')
          .getPublicUrl(filePath);

      await _supabase.from('product_images').insert({
        'product_id': productId,
        'image_url': imageUrl,
        'sort_order': i,
      });
    }
  }

  String _sanitizeSearchTerm(String rawQuery) {
    return rawQuery
        .trim()
        .replaceAll(',', ' ')
        .replaceAll('(', ' ')
        .replaceAll(')', ' ');
  }
}
