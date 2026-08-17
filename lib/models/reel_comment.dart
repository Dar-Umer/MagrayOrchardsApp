class ReelComment {
  final int id;
  final String body;
  final int userId;
  final String userName;
  final String? createdAt;

  const ReelComment({
    required this.id,
    required this.body,
    required this.userId,
    required this.userName,
    this.createdAt,
  });

  factory ReelComment.fromJson(Map<String, dynamic> json) {
    String? name;
    if (json['user'] is Map) {
      name = json['user']['name']?.toString();
    }
    return ReelComment(
      id: json['id'] ?? 0,
      body: json['body'] ?? '',
      userId: json['user_id'] is num ? (json['user_id'] as num).toInt() : 0,
      userName: name ?? 'User',
      createdAt: json['created_at'],
    );
  }
}
