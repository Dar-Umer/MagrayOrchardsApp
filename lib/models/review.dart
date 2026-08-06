class Review {
  final int id;
  final int userId;
  final int productId;
  final int rating;
  final String? comment;
  final bool isApproved;
  final String? createdAt;
  final String? userName;

  Review({
    required this.id,
    required this.userId,
    required this.productId,
    required this.rating,
    this.comment,
    this.isApproved = false,
    this.createdAt,
    this.userName,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    String? name;
    if (json['user'] is Map) {
      name = json['user']['name'];
    }
    return Review(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      productId: json['product_id'] ?? 0,
      rating: json['rating'] ?? 0,
      comment: json['comment'],
      isApproved: json['is_approved'] ?? false,
      createdAt: json['created_at'],
      userName: name,
    );
  }
}
