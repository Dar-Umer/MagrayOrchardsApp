class PaidContent {
  final int id;
  final String title;
  final String slug;
  final String contentType;
  final String? customTypeLabel;
  final String? summary;
  final String body;
  final String? image;
  final int requiredPlanId;
  final bool isActive;
  final String? requiredPlanName;
  final int? requiredPlanTier;

  PaidContent({
    required this.id,
    required this.title,
    required this.slug,
    required this.contentType,
    this.customTypeLabel,
    this.summary,
    required this.body,
    this.image,
    required this.requiredPlanId,
    required this.isActive,
    this.requiredPlanName,
    this.requiredPlanTier,
  });

  factory PaidContent.fromJson(Map<String, dynamic> json) {
    final requiredPlan = json['required_plan'];
    return PaidContent(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      contentType: json['content_type'] ?? '',
      customTypeLabel: json['custom_type_label'],
      summary: json['summary'],
      body: json['body'] ?? '',
      image: json['image'],
      requiredPlanId: json['required_plan_id'] ?? 0,
      isActive: json['is_active'] ?? true,
      requiredPlanName: requiredPlan?['name'],
      requiredPlanTier: requiredPlan?['tier'],
    );
  }

  String get contentTypeLabel {
    if (contentType == 'custom' && customTypeLabel != null) {
      return customTypeLabel!;
    }
    switch (contentType) {
      case 'spray_schedule':
        return 'Spray Schedule';
      case 'nutrition':
        return 'Nutrition Management';
      case 'custom':
        return 'Custom';
      default:
        return contentType;
    }
  }
}
