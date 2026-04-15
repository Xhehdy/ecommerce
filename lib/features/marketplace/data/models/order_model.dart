import 'product_model.dart';

enum MarketplaceOrderRole { buyer, seller }

class OrderCounterparty {
  final String id;
  final String email;
  final String? fullName;

  const OrderCounterparty({
    required this.id,
    required this.email,
    this.fullName,
  });

  String get displayName {
    final trimmedName = fullName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      return trimmedName;
    }
    return email;
  }

  factory OrderCounterparty.fromJson(Map<String, dynamic> json) {
    return OrderCounterparty(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
    );
  }
}

class MarketplaceOrderItem {
  final String id;
  final String productId;
  final double price;
  final Product? product;

  const MarketplaceOrderItem({
    required this.id,
    required this.productId,
    required this.price,
    this.product,
  });

  factory MarketplaceOrderItem.fromJson(
    Map<String, dynamic> json, {
    Product? product,
  }) {
    return MarketplaceOrderItem(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      price: (json['price'] as num).toDouble(),
      product: product,
    );
  }
}

class MarketplaceOrder {
  final String id;
  final String buyerId;
  final String sellerId;
  final double totalAmount;
  final String status;
  final DateTime? createdAt;
  final MarketplaceOrderRole role;
  final OrderCounterparty? counterparty;
  final MarketplaceOrderItem? item;

  const MarketplaceOrder({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.totalAmount,
    required this.status,
    required this.role,
    this.createdAt,
    this.counterparty,
    this.item,
  });

  bool get isPending => status == 'pending';

  factory MarketplaceOrder.fromJson(
    Map<String, dynamic> json, {
    required MarketplaceOrderRole role,
    OrderCounterparty? counterparty,
    MarketplaceOrderItem? item,
  }) {
    return MarketplaceOrder(
      id: json['id'] as String,
      buyerId: json['buyer_id'] as String,
      sellerId: json['seller_id'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      role: role,
      counterparty: counterparty,
      item: item,
    );
  }
}
