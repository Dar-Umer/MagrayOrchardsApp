class ServiceBookingModel {
  final int id;
  final int? serviceId;
  final String serviceName;
  final String? serviceSlug;
  final String? serviceImage;
  final DateTime bookingDate;
  final String timeSlot;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double distanceKm;
  final double travelCharge;
  final double baseCharge;
  final String? orchardDetails;
  final String? notes;
  final String status;
  final String paymentStatus;
  final double totalAmount;
  final DateTime? createdAt;

  ServiceBookingModel({
    required this.id,
    this.serviceId,
    required this.serviceName,
    this.serviceSlug,
    this.serviceImage,
    required this.bookingDate,
    required this.timeSlot,
    this.address,
    this.latitude,
    this.longitude,
    required this.distanceKm,
    required this.travelCharge,
    required this.baseCharge,
    this.orchardDetails,
    this.notes,
    required this.status,
    required this.paymentStatus,
    required this.totalAmount,
    this.createdAt,
  });

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static String _addressToString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) {
      return value.values
          .whereType<String>()
          .where((v) => v.trim().isNotEmpty)
          .join(', ');
    }
    return value.toString();
  }

  factory ServiceBookingModel.fromJson(Map<String, dynamic> json) {
    final service = json['service'] is Map
        ? Map<String, dynamic>.from(json['service'] as Map)
        : null;

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    return ServiceBookingModel(
      id: json['id'] ?? 0,
      serviceId: json['service_id'],
      serviceName: service?['name'] ?? json['service_name'] ?? 'Service',
      serviceSlug: service?['slug'] ?? json['service_slug'],
      serviceImage: service?['image'] ?? json['service_image'],
      bookingDate: parseDate(json['booking_date']) ?? DateTime.now(),
      timeSlot: json['time_slot'] ?? 'morning',
      address: _addressToString(json['address']),
      latitude: json['latitude'] != null ? _toDouble(json['latitude']) : null,
      longitude: json['longitude'] != null ? _toDouble(json['longitude']) : null,
      distanceKm: _toDouble(json['distance_km']),
      travelCharge: _toDouble(json['travel_charge']),
      baseCharge: _toDouble(json['base_charge']),
      orchardDetails: _addressToString(json['orchard_details']),
      notes: json['notes'],
      status: json['status'] ?? 'pending',
      paymentStatus: json['payment_status'] ?? 'unpaid',
      totalAmount: _toDouble(json['total_amount']),
      createdAt: parseDate(json['created_at']),
    );
  }

  bool get isPaid => paymentStatus == 'paid';
  bool get isCancelled => status == 'cancelled';
  bool get isTravel => (latitude != null && longitude != null) || travelCharge > 0;

  String get timeSlotLabel {
    switch (timeSlot) {
      case 'afternoon':
        return 'Afternoon (12 PM - 4 PM)';
      case 'evening':
        return 'Evening (4 PM - 7 PM)';
      default:
        return 'Morning (8 AM - 12 PM)';
    }
  }
}
