import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepository(ref.watch(supabaseClientProvider));
});

class MarketplaceRepository {
  final SupabaseClient _supabase;

  MarketplaceRepository(this._supabase);

  Future<List<Category>> fetchCategories() async {
    final response = await _supabase.from('categories').select().order('name', ascending: true);
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

    final productResponse = await _supabase.from('products').insert({
      'seller_id': user.id,
      'category_id': categoryId,
      'title': title,
      'description': description,
      'price': price,
      'condition': condition,
      'status': 'available',
    }).select().single();

    final product = Product.fromJson(productResponse);

    if (images.isNotEmpty) {
      await _uploadProductImages(product.id, images);
    }

    return getProductDetails(product.id);
  }

  Future<void> _uploadProductImages(String productId, List<File> images) async {
    for (int i = 0; i < images.length; i++) {
      final file = images[i];
      final fileExt = file.path.split('.').last;
      // create safe unique name
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';
      final filePath = '$productId/$fileName';
      
      await _supabase.storage.from('product-images').upload(filePath, file);
      
      final imageUrl = _supabase.storage.from('product-images').getPublicUrl(filePath);
      
      await _supabase.from('product_images').insert({
        'product_id': productId,
        'image_url': imageUrl,
        'sort_order': i,
      });
    }
  }
}
