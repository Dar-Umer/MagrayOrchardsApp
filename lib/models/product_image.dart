import '../config/api_config.dart';

class ProductImage {
  final int id;
  final int productId;
  final String imagePath;
  final int sortOrder;
  final bool isPrimary;

  ProductImage({
    required this.id,
    required this.productId,
    required this.imagePath,
    this.sortOrder = 0,
    this.isPrimary = false,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      imagePath: json['image_path'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
      isPrimary: json['is_primary'] == true || json['is_primary'] == 1,
    );
  }

  String get url => '${ApiConfig.imageBaseUrl}$imagePath';
}
