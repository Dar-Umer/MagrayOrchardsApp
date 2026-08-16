class Brand {
  final int id;
  final String name;
  final String? slug;
  final String? description;
  final String? logo;
  final bool isActive;
  final int sortOrder;
  final int productsCount;

  const Brand({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.logo,
    this.isActive = true,
    this.sortOrder = 0,
    this.productsCount = 0,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'],
      description: json['description'],
      logo: json['logo'],
      isActive: json['is_active'] ?? true,
      sortOrder: json['sort_order'] ?? 0,
      productsCount: json['products_count'] ?? 0,
    );
  }
}
