class User {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? phoneVerifiedAt;
  final String? role;
  final String? avatar;
  final bool isActive;
  final bool isProMember;
  final String? currentPlan;
  final bool hasFreeDelivery;
  final bool hasFastSupport;
  final String? subscriptionExpires;

  User({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.phoneVerifiedAt,
    this.role,
    this.avatar,
    this.isActive = true,
    this.isProMember = false,
    this.currentPlan,
    this.hasFreeDelivery = false,
    this.hasFastSupport = false,
    this.subscriptionExpires,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'],
      phone: json['phone'],
      phoneVerifiedAt: json['phone_verified_at'],
      role: json['role'],
      avatar: json['avatar'],
      isActive: json['is_active'] ?? true,
      isProMember: json['is_pro_member'] ?? false,
      currentPlan: json['current_plan'],
      hasFreeDelivery: json['has_free_delivery'] ?? false,
      hasFastSupport: json['has_fast_support'] ?? false,
      subscriptionExpires: json['subscription_expires'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'phone_verified_at': phoneVerifiedAt,
      'role': role,
      'avatar': avatar,
      'is_active': isActive,
      'is_pro_member': isProMember,
      'current_plan': currentPlan,
      'has_free_delivery': hasFreeDelivery,
      'has_fast_support': hasFastSupport,
      'subscription_expires': subscriptionExpires,
    };
  }

  String get displayName => name.isNotEmpty ? name : (phone ?? 'User');

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'U';
  }
}
