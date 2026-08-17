/// A single configurable section of the mobile app home page.
///
/// Mirrors the section objects saved by the admin panel in `shop.home_layout`.
class HomeSection {
  final String type;
  final bool enabled;
  final String? title;
  final String? source;
  final String? layout;
  final int? rows;
  final int? limit;
  final int? categoryId;
  final int? brandId;

  const HomeSection({
    required this.type,
    this.enabled = true,
    this.title,
    this.source,
    this.layout,
    this.rows = 1,
    this.limit,
    this.categoryId,
    this.brandId,
  });

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    return HomeSection(
      type: json['type']?.toString() ?? '',
      enabled: json['enabled'] ?? true,
      title: json['title']?.toString(),
      source: json['source']?.toString(),
      layout: json['layout']?.toString(),
      rows: json['rows'] is num ? (json['rows'] as num).toInt() : 1,
      limit: json['limit'] is num ? (json['limit'] as num).toInt() : null,
      categoryId:
          json['category_id'] is num ? (json['category_id'] as num).toInt() : null,
      brandId: json['brand_id'] is num ? (json['brand_id'] as num).toInt() : null,
    );
  }

  bool get isCarousel => layout == 'carousel';
  bool get isGrid => layout == 'grid';
  int get rowCount => (rows ?? 1).clamp(1, 6);
}

/// Ordered collection of home sections parsed from `shop.home_layout`.
class HomeLayout {
  final List<HomeSection> sections;

  const HomeLayout({this.sections = const []});

  factory HomeLayout.fromJson(dynamic json) {
    if (json is! List) return const HomeLayout();
    return HomeLayout(
      sections: json
          .whereType<Map>()
          .map((e) => HomeSection.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
