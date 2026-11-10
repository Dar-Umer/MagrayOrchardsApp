import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magray_orchards/models/user.dart';
import 'package:magray_orchards/models/product.dart';
import 'package:magray_orchards/models/product_variant.dart';
import 'package:magray_orchards/models/home_section.dart';
import 'package:magray_orchards/models/banner.dart';
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
}
