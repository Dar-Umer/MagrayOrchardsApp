import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magray_orchards/config/api_config.dart';
import 'package:magray_orchards/models/order.dart';
import 'package:magray_orchards/models/review.dart';
import 'package:magray_orchards/providers/cart_provider.dart';
import 'package:magray_orchards/services/shop_config.dart';
import 'package:magray_orchards/widgets/review_card.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ApiConfig.resolveImageUrl', () {
    test('resolves relative paths, leading slashes, and full URLs cleanly', () {
      expect(ApiConfig.resolveImageUrl(null), '');
      expect(ApiConfig.resolveImageUrl(''), '');

      final rel = ApiConfig.resolveImageUrl('products/apple.jpg');
      expect(rel, endsWith('/images/products/apple.jpg'));

      final full = ApiConfig.resolveImageUrl('https://cdn.example.com/img.png');
      expect(full, 'https://cdn.example.com/img.png');

      final storagePrefixed = ApiConfig.resolveImageUrl('storage/products/b.png');
      expect(storagePrefixed, '${ApiConfig.imageBaseUrl}products/b.png');
    });
  });

  group('Order.fromJson date parsing safety', () {
    test('handles invalid or empty date strings without throwing', () {
      final order = Order.fromJson({
        'id': 1,
        'order_number': 'MO-1001',
        'type': 'product',
        'status': 'pending',
        'subtotal': 100,
        'total_amount': 118,
        'created_at': 'not-a-date',
        'cancelled_at': '',
        'delivered_at': null,
      });

      expect(order.id, 1);
      expect(order.createdAt, isNull);
      expect(order.cancelledAt, isNull);
      expect(order.deliveredAt, isNull);
    });
  });

  group('ReviewCard defensive rendering', () {
    testWidgets('renders cleanly with empty userName and short createdAt',
        (tester) async {
      final review = Review(
        id: 1,
        userId: 1,
        productId: 2,
        rating: 5,
        comment: 'Great quality',
        userName: '',
        createdAt: '2026',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ReviewCard(review: review)),
        ),
      );

      expect(find.text('U'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
    });
  });

  group('CartProvider reset and paise rounding', () {
    test('reset clears in-memory items', () async {
      final cart = CartProvider();
      cart.reset();
      expect(cart.items, isEmpty);
      expect(cart.itemCount, 0);
    });

    test('paise conversion with round avoids floating-point truncation', () {
      const amount = 19.99;
      expect((amount * 100).round(), 1999);
    });
  });

  group('ShopConfig cache loading', () {
    test('loadFromCache hydrates config from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'cached_shop_config_v1': jsonEncode({
          'site_name': 'Orchard Cache Test',
          'tax_rate': 12,
          'gst_enabled': true,
          'mobile_app_maintenance_enabled': false,
        }),
      });

      final loaded = await ShopConfig.loadFromCache();
      expect(loaded, isTrue);
      expect(ShopConfig.siteName, 'Orchard Cache Test');
      expect(ShopConfig.taxRate, 12.0);
    });
  });
}
