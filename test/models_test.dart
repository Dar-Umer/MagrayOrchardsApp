import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magray_orchards/models/user.dart';
import 'package:magray_orchards/models/product.dart';
import 'package:magray_orchards/models/product_variant.dart';
import 'package:magray_orchards/models/home_section.dart';
import 'package:magray_orchards/models/banner.dart';
import 'package:magray_orchards/models/service_model.dart';
import 'package:magray_orchards/models/service_booking.dart';
import 'package:magray_orchards/utils/formatters.dart';
import 'package:magray_orchards/providers/cart_provider.dart';

void main() {
  group('User Model Tests', () {
    test('User.fromJson parses customer fields and default address correctly', () {
      final json = {
        'id': 42,
        'name': 'Bashir Ahmad',
        'email': 'bashir@example.com',
        'phone': '9906123456',
        'is_active': true,
        'is_pro_member': true,
        'has_free_delivery': true,
        'current_plan': 'Pro Plan',
        'default_address': {
          'pincode': '192124',
          'city': 'Srinagar',
          'state': 'Jammu and Kashmir',
        },
      };

      final user = User.fromJson(json);

      expect(user.id, 42);
      expect(user.name, 'Bashir Ahmad');
      expect(user.phone, '9906123456');
      expect(user.isProMember, true);
      expect(user.hasFreeDelivery, true);
      expect(user.defaultPincode, '192124');
      expect(user.defaultCity, 'Srinagar');
      expect(user.defaultState, 'Jammu and Kashmir');
    });

    test('User.toJson serializes core fields', () {
      final user = User(
        id: 10,
        name: 'Tariq',
        phone: '9876543210',
        isProMember: false,
      );

      final json = user.toJson();
      expect(json['id'], 10);
      expect(json['name'], 'Tariq');
      expect(json['phone'], '9876543210');
      expect(json['is_pro_member'], false);
    });
  });

  group('ProductVariant Model Tests', () {
    test('ProductVariant parses numeric and decimal strings into doubles', () {
      final json = {
        'id': 1,
        'product_id': 100,
        'name': '1 Liter Bottle',
        'sku': 'PEST-1L',
        'price': '850.50',
        'compare_price': '999.00',
        'stock_quantity': 25,
      };

      final variant = ProductVariant.fromJson(json);

      expect(variant.id, 1);
      expect(variant.productId, 100);
      expect(variant.name, '1 Liter Bottle');
      expect(variant.price, 850.50);
      expect(variant.comparePrice, 999.00);
      expect(variant.stockQuantity, 25);
    });
  });

  group('HomeSection Model Tests', () {
    test('HomeSection parses layout configuration', () {
      final json = {
        'type': 'products',
        'title': 'Featured Insecticides',
        'source': 'featured',
        'layout': 'carousel',
        'enabled': true,
        'rows': 1,
      };

      final section = HomeSection.fromJson(json);

      expect(section.type, 'products');
      expect(section.title, 'Featured Insecticides');
      expect(section.source, 'featured');
      expect(section.layout, 'carousel');
      expect(section.enabled, true);
      expect(section.itemsPerRow, 10);
      expect(section.fetchLimit, 10);
    });

    test('HomeSection respects limit, grid fetchLimit, and string IDs', () {
      final carousel = HomeSection.fromJson({
        'type': 'products',
        'source': 'category',
        'layout': 'carousel',
        'rows': '2',
        'limit': '8',
        'category_id': '4',
      });
      expect(carousel.rowCount, 2);
      expect(carousel.itemsPerRow, 8);
      expect(carousel.fetchLimit, 16);
      expect(carousel.categoryId, 4);

      final grid = HomeSection.fromJson({
        'type': 'products',
        'layout': 'grid',
        'rows': 3,
        'limit': 10,
      });
      expect(grid.fetchLimit, 6);
    });
  });

  group('AppBanner Model Tests', () {
    test('AppBanner parses backend link field cleanly', () {
      final banner = AppBanner.fromJson({
        'id': 4,
        'title': 'Monsoon Sale',
        'image': 'banners/monsoon-sale.jpg',
        'link': '/products?category=pesticides',
        'sort_order': 1,
      });

      expect(banner.id, 4);
      expect(banner.link, '/products?category=pesticides');
      expect(banner.sortOrder, 1);
    });
  });

  group('CartProvider Variant Tests', () {
    test('CartProvider separates variants and serializes variant_id in toOrderItems', () async {
      SharedPreferences.setMockInitialValues({});
      final cart = CartProvider();
      final product = Product(
        id: 7,
        name: 'Neem Oil',
        slug: 'neem-oil',
        price: 350,
        stockQuantity: 10,
      );
      final liter = ProductVariant(
        id: 21,
        productId: 7,
        name: '1 Liter',
        price: 680,
        stockQuantity: 5,
      );

      await cart.addItem(product, quantity: 1);
      await cart.addItem(product, quantity: 2, variant: liter);

      expect(cart.items.length, 2);
      expect(cart.total, 350 + (680 * 2));
      final orderItems = cart.toOrderItems();
      expect(orderItems[0].containsKey('variant_id'), false);
      expect(orderItems[1]['variant_id'], 21);
      expect(orderItems[1]['quantity'], 2);
    });
  });

  group('Service Price Unit & Pricing Tests', () {
    test('formatPriceUnit formats Kashmiri agricultural units correctly', () {
      expect(formatPriceUnit('per_tree'), 'Per Tree');
      expect(formatPriceUnit('per_kanal'), 'Per Kanal');
      expect(formatPriceUnit('per_acre'), 'Per Acre');
      expect(formatPriceUnit('per_visit'), 'Per Visit');
      expect(formatPriceUnit('fixed'), 'Fixed');
      expect(formatPriceUnit(''), '');
      expect(formatPriceUnit(null), '');
    });

    test('formatPriceUnitSuffix creates clean display suffixes', () {
      expect(formatPriceUnitSuffix('per_tree'), '/ Tree');
      expect(formatPriceUnitSuffix('per_kanal'), '/ Kanal');
      expect(formatPriceUnitSuffix('per_acre'), '/ Acre');
      expect(formatPriceUnitSuffix('per_visit'), '/ Visit');
      expect(formatPriceUnitSuffix('fixed'), '(Fixed)');
      expect(formatPriceUnitSuffix(null), '');
    });

    test('ServiceModel parses per_tree and per_kanal units and computes formattedPrice', () {
      final treeJson = {
        'id': 1,
        'name': 'High-Density Orchard Pruning',
        'slug': 'orchard-pruning',
        'base_price': '50.00',
        'price_unit': 'per_tree',
        'price_unit_label': 'Per Tree',
        'service_type': 'physical',
      };
      final treeService = ServiceModel.fromJson(treeJson);
      expect(treeService.isPerTree, true);
      expect(treeService.isPerKanal, false);
      expect(treeService.isQuantityOrAreaBased, true);
      expect(treeService.unitDisplay, 'Per Tree');
      expect(treeService.unitSuffix, '/ Tree');
      expect(treeService.formattedPrice, 'Rs. 50 / Tree');
      expect(treeService.quantityFieldLabel, 'Number of Trees');
      expect(treeService.quantityUnitNoun, 'trees');

      final kanalJson = {
        'id': 2,
        'name': 'Pesticide & Fungicide Spraying',
        'slug': 'pesticide-spraying',
        'base_price': 150,
        'price_unit': 'per_kanal',
        'price_unit_label': 'Per Kanal',
        'service_type': 'physical',
      };
      final kanalService = ServiceModel.fromJson(kanalJson);
      expect(kanalService.isPerTree, false);
      expect(kanalService.isPerKanal, true);
      expect(kanalService.isQuantityOrAreaBased, true);
      expect(kanalService.unitDisplay, 'Per Kanal');
      expect(kanalService.unitSuffix, '/ Kanal');
      expect(kanalService.formattedPrice, 'Rs. 150 / Kanal');
      expect(kanalService.quantityFieldLabel, 'Orchard Size (in Kanals)');
      expect(kanalService.quantityUnitNoun, 'kanals');
    });

    test('ServiceModel parses min_quantity and max_quantity and calculates limitsDisplay', () {
      final serviceWithLimits = ServiceModel.fromJson({
        'id': 3,
        'name': 'High-Density Orchard Pruning',
        'slug': 'orchard-pruning',
        'base_price': 50,
        'price_unit': 'per_tree',
        'price_unit_label': 'Per Tree',
        'min_quantity': 10,
        'max_quantity': 500,
      });
      expect(serviceWithLimits.minQuantity, 10);
      expect(serviceWithLimits.maxQuantity, 500);
      expect(serviceWithLimits.minQty, 10);
      expect(serviceWithLimits.maxQty, 500);
      expect(serviceWithLimits.hasLimit, true);
      expect(serviceWithLimits.limitsDisplay, '10 – 500 trees');

      final serviceWithAppendedLimits = ServiceModel.fromJson({
        'id': 4,
        'name': 'Orchard Visit & Consultation',
        'slug': 'orchard-visit',
        'base_price': 200,
        'price_unit': 'per_kanal',
        'price_unit_label': 'Per Kanal',
        'quantity_limits': {'min': 2, 'max': 40},
      });
      expect(serviceWithAppendedLimits.minQty, 2);
      expect(serviceWithAppendedLimits.maxQty, 40);
      expect(serviceWithAppendedLimits.hasLimit, true);
      expect(serviceWithAppendedLimits.limitsDisplay, '2 – 40 kanals');

      final unconstrainedService = ServiceModel.fromJson({
        'id': 5,
        'name': 'General Advice',
        'slug': 'general-advice',
        'base_price': 100,
        'price_unit': 'per_visit',
      });
      expect(unconstrainedService.minQty, 1);
      expect(unconstrainedService.maxQty, null);
      expect(unconstrainedService.hasLimit, false);
      expect(unconstrainedService.limitsDisplay, '');
    });

    test('ServiceBookingModel parses quantity and formattedScope from orchard_details', () {
      final bookingJson = {
        'id': 55,
        'service_name': 'High-Density Orchard Pruning',
        'booking_date': '2026-11-20',
        'time_slot': 'morning',
        'distance_km': 12.5,
        'travel_charge': '212.50',
        'base_charge': '2500.00',
        'total_amount': '2712.50',
        'status': 'confirmed',
        'payment_status': 'paid',
        'orchard_details': {
          'quantity': 50,
          'price_unit': 'per_tree',
          'price_unit_label': 'Per Tree',
          'description': 'Near apple orchard block B',
        },
      };

      final booking = ServiceBookingModel.fromJson(bookingJson);
      expect(booking.id, 55);
      expect(booking.quantity, 50);
      expect(booking.formattedScope, '50 Per Tree');
      expect(booking.baseCharge, 2500.00);
      expect(booking.travelCharge, 212.50);
      expect(booking.totalAmount, 2712.50);
      expect(booking.orchardDetails, 'Near apple orchard block B');
    });

    test('ServiceBookingModel parses payment_method and handles string decimals gracefully', () {
      final visitBookingJson = {
        'id': 70,
        'service_name': 'Orchard Pruning Service',
        'booking_date': '2026-11-25',
        'time_slot': 'morning',
        'distance_km': '0.00',
        'travel_charge': '0.00',
        'base_charge': '500.00',
        'total_amount': '500.00',
        'status': 'pending',
        'payment_status': 'unpaid',
        'payment_method': 'visit',
      };
      final visitBooking = ServiceBookingModel.fromJson(visitBookingJson);
      expect(visitBooking.isPayOnVisit, true);
      expect(visitBooking.isPayOnline, false);
      expect(visitBooking.paymentMethodLabel, 'Pay on Visit');
      expect(visitBooking.totalAmount, 500.00);

      final onlineBookingJson = {
        'id': 71,
        'service_name': 'Orchard Pruning Service',
        'booking_date': '2026-11-25',
        'time_slot': 'morning',
        'distance_km': 10,
        'travel_charge': 100,
        'base_charge': 500,
        'total_amount': 600,
        'status': 'confirmed',
        'payment_status': 'paid',
        'payment_method': 'online',
      };
      final onlineBooking = ServiceBookingModel.fromJson(onlineBookingJson);
      expect(onlineBooking.isPayOnVisit, false);
      expect(onlineBooking.isPayOnline, true);
      expect(onlineBooking.paymentMethodLabel, 'Online Payment');
      expect(onlineBooking.totalAmount, 600.00);
    });

    test('ServiceModel parses travel charge types: zero, flat, and per_km', () {
      final zeroJson = {
        'id': 10,
        'name': 'Pest Package',
        'base_price': 500,
        'service_type': 'physical',
        'travel_charge_type': 'zero',
      };
      final zeroService = ServiceModel.fromJson(zeroJson);
      expect(zeroService.isZeroTravel, true);
      expect(zeroService.isFlatTravel, false);
      expect(zeroService.isPerKmTravel, false);
      expect(zeroService.travelChargeDescription, contains('Free Doorstep Travel'));

      final flatJson = {
        'id': 11,
        'name': 'Spraying Service',
        'base_price': 150,
        'service_type': 'physical',
        'travel_charge_type': 'flat',
        'flat_travel_charge': 150.0,
      };
      final flatService = ServiceModel.fromJson(flatJson);
      expect(flatService.isZeroTravel, false);
      expect(flatService.isFlatTravel, true);
      expect(flatService.isPerKmTravel, false);
      expect(flatService.travelChargeDescription, contains('Flat Travel Charge: Rs. 150'));

      final perKmJson = {
        'id': 12,
        'name': 'Pruning Service',
        'base_price': 50,
        'service_type': 'physical',
        'travel_charge_type': 'per_km',
      };
      final perKmService = ServiceModel.fromJson(perKmJson);
      expect(perKmService.isZeroTravel, false);
      expect(perKmService.isFlatTravel, false);
      expect(perKmService.isPerKmTravel, true);
      expect(perKmService.travelChargeDescription, contains('Travel charges apply based on distance'));
    });
  });
}
