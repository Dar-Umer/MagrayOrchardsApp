import '../utils/formatters.dart';

class PlantTypeModel {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;

  PlantTypeModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
  });

  factory PlantTypeModel.fromJson(Map<String, dynamic> json) {
    return PlantTypeModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      icon: json['icon']?.toString(),
    );
  }
}

class PlantAgeGroupModel {
  final int id;
  final String name;
  final String slug;
  final int? minAgeYears;
  final int? maxAgeYears;
  final String? description;

  PlantAgeGroupModel({
    required this.id,
    required this.name,
    required this.slug,
    this.minAgeYears,
    this.maxAgeYears,
    this.description,
  });

  factory PlantAgeGroupModel.fromJson(Map<String, dynamic> json) {
    return PlantAgeGroupModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      minAgeYears: json['min_age_years'] is int
          ? json['min_age_years']
          : int.tryParse(json['min_age_years']?.toString() ?? ''),
      maxAgeYears: json['max_age_years'] is int
          ? json['max_age_years']
          : int.tryParse(json['max_age_years']?.toString() ?? ''),
      description: json['description']?.toString(),
    );
  }
}

class ServiceTierRateModel {
  final int id;
  final int plantTypeId;
  final int plantAgeGroupId;
  final double pricePerUnit;
  final String? priceUnit;
  final String? plantTypeName;
  final String? plantAgeGroupName;

  ServiceTierRateModel({
    required this.id,
    required this.plantTypeId,
    required this.plantAgeGroupId,
    required this.pricePerUnit,
    this.priceUnit,
    this.plantTypeName,
    this.plantAgeGroupName,
  });

  factory ServiceTierRateModel.fromJson(Map<String, dynamic> json) {
    return ServiceTierRateModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      plantTypeId: json['plant_type_id'] is int
          ? json['plant_type_id']
          : int.tryParse(json['plant_type_id'].toString()) ?? 0,
      plantAgeGroupId: json['plant_age_group_id'] is int
          ? json['plant_age_group_id']
          : int.tryParse(json['plant_age_group_id'].toString()) ?? 0,
      pricePerUnit: (json['price_per_unit'] is num)
          ? (json['price_per_unit'] as num).toDouble()
          : (double.tryParse(json['price_per_unit']?.toString() ?? '') ?? 0.0),
      priceUnit: json['price_unit']?.toString(),
      plantTypeName: json['plant_type'] is Map ? json['plant_type']['name']?.toString() : null,
      plantAgeGroupName: json['plant_age_group'] is Map ? json['plant_age_group']['name']?.toString() : null,
    );
  }
}

class TreeInventoryItem {
  int? plantTypeId;
  String plantTypeName;
  int? plantAgeGroupId;
  String plantAgeGroupName;
  int quantity;
  double ratePerUnit;

  TreeInventoryItem({
    this.plantTypeId,
    required this.plantTypeName,
    this.plantAgeGroupId,
    required this.plantAgeGroupName,
    this.quantity = 10,
    this.ratePerUnit = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'plant_type_id': plantTypeId,
    'plant_age_group_id': plantAgeGroupId,
    'quantity': quantity,
  };
}

class SlotInfo {
  final String key;
  final String label;
  final int capacity;
  final int booked;
  final int available;
  final bool isOpen;

  SlotInfo({
    required this.key,
    required this.label,
    required this.capacity,
    required this.booked,
    required this.available,
    required this.isOpen,
  });

  factory SlotInfo.fromJson(String key, Map<String, dynamic> json) {
    return SlotInfo(
      key: key,
      label: json['label']?.toString() ?? key,
      capacity: (json['capacity'] is num) ? (json['capacity'] as num).toInt() : 0,
      booked: (json['booked'] is num) ? (json['booked'] as num).toInt() : 0,
      available: (json['available'] is num) ? (json['available'] as num).toInt() : 0,
      isOpen: json['is_open'] == true,
    );
  }
}

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
  final bool hasTierRates;
  final List<ServiceTierRateModel> tierRates;
  final List<PlantTypeModel> plantTypes;
  final List<PlantAgeGroupModel> plantAgeGroups;

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
    this.hasTierRates = false,
    this.tierRates = const [],
    this.plantTypes = const [],
    this.plantAgeGroups = const [],
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

    final rawTierRates = <ServiceTierRateModel>[];
    if (json['tier_rates'] is List) {
      for (final item in json['tier_rates']) {
        if (item is Map<String, dynamic>) {
          rawTierRates.add(ServiceTierRateModel.fromJson(item));
        } else if (item is Map) {
          rawTierRates.add(ServiceTierRateModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final rawPlantTypes = <PlantTypeModel>[];
    if (json['plant_types'] is List) {
      for (final item in json['plant_types']) {
        if (item is Map<String, dynamic>) {
          rawPlantTypes.add(PlantTypeModel.fromJson(item));
        } else if (item is Map) {
          rawPlantTypes.add(PlantTypeModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final rawPlantAgeGroups = <PlantAgeGroupModel>[];
    if (json['plant_age_groups'] is List) {
      for (final item in json['plant_age_groups']) {
        if (item is Map<String, dynamic>) {
          rawPlantAgeGroups.add(PlantAgeGroupModel.fromJson(item));
        } else if (item is Map) {
          rawPlantAgeGroups.add(PlantAgeGroupModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final hasTiers = json['has_tier_rates'] == true || rawTierRates.isNotEmpty;

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
      hasTierRates: hasTiers,
      tierRates: rawTierRates,
      plantTypes: rawPlantTypes,
      plantAgeGroups: rawPlantAgeGroups,
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

  bool get isPhysical => serviceType == 'physical';

  bool get isTravel => isPhysical && !isZeroTravel;

  /// True if travel charges are zero (free/promotional waiver).
  bool get isZeroTravel =>
      travelChargeType == 'zero' ||
      travelChargeType == 'free_promo' ||
      travelChargeType == 'free' ||
      (travelInfo?['is_zero'] == true);

  /// True if district-based travel calculation applies.
  bool get isDistrictTravel => isPhysical && !isZeroTravel;

  /// Legacy flat travel fallback (if any)
  bool get isFlatTravel =>
      travelChargeType == 'flat' || (travelInfo?['is_flat'] == true);

  /// True if distance-based per-km calculation applies.
  bool get isPerKmTravel =>
      isDistrictTravel && !isFlatTravel;

  /// Human-friendly description of travel charging policy.
  String get travelChargeDescription {
    if (!isPhysical) return 'Virtual Advisory (No field visit required)';
    if (isZeroTravel) return 'Free Doorstep Travel — Promotional waiver applied';
    return 'District-based travel rates configured per Service Zone';
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
    return u.contains('tree') || hasTierRates;
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
      'has_tier_rates': hasTierRates,
    };
  }
}
