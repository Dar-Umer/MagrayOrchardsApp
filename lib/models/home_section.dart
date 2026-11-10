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
      enabled: json['enabled'] == null ? true : json['enabled'] == true || json['enabled'] == 1,
      title: json['title']?.toString(),
      source: json['source']?.toString(),
      layout: json['layout']?.toString(),
      rows: _toInt(json['rows']) ?? 1,
      limit: _toInt(json['limit']),
      categoryId: _toInt(json['category_id']),
      brandId: _toInt(json['brand_id']),
    );
  }

  static int? _toInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');

  bool get isCarousel => layout == 'carousel';
  bool get isGrid => layout == 'grid';
  int get rowCount => (rows ?? 1).clamp(1, 6);
  int get itemsPerRow =>
      (limit != null && limit! > 0) ? limit!.clamp(1, 50) : 10;
  int get fetchLimit => isGrid ? rowCount * 2 : rowCount * itemsPerRow;
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
