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
  final int quantity;
  final Product? product;

  const MarketplaceOrderItem({
    required this.id,
    required this.productId,
    required this.price,
    this.quantity = 1,
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
      quantity: json['quantity'] as int? ?? 1,
      product: product,
    );
  }

  double get lineTotal => price * quantity;
}

class MarketplaceOrder {
  final String id;
  final String buyerId;
  final String sellerId;
  final double totalAmount;
  final String status;
  final String? paymentProvider;
  final String? paymentReference;
  final String? paymentBatchId;
  final String? meetupLocation;
  final DateTime? paidAt;
  final DateTime? handedOverAt;
  final DateTime? completedAt;
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
    this.paymentProvider,
    this.paymentReference,
    this.paymentBatchId,
    this.meetupLocation,
    this.paidAt,
    this.handedOverAt,
    this.completedAt,
    this.createdAt,
    this.counterparty,
    this.item,
  });

  bool get isPending =>
      status == 'pending' ||
      status == 'pending_payment' ||
      status == 'pending_meetup';

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
      paymentProvider: json['payment_provider'] as String?,
      paymentReference: json['payment_reference'] as String?,
      paymentBatchId: json['payment_batch_id'] as String?,
      meetupLocation: json['meetup_location'] as String?,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      handedOverAt: json['handed_over_at'] != null
          ? DateTime.parse(json['handed_over_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      role: role,
      counterparty: counterparty,
      item: item,
    );
  }
}
