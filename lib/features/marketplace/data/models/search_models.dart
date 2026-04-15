enum ProductSortOption { newest, priceLowToHigh, priceHighToLow }

extension ProductSortOptionX on ProductSortOption {
  String get label {
    switch (this) {
      case ProductSortOption.newest:
        return 'Newest';
      case ProductSortOption.priceLowToHigh:
        return 'Price: Low to High';
      case ProductSortOption.priceHighToLow:
        return 'Price: High to Low';
    }
  }

  String get storageValue {
    switch (this) {
      case ProductSortOption.newest:
        return 'newest';
      case ProductSortOption.priceLowToHigh:
        return 'price_low_to_high';
      case ProductSortOption.priceHighToLow:
        return 'price_high_to_low';
    }
  }

  static ProductSortOption fromStorage(String value) {
    switch (value) {
      case 'price_low_to_high':
        return ProductSortOption.priceLowToHigh;
      case 'price_high_to_low':
        return ProductSortOption.priceHighToLow;
      case 'newest':
      default:
        return ProductSortOption.newest;
    }
  }
}

class ProductSearchFilters {
  static const Object _unset = Object();

  final String query;
  final int? categoryId;
  final double? minPrice;
  final double? maxPrice;
  final ProductSortOption sortOption;
  final bool availableOnly;

  const ProductSearchFilters({
    this.query = '',
    this.categoryId,
    this.minPrice,
    this.maxPrice,
    this.sortOption = ProductSortOption.newest,
    this.availableOnly = true,
  });

  bool get hasActiveFilters {
    return query.trim().isNotEmpty ||
        categoryId != null ||
        minPrice != null ||
        maxPrice != null ||
        sortOption != ProductSortOption.newest ||
        availableOnly != true;
  }

  ProductSearchFilters copyWith({
    Object? query = _unset,
    Object? categoryId = _unset,
    Object? minPrice = _unset,
    Object? maxPrice = _unset,
    ProductSortOption? sortOption,
    bool? availableOnly,
  }) {
    return ProductSearchFilters(
      query: query == _unset ? this.query : query as String,
      categoryId: categoryId == _unset ? this.categoryId : categoryId as int?,
      minPrice: minPrice == _unset ? this.minPrice : minPrice as double?,
      maxPrice: maxPrice == _unset ? this.maxPrice : maxPrice as double?,
      sortOption: sortOption ?? this.sortOption,
      availableOnly: availableOnly ?? this.availableOnly,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ProductSearchFilters &&
        other.query == query &&
        other.categoryId == categoryId &&
        other.minPrice == minPrice &&
        other.maxPrice == maxPrice &&
        other.sortOption == sortOption &&
        other.availableOnly == availableOnly;
  }

  @override
  int get hashCode => Object.hash(
    query,
    categoryId,
    minPrice,
    maxPrice,
    sortOption,
    availableOnly,
  );
}

class RecentSearch {
  final String id;
  final String query;
  final int? categoryId;
  final double? minPrice;
  final double? maxPrice;
  final ProductSortOption sortOption;
  final bool availableOnly;
  final DateTime? createdAt;

  const RecentSearch({
    required this.id,
    required this.query,
    this.categoryId,
    this.minPrice,
    this.maxPrice,
    required this.sortOption,
    required this.availableOnly,
    this.createdAt,
  });

  String get signature {
    return [
      query.trim().toLowerCase(),
      categoryId?.toString() ?? '',
      minPrice?.toString() ?? '',
      maxPrice?.toString() ?? '',
      sortOption.storageValue,
      availableOnly.toString(),
    ].join('|');
  }

  ProductSearchFilters toFilters() {
    return ProductSearchFilters(
      query: query,
      categoryId: categoryId,
      minPrice: minPrice,
      maxPrice: maxPrice,
      sortOption: sortOption,
      availableOnly: availableOnly,
    );
  }

  factory RecentSearch.fromJson(Map<String, dynamic> json) {
    return RecentSearch(
      id: json['id'] as String,
      query: (json['query'] as String?) ?? '',
      categoryId: json['category_id'] as int?,
      minPrice: (json['min_price'] as num?)?.toDouble(),
      maxPrice: (json['max_price'] as num?)?.toDouble(),
      sortOption: ProductSortOptionX.fromStorage(
        (json['sort_by'] as String?) ?? ProductSortOption.newest.storageValue,
      ),
      availableOnly: json['available_only'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}
