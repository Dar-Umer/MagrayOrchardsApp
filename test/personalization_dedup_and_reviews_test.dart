import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:magray_orchards/models/product.dart';
import 'package:magray_orchards/widgets/product_card.dart';
import 'package:magray_orchards/providers/auth_provider.dart';
import 'package:magray_orchards/providers/cart_provider.dart';

void main() {
  group('ProductCard Review Badge Tests', () {
    testWidgets('renders rating badge when product has ratings and reviews', (tester) async {
      final product = Product(
        id: 1,
        name: 'Apple Orchard Spray Machine',
        slug: 'apple-spray-machine',
        price: 15999.0,
        comparePrice: 18500.0,
        stockQuantity: 10,
        rating: 4.9,
        reviewsCount: 18,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 320,
                child: ProductCard(product: product),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Apple Orchard Spray Machine'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
      expect(find.text('(18)'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('omits rating badge when product has no reviews (rating == 0)', (tester) async {
      final product = Product(
        id: 2,
        name: 'Basic Pruning Shears',
        slug: 'basic-shears',
        price: 499.0,
        stockQuantity: 5,
        rating: 0.0,
        reviewsCount: 0,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 320,
                child: ProductCard(product: product),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Basic Pruning Shears'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });
  });

  group('Cross-Section Deduplication Logic Tests', () {
    test('Filter logic ensures no product repeats in subsequent sections', () {
      final displayedProductIds = <int>{};

      final offers = [
        Product(id: 1, name: 'Neem Oil', slug: 'neem-oil', price: 299, rating: 4.5),
        Product(id: 2, name: 'Urea Fertilizer', slug: 'urea', price: 450, rating: 4.0),
        Product(id: 3, name: 'Pruning Shears', slug: 'shears', price: 1299, rating: 4.8),
      ];

      final featured = [
        Product(id: 1, name: 'Neem Oil', slug: 'neem-oil', price: 299, rating: 4.5), // Duplicate
        Product(id: 4, name: 'Spray Machine', slug: 'spray', price: 15999, rating: 5.0),
        Product(id: 5, name: 'Knapsack Sprayer', slug: 'knapsack', price: 3499, rating: 4.2),
      ];

      final recommended = [
        Product(id: 3, name: 'Pruning Shears', slug: 'shears', price: 1299, rating: 4.8), // Duplicate
        Product(id: 4, name: 'Spray Machine', slug: 'spray', price: 15999, rating: 5.0), // Duplicate
        Product(id: 6, name: 'Drip Irrigation', slug: 'drip', price: 4999, rating: 4.6),
        Product(id: 7, name: 'Chaubattia Paste', slug: 'paste', price: 320, rating: 5.0),
      ];

      // Section 1: Offers
      final uniqueOffers = offers.where((p) => !displayedProductIds.contains(p.id)).toList();
      displayedProductIds.addAll(uniqueOffers.map((p) => p.id));
      expect(uniqueOffers.map((p) => p.id).toList(), [1, 2, 3]);

      // Section 2: Featured (Product 1 must be excluded!)
      final uniqueFeatured = featured.where((p) => !displayedProductIds.contains(p.id)).toList();
      displayedProductIds.addAll(uniqueFeatured.map((p) => p.id));
      expect(uniqueFeatured.map((p) => p.id).toList(), [4, 5]);
      expect(uniqueFeatured.any((p) => p.id == 1), false);

      // Section 3: Recommended (Products 3 and 4 must be excluded!)
      final uniqueRecommended = recommended.where((p) => !displayedProductIds.contains(p.id)).toList();
      displayedProductIds.addAll(uniqueRecommended.map((p) => p.id));
      expect(uniqueRecommended.map((p) => p.id).toList(), [6, 7]);
      expect(uniqueRecommended.any((p) => p.id == 3 || p.id == 4), false);

      // Verify total unique displayed products
      expect(displayedProductIds.length, 7);
    });

    test('High rating sorting prioritizes 5.0 and 4.8 stars first', () {
      final catalog = [
        Product(id: 1, name: 'Basic Hoe', slug: 'hoe', price: 200, rating: 0.0, reviewsCount: 0),
        Product(id: 2, name: 'Shears Pro', slug: 'shears', price: 1299, rating: 4.8, reviewsCount: 12),
        Product(id: 3, name: 'Tree Paste', slug: 'paste', price: 320, rating: 5.0, reviewsCount: 8),
        Product(id: 4, name: 'Urea', slug: 'urea', price: 450, rating: 4.0, reviewsCount: 2),
      ];

      catalog.sort((a, b) {
        final ratingComp = b.rating.compareTo(a.rating);
        if (ratingComp != 0) return ratingComp;
        return b.reviewsCount.compareTo(a.reviewsCount);
      });

      expect(catalog[0].id, 3); // 5.0 stars
      expect(catalog[1].id, 2); // 4.8 stars
      expect(catalog[2].id, 4); // 4.0 stars
      expect(catalog[3].id, 1); // 0.0 stars
    });
  });
}
