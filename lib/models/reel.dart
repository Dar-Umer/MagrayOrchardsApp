import 'product.dart';

class Reel {
  final int id;
  final String title;
  final String? description;
  final String videoType;
  final String? videoUrl;
  final String? thumbnail;
  final int? width;
  final int? height;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final Product? product;

  const Reel({
    required this.id,
    required this.title,
    this.description,
    required this.videoType,
    this.videoUrl,
    this.thumbnail,
    this.width,
    this.height,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.product,
  });

  bool get isYouTube => videoType == 'youtube';

  factory Reel.fromJson(Map<String, dynamic> json) {
    return Reel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      videoType: json['video_type'] ?? 'uploaded',
      videoUrl: json['video_url'],
      thumbnail: json['thumbnail'],
      width: json['width'] is num ? (json['width'] as num).toInt() : null,
      height: json['height'] is num ? (json['height'] as num).toInt() : null,
      likesCount: json['likes_count'] is num
          ? (json['likes_count'] as num).toInt()
          : 0,
      commentsCount: json['comments_count'] is num
          ? (json['comments_count'] as num).toInt()
          : 0,
      isLiked: json['is_liked'] ?? false,
      product: json['product'] is Map
          ? Product.fromJson(Map<String, dynamic>.from(json['product']))
          : null,
    );
  }

  Reel copyWith({
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
  }) {
    return Reel(
      id: id,
      title: title,
      description: description,
      videoType: videoType,
      videoUrl: videoUrl,
      thumbnail: thumbnail,
      width: width,
      height: height,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      product: product,
    );
  }
}
