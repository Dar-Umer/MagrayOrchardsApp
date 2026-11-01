import 'package:flutter_test/flutter_test.dart';
import 'package:magray_orchards/models/user.dart';
import 'package:magray_orchards/models/product_variant.dart';
import 'package:magray_orchards/models/home_section.dart';

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
    });
  });
}
