import '../utils/formatters.dart';

class ServiceModel {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? shortDescription;
  final double basePrice;
  final String? priceUnit;
  final String? priceUnitLabel;
  final String? serviceType;
  final String? travelChargeType;
  final double? flatTravelCharge;
  final String? travelChargeTypeLabel;
  final int? minQuantity;
  final int? maxQuantity;
  final String? durationEstimate;
  final String? image;
  final String? categoryName;
  final bool isFeatured;
  final Map<String, dynamic>? travelInfo;

  ServiceModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.shortDescription,
    required this.basePrice,
    this.priceUnit,
    this.priceUnitLabel,
    this.serviceType,
    this.travelChargeType,
    this.flatTravelCharge,
    this.travelChargeTypeLabel,
    this.minQuantity,
    this.maxQuantity,
    this.durationEstimate,
    this.image,
    this.categoryName,
    this.isFeatured = false,
    this.travelInfo,
  });

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    String? categoryName;
    if (json['category'] is Map) {
      categoryName = json['category']['name'];
    } else {
      categoryName = json['category_name'];
    }

    Map<String, dynamic>? travelInfo;
    if (json['travel_info'] is Map) {
      travelInfo = Map<String, dynamic>.from(json['travel_info'] as Map);
    }

    final rawPriceUnit = json['price_unit']?.toString();
    final rawPriceUnitLabel =
        json['price_unit_label']?.toString() ?? rawPriceUnit;

    final rawTravelChargeType = json['travel_charge_type']?.toString() ??
        travelInfo?['type']?.toString() ??
        'per_km';
    final rawFlatTravelCharge = json['flat_travel_charge'] != null
        ? _toDouble(json['flat_travel_charge'])
        : (travelInfo?['flat_amount'] != null
            ? _toDouble(travelInfo!['flat_amount'])
            : null);
    final rawTravelChargeTypeLabel = json['travel_charge_type_label']?.toString() ??
        travelInfo?['type_label']?.toString();

    final rawMinQuantity = json['min_quantity'] is num
        ? (json['min_quantity'] as num).toInt()
        : (json['quantity_limits'] is Map && json['quantity_limits']['min'] is num
            ? (json['quantity_limits']['min'] as num).toInt()
            : (json['min_quantity'] != null ? int.tryParse(json['min_quantity'].toString()) : null));

    final rawMaxQuantity = json['max_quantity'] is num
        ? (json['max_quantity'] as num).toInt()
        : (json['quantity_limits'] is Map && json['quantity_limits']['max'] is num
            ? (json['quantity_limits']['max'] as num).toInt()
            : (json['max_quantity'] != null ? int.tryParse(json['max_quantity'].toString()) : null));

    return ServiceModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      shortDescription: json['short_description'],
      basePrice: _toDouble(json['base_price']),
      priceUnit: rawPriceUnit,
      priceUnitLabel: rawPriceUnitLabel,
      serviceType: json['service_type'],
      travelChargeType: rawTravelChargeType,
      flatTravelCharge: rawFlatTravelCharge,
      travelChargeTypeLabel: rawTravelChargeTypeLabel,
      minQuantity: rawMinQuantity,
      maxQuantity: rawMaxQuantity,
      durationEstimate: json['duration_estimate'],
      image: json['image'],
      categoryName: categoryName,
      isFeatured: json['is_featured'] ?? false,
      travelInfo: travelInfo,
    );
  }

  /// Minimum bookable quantity (defaults to 1 if not set).
  int get minQty => (minQuantity != null && minQuantity! > 0) ? minQuantity! : 1;

  /// Maximum bookable quantity (null if unlimited).
  int? get maxQty => maxQuantity;

  /// True if explicit quantity limits (min > 1 or max set) are defined.
  bool get hasLimit => (minQuantity != null && minQuantity! > 1) || maxQuantity != null;

  /// Clean display string for limits (e.g. "10 – 500 trees", "Min: 2 kanals", "Max: 40 kanals").
  String get limitsDisplay {
    if (minQuantity != null && minQuantity! > 1 && maxQuantity != null) {
      return '$minQty – $maxQty $quantityUnitNoun';
    } else if (minQuantity != null && minQuantity! > 1) {
      return 'Min: $minQty $quantityUnitNoun';
    } else if (maxQuantity != null) {
      return 'Max: $maxQty $quantityUnitNoun';
    }
    return '';
  }

  bool get isTravel => serviceType == 'physical';

  /// True if travel charges are zero (free/included).
  bool get isZeroTravel =>
      travelChargeType == 'zero' || (travelInfo?['is_zero'] == true);

  /// True if a fixed flat travel charge applies.
  bool get isFlatTravel =>
      travelChargeType == 'flat' || (travelInfo?['is_flat'] == true);

  /// True if distance-based per-km calculation applies.
  bool get isPerKmTravel =>
      !isZeroTravel && !isFlatTravel && isTravel;

  /// Human-friendly description of travel charging policy.
  String get travelChargeDescription {
    if (!isTravel) return 'Virtual Advisory (No field visit required)';
    if (isZeroTravel) return 'Free Doorstep Travel — Included in service fee';
    if (isFlatTravel) {
      final amt = flatTravelCharge ??
          (travelInfo?['flat_amount'] is num
              ? (travelInfo!['flat_amount'] as num).toDouble()
              : 100.0);
      return 'Flat Travel Charge: ${formatCurrency(amt)} (regardless of distance)';
    }
    return 'Travel charges apply based on distance from base location';
  }

  /// Human-readable label for the price unit (e.g. "Per Tree", "Per Kanal", "Per Visit").
  String get unitDisplay =>
      formatPriceUnit(priceUnitLabel ?? priceUnit);

  /// Suffix notation for pricing (e.g. "/ Tree", "/ Kanal", "/ Visit", "(Fixed)").
  String get unitSuffix =>
      formatPriceUnitSuffix(priceUnitLabel ?? priceUnit);

  /// Full formatted price string with currency and clean unit suffix (e.g. "Rs. 50 / Tree", "Rs. 150 / Kanal").
  String get formattedPrice {
    final suffix = unitSuffix;
    if (suffix.isEmpty) return formatCurrency(basePrice);
    return '${formatCurrency(basePrice)} $suffix'.trim();
  }

  /// True if charged per tree (e.g. pruning, training).
  bool get isPerTree {
    final u = (priceUnit ?? priceUnitLabel ?? '').toLowerCase();
    return u.contains('tree');
  }

  /// True if charged per kanal (Kashmiri land measurement: 1 acre = 8 kanals).
  bool get isPerKanal {
    final u = (priceUnit ?? priceUnitLabel ?? '').toLowerCase();
    return u.contains('kanal');
  }

  /// True if charged per acre.
  bool get isPerAcre {
    final u = (priceUnit ?? priceUnitLabel ?? '').toLowerCase();
    return u.contains('acre');
  }

  /// True if charged per unit/area (tree, kanal, acre).
  bool get isQuantityOrAreaBased => isPerTree || isPerKanal || isPerAcre;

  /// User-friendly label for the quantity input field.
  String get quantityFieldLabel {
    if (isPerTree) return 'Number of Trees';
    if (isPerKanal) return 'Orchard Size (in Kanals)';
    if (isPerAcre) return 'Orchard Size (in Acres)';
    return 'Quantity';
  }

  /// User-friendly hint text for the quantity input.
  String get quantityFieldHint {
    if (isPerTree) return 'e.g. 50 trees';
    if (isPerKanal) return 'e.g. 4 kanals (1 acre = 8 kanals)';
    if (isPerAcre) return 'e.g. 2 acres';
    return 'e.g. 1';
  }

  /// Short noun for the unit (e.g. "trees", "kanals", "acres", "visits").
  String get quantityUnitNoun {
    if (isPerTree) return 'trees';
    if (isPerKanal) return 'kanals';
    if (isPerAcre) return 'acres';
    return 'units';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'short_description': shortDescription,
      'base_price': basePrice,
      'price_unit': priceUnit,
      'price_unit_label': priceUnitLabel,
      'service_type': serviceType,
      'duration_estimate': durationEstimate,
      'image': image,
      'category_name': categoryName,
      'is_featured': isFeatured,
      'travel_info': travelInfo,
      'min_quantity': minQuantity,
      'max_quantity': maxQuantity,
    };
  }
}
