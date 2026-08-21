import '../config/api_config.dart';

class PushNotification {
  final int id;
  final String title;
  final String body;
  final String type; // transactional | promotional
  final String? trigger;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  PushNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.trigger,
    this.data,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory PushNotification.fromJson(Map<String, dynamic> json) {
    return PushNotification(
      id: _toInt(json['id']),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      type: (json['type'] ?? 'transactional').toString(),
      trigger: json['trigger']?.toString(),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      isRead: (json['is_read'] ?? false) == true || (json['is_read'] ?? false) == 1,
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  /// Open target: deep-links a notification to a screen (e.g. an order).
  String? get targetScreen {
    final screen = data?['screen']?.toString();
    if (screen != null && screen.isNotEmpty) return screen;
    if (data?['order_id'] != null) return 'order';
    if (data?['booking_id'] != null) return 'booking';
    return null;
  }

  int? get targetId {
    final id = data?['order_id'] ?? data?['booking_id'] ?? data?['subscription_id'];
    return id is num ? id.toInt() : null;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

/// The [imageBaseUrl] helper is imported for consistency with other models;
/// notifications carry no image today but may in future campaigns.
String notificationImageUrl(String path) => '${ApiConfig.imageBaseUrl}$path';