class Category {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? image;
  final int productCount;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.image,
    this.productCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      image: json['image'],
      productCount: json['products_count'] ?? json['product_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'image': image,
      'product_count': productCount,
    };
  }
}
