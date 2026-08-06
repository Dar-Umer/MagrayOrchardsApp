class Order {
  final int id;
  final String orderNumber;
  final String type;
  final String status;
  final double subtotal;
  final double discount;
  final double tax;
  final double shippingCharge;
  final double pincodeDeliveryCharge;
  final double totalAmount;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final Map<String, dynamic>? shippingAddress;
  final Map<String, dynamic>? billingAddress;
  final String? notes;
  final String? cancellationReason;
  final DateTime? cancelledAt;
  final List<OrderItem> items;
  final Map<String, dynamic>? shipment;
  final double? walletAmountUsed;
  final DateTime? createdAt;
  final DateTime? deliveredAt;

  Order({
    required this.id,
    required this.orderNumber,
    required this.type,
    required this.status,
    required this.subtotal,
    this.discount = 0,
    this.tax = 0,
    this.shippingCharge = 0,
    this.pincodeDeliveryCharge = 0,
    required this.totalAmount,
    this.paymentMethod,
    this.paymentStatus,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.shippingAddress,
    this.billingAddress,
    this.notes,
    this.cancellationReason,
    this.cancelledAt,
    this.shipment,
    this.items = const [],
    this.walletAmountUsed,
    this.createdAt,
    this.deliveredAt,
  });

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? '',
      subtotal: _toDouble(json['subtotal']),
      discount: _toDouble(json['discount']),
      tax: _toDouble(json['tax']),
      shippingCharge: _toDouble(json['shipping_charge']),
      pincodeDeliveryCharge: _toDouble(json['pincode_delivery_charge']),
      totalAmount: _toDouble(json['total_amount']),
      paymentMethod: json['payment_method'],
      paymentStatus: json['payment_status'],
      razorpayOrderId: json['razorpay_order_id'],
      razorpayPaymentId: json['razorpay_payment_id'],
      shippingAddress: json['shipping_address'] is Map
          ? Map<String, dynamic>.from(json['shipping_address'])
          : null,
      billingAddress: json['billing_address'] is Map
          ? Map<String, dynamic>.from(json['billing_address'])
          : null,
      notes: json['notes'],
      cancellationReason: json['cancellation_reason'],
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'])
          : null,
      shipment: json['shipment'] is Map
          ? Map<String, dynamic>.from(json['shipment'])
          : null,
      walletAmountUsed: _toDouble(json['wallet_amount_used']),
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromJson(item))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'])
          : null,
    );
  }
}

class OrderItem {
  final int id;
  final int? productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? image;

  OrderItem({
    required this.id,
    this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.image,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    String? imageUrl = json['image'];
    final product = json['product'];
    if (imageUrl == null && product is Map) {
      imageUrl = product['image'];
    }
    return OrderItem(
      id: json['id'] ?? 0,
      productId: json['product_id'],
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPrice: Order._toDouble(json['price']),
      totalPrice: Order._toDouble(json['total']),
      image: imageUrl,
    );
  }
}
