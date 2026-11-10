class AppBanner {
  final int id;
  final String? title;
  final String? subtitle;
  final String? image;
  final String? link;
  final String? linkType;
  final String? linkValue;
  final int sortOrder;

  AppBanner({
    required this.id,
    this.title,
    this.subtitle,
    this.image,
    this.link,
    this.linkType,
    this.linkValue,
    this.sortOrder = 0,
  });

  factory AppBanner.fromJson(Map<String, dynamic> json) {
    return AppBanner(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      title: json['title']?.toString(),
      subtitle: json['subtitle']?.toString(),
      image: json['image']?.toString(),
      link: json['link']?.toString(),
      linkType: json['link_type']?.toString(),
      linkValue: json['link_value']?.toString(),
      sortOrder: json['sort_order'] is num ? (json['sort_order'] as num).toInt() : 0,
    );
  }
}
