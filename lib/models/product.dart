import 'product_image.dart';
import 'product_variant.dart';
import 'review.dart';

class Product {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? shortDescription;
  final double price;
  final double? comparePrice;
  final String? image;
  final int? categoryId;
  final String? categoryName;
  final bool isActive;
  final bool isFeatured;
  final int stockQuantity;
  final String? brand;
  final String? composition;
  final String? dosage;
  final String? classification;
  final String? recommendedCrops;
  final String? sku;
  final List<ProductImage> images;
  final List<ProductVariant> variants;
  final List<Review> reviews;

  Product({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.shortDescription,
    required this.price,
    this.comparePrice,
    this.image,
    this.categoryId,
    this.categoryName,
    this.isActive = true,
    this.isFeatured = false,
    this.stockQuantity = 0,
    this.brand,
    this.composition,
    this.dosage,
    this.classification,
    this.recommendedCrops,
    this.sku,
    this.images = const [],
    this.variants = const [],
    this.reviews = const [],
  });

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    String? categoryName;
    int? categoryId;

    if (json['category'] is Map) {
      categoryName = json['category']['name'];
      categoryId = json['category']['id'];
    } else {
      categoryName = json['category_name'];
      categoryId = json['category_id'];
    }

    String? imageUrl = json['image'];
    if (imageUrl == null && json['images'] is List && (json['images'] as List).isNotEmpty) {
      imageUrl = json['images'][0]['image_path'] ?? json['images'][0]['image'];
    }

    List<ProductImage> images = [];
    if (json['images'] is List) {
      images = (json['images'] as List)
          .map((e) => ProductImage.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<ProductVariant> variants = [];
    if (json['variants'] is List) {
      variants = (json['variants'] as List)
          .map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<Review> reviews = [];
    if (json['reviews'] is List) {
      reviews = (json['reviews'] as List)
          .map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      shortDescription: json['short_description'],
      price: _toDouble(json['price']),
      comparePrice: json['compare_price'] != null
          ? _toDouble(json['compare_price'])
          : null,
      image: imageUrl,
      categoryId: categoryId,
      categoryName: categoryName,
      isActive: json['is_active'] ?? true,
      isFeatured: json['is_featured'] ?? false,
      stockQuantity: json['stock_quantity'] ?? 0,
      brand: json['brand'],
      composition: json['composition'],
      dosage: json['dosage'],
      classification: json['classification'],
      recommendedCrops: json['recommended_crops'],
      sku: json['sku'],
      images: images,
      variants: variants,
      reviews: reviews,
    );
  }

  List<String> get allImageUrls {
    final urls = <String>[];
    if (image != null && image!.isNotEmpty) {
      urls.add(image!);
    }
    for (final img in images) {
      if (img.imagePath.isNotEmpty && !urls.contains(img.imagePath)) {
        urls.add(img.imagePath);
      }
    }
    return urls;
  }

  int get discountPercent {
    if (comparePrice == null || comparePrice! <= 0 || price <= 0) return 0;
    return ((comparePrice! - price) / comparePrice! * 100).round();
  }

  bool get inStock => stockQuantity > 0;
}
