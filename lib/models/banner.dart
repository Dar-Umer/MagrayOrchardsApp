class AppBanner {
  final int id;
  final String? title;
  final String? subtitle;
  final String? image;
  final String? linkType;
  final String? linkValue;
  final int sortOrder;

  AppBanner({
    required this.id,
    this.title,
    this.subtitle,
    this.image,
    this.linkType,
    this.linkValue,
    this.sortOrder = 0,
  });

  factory AppBanner.fromJson(Map<String, dynamic> json) {
    return AppBanner(
      id: json['id'] ?? 0,
      title: json['title'],
      subtitle: json['subtitle'],
      image: json['image'],
      linkType: json['link_type'],
      linkValue: json['link_value'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}
