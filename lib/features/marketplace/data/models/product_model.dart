class Product {
  final String id;
  final String sellerId;
  final int? categoryId;
  final String title;
  final String? description;
  final double price;
  final String? condition;
  final String status;
  final String? location;
  final DateTime? createdAt;
  final List<ProductImage> images;

  Product({
    required this.id,
    required this.sellerId,
    this.categoryId,
    required this.title,
    this.description,
    required this.price,
    this.condition,
    required this.status,
    this.location,
    this.createdAt,
    this.images = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    var imagesList = <ProductImage>[];
    if (json['product_images'] != null) {
      if (json['product_images'] is List) {
        imagesList = (json['product_images'] as List)
            .map((e) => ProductImage.fromJson(e))
            .toList();
      }
    }

    return Product(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String,
      categoryId: json['category_id'] as int?,
      title: json['title'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      condition: json['condition'] as String?,
      status: json['status'] ?? 'available',
      location: json['location'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      images: imagesList..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    );
  }
}

class ProductImage {
  final String id;
  final String productId;
  final String imageUrl;
  final int sortOrder;

  ProductImage({
    required this.id,
    required this.productId,
    required this.imageUrl,
    this.sortOrder = 0,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      imageUrl: json['image_url'] as String,
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}
