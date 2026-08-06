class PlanProration {
  final double originalPrice;
  final double credit;
  final double finalPrice;
  final int remainingDays;
  final int totalDays;
  final String currentPlanName;

  PlanProration({
    required this.originalPrice,
    required this.credit,
    required this.finalPrice,
    required this.remainingDays,
    required this.totalDays,
    required this.currentPlanName,
  });

  factory PlanProration.fromJson(Map<String, dynamic> json) {
    return PlanProration(
      originalPrice: _toDouble(json['original_price']),
      credit: _toDouble(json['credit']),
      finalPrice: _toDouble(json['final_price']),
      remainingDays: json['remaining_days'] ?? 0,
      totalDays: json['total_days'] ?? 0,
      currentPlanName: json['current_plan_name'] ?? '',
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class SubscriptionPlan {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final int tier;
  final double price;
  final String billingPeriod;
  final bool isActive;
  final bool hasFreeDelivery;
  final bool hasFastSupport;
  final List<String>? features;
  final int sortOrder;
  final String subscriptionAction;
  final String? subscriptionReason;
  final PlanProration? proration;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.tier,
    required this.price,
    required this.billingPeriod,
    required this.isActive,
    required this.hasFreeDelivery,
    required this.hasFastSupport,
    this.features,
    this.sortOrder = 0,
    this.subscriptionAction = 'subscribe',
    this.subscriptionReason,
    this.proration,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      tier: json['tier'] ?? 1,
      price: _toDouble(json['price']),
      billingPeriod: json['billing_period'] ?? 'monthly',
      isActive: json['is_active'] ?? true,
      hasFreeDelivery: json['has_free_delivery'] ?? false,
      hasFastSupport: json['has_fast_support'] ?? false,
      features: json['features'] != null
          ? List<String>.from(json['features'])
          : null,
      sortOrder: json['sort_order'] ?? 0,
      subscriptionAction: json['subscription_action'] ?? 'subscribe',
      subscriptionReason: json['subscription_reason'],
      proration: json['proration'] != null
          ? PlanProration.fromJson(json['proration'])
          : null,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  bool get isCurrentPlan => subscriptionAction == 'current';
  bool get isUpgrade => subscriptionAction == 'upgrade';
  bool get isDowngradeBlocked => subscriptionAction == 'downgrade_blocked';
  bool get canSubscribeNow => subscriptionAction == 'subscribe' || subscriptionAction == 'upgrade';

  double get displayPrice {
    if (isUpgrade && proration != null) {
      return proration!.finalPrice;
    }
    return price;
  }

  String get billingPeriodLabel {
    switch (billingPeriod) {
      case 'monthly':
        return 'Per Month';
      case 'quarterly':
        return 'Per Quarter';
      case 'yearly':
        return 'Per Year';
      default:
        return '';
    }
  }
}
