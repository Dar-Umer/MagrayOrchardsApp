class ProductVariant {
  final int id;
  final int productId;
  final String name;
  final String? sku;
  final double price;
  final double? comparePrice;
  final int stockQuantity;
  final String? image;
  final Map<String, dynamic>? attributes;

  ProductVariant({
    required this.id,
    required this.productId,
    required this.name,
    this.sku,
    required this.price,
    this.comparePrice,
    this.stockQuantity = 0,
    this.image,
    this.attributes,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      name: json['name'] ?? '',
      sku: json['sku'],
      price: double.tryParse(json['price'].toString()) ?? 0,
      comparePrice: json['compare_price'] != null
          ? double.tryParse(json['compare_price'].toString())
          : null,
      stockQuantity: json['stock_quantity'] ?? 0,
      image: json['image'],
      attributes: json['attributes'] is Map ? Map.from(json['attributes']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'name': name,
      'sku': sku,
      'price': price,
      'compare_price': comparePrice,
      'stock_quantity': stockQuantity,
      'image': image,
      'attributes': attributes,
    };
  }

  int get discountPercent {
    if (comparePrice == null || comparePrice! <= 0 || price <= 0) return 0;
    return ((comparePrice! - price) / comparePrice! * 100).round();
  }

  bool get inStock => stockQuantity > 0;
}
