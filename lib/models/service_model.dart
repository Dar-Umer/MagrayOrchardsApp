class ServiceModel {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? shortDescription;
  final double basePrice;
  final String? priceUnit;
  final String? serviceType;
  final String? durationEstimate;
  final String? image;
  final String? categoryName;
  final bool isFeatured;
  final Map<String, dynamic>? travelInfo;

  ServiceModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.shortDescription,
    required this.basePrice,
    this.priceUnit,
    this.serviceType,
    this.durationEstimate,
    this.image,
    this.categoryName,
    this.isFeatured = false,
    this.travelInfo,
  });

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    String? categoryName;
    if (json['category'] is Map) {
      categoryName = json['category']['name'];
    } else {
      categoryName = json['category_name'];
    }

    Map<String, dynamic>? travelInfo;
    if (json['travel_info'] is Map) {
      travelInfo = Map<String, dynamic>.from(json['travel_info'] as Map);
    }

    return ServiceModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      shortDescription: json['short_description'],
      basePrice: _toDouble(json['base_price']),
      priceUnit: json['price_unit'],
      serviceType: json['service_type'],
      durationEstimate: json['duration_estimate'],
      image: json['image'],
      categoryName: categoryName,
      isFeatured: json['is_featured'] ?? false,
      travelInfo: travelInfo,
    );
  }

  bool get isTravel => serviceType == 'physical';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'short_description': shortDescription,
      'base_price': basePrice,
      'price_unit': priceUnit,
      'service_type': serviceType,
      'duration_estimate': durationEstimate,
      'image': image,
      'category_name': categoryName,
      'is_featured': isFeatured,
      'travel_info': travelInfo,
    };
  }
}
