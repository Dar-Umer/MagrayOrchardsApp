import '../utils/formatters.dart';

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
  final Map<String, dynamic>? orchardDetailsMap;
  final int? quantity;
  final String? priceUnit;
  final String? notes;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final double totalAmount;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final int? assignedStaffId;
  final String? assignedStaffName;
  final String? assignedStaffPhone;
  final String? assignedStaffRole;
  final String? assignedStaffAvatar;
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
    this.orchardDetailsMap,
    this.quantity,
    this.priceUnit,
    this.notes,
    required this.status,
    required this.paymentStatus,
    this.paymentMethod = 'visit',
    required this.totalAmount,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.assignedStaffId,
    this.assignedStaffName,
    this.assignedStaffPhone,
    this.assignedStaffRole,
    this.assignedStaffAvatar,
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

  static String? _extractDetailsText(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    if (value is Map) {
      final desc = value['description']?.toString();
      if (desc != null && desc.trim().isNotEmpty) return desc.trim();
      final textParts = <String>[];
      if (value['quantity'] != null) {
        final q = value['quantity'];
        final u = formatPriceUnit(value['price_unit_label']?.toString() ?? value['price_unit']?.toString());
        textParts.add(u.isNotEmpty ? '$q $u' : '$q units');
      }
      if (textParts.isNotEmpty) return textParts.join(' • ');
    }
    return null;
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

    Map<String, dynamic>? rawDetailsMap;
    int? parsedQuantity;
    String? parsedPriceUnit;

    if (json['orchard_details'] is Map) {
      rawDetailsMap = Map<String, dynamic>.from(json['orchard_details'] as Map);
      final rawQ = rawDetailsMap['quantity'];
      if (rawQ is num) {
        parsedQuantity = rawQ.toInt();
      } else if (rawQ != null) {
        parsedQuantity = int.tryParse(rawQ.toString());
      }
      parsedPriceUnit = rawDetailsMap['price_unit_label']?.toString() ??
          rawDetailsMap['price_unit']?.toString();
    }

    if (parsedPriceUnit == null && service != null) {
      parsedPriceUnit = service['price_unit_label']?.toString() ??
          service['price_unit']?.toString();
    }

    final rawStaff = json['assigned_staff'] is Map
        ? Map<String, dynamic>.from(json['assigned_staff'] as Map)
        : (json['assignedStaff'] is Map
            ? Map<String, dynamic>.from(json['assignedStaff'] as Map)
            : null);

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
      orchardDetails: _extractDetailsText(json['orchard_details']),
      orchardDetailsMap: rawDetailsMap,
      quantity: parsedQuantity,
      priceUnit: parsedPriceUnit,
      notes: json['notes'],
      status: json['status'] ?? 'pending',
      paymentStatus: json['payment_status'] ?? 'unpaid',
      paymentMethod: json['payment_method']?.toString() ?? 'visit',
      totalAmount: _toDouble(json['total_amount']),
      razorpayOrderId: json['razorpay_order_id']?.toString(),
      razorpayPaymentId: json['razorpay_payment_id']?.toString(),
      assignedStaffId: json['assigned_staff_id'] ?? rawStaff?['id'],
      assignedStaffName: rawStaff?['name']?.toString(),
      assignedStaffPhone: rawStaff?['phone']?.toString(),
      assignedStaffRole: rawStaff?['role']?.toString(),
      assignedStaffAvatar: rawStaff?['avatar']?.toString(),
      createdAt: parseDate(json['created_at']),
    );
  }

  String get bookingNumber => '#BK-${id.toString().padLeft(4, '0')}';
  String get shortBookingNumber => '#$id';

  bool get isPaid => paymentStatus.toLowerCase() == 'paid';
  bool get isPayOnVisit => paymentMethod == 'visit' || paymentMethod == 'cod';
  bool get isPayOnline => paymentMethod == 'online' || paymentMethod == 'razorpay';
  String get paymentMethodLabel => isPayOnVisit ? 'Pay on Visit' : 'Online Payment';
  String get paymentMethodFullLabel =>
      isPayOnVisit ? 'Pay on Visit (Cash / UPI)' : 'Paid Online (Razorpay)';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isCancellable =>
      status.toLowerCase() == 'pending' &&
      (paymentStatus.toLowerCase() == 'unpaid' ||
          paymentStatus.toLowerCase() == 'pending');

  bool get hasAssignedStaff =>
      assignedStaffName != null && assignedStaffName!.trim().isNotEmpty;
  bool get hasAssignedStaffPhone =>
      assignedStaffPhone != null && assignedStaffPhone!.trim().isNotEmpty;

  bool get isTravel => (latitude != null && longitude != null) || travelCharge > 0;

  /// User-friendly scope display e.g. "50 Per Tree" or "4 Per Kanal".
  String? get formattedScope {
    if (quantity != null && quantity! > 0) {
      final unit = formatPriceUnit(priceUnit);
      if (unit.isNotEmpty) {
        return '$quantity $unit';
      }
      return '$quantity units';
    }
    return null;
  }

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
