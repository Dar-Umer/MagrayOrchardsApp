import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magray_orchards/models/product.dart';
import 'package:magray_orchards/providers/auth_provider.dart';
import 'package:magray_orchards/providers/cart_provider.dart';
import 'package:magray_orchards/providers/product_provider.dart';
import 'package:magray_orchards/providers/personalization_provider.dart';
import 'package:magray_orchards/providers/notification_provider.dart';
import 'package:magray_orchards/providers/wishlist_provider.dart';
import 'package:magray_orchards/providers/theme_provider.dart';
import 'package:magray_orchards/providers/address_provider.dart';
import 'package:magray_orchards/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProductProvider Infinite Scroll State Tests', () {
    test('initial infinite scroll state is uninitialized with hasMore true and page 0', () {
      final provider = ProductProvider();
      expect(provider.infiniteProducts, isEmpty);
      expect(provider.infiniteLoading, false);
      expect(provider.infiniteHasMore, true);
      expect(provider.infiniteInitialized, false);
    });

    test('resetInfiniteProducts resets all infinite scroll state and notifies listeners', () {
      final provider = ProductProvider();
      provider.setInfiniteForTesting(
        products: [
          Product(id: 1, name: 'P1', slug: 'p1', price: 100, stockQuantity: 5),
        ],
        loading: false,
        hasMore: false,
        initialized: true,
      );

      expect(provider.infiniteProducts.length, 1);
      expect(provider.infiniteInitialized, true);

      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.resetInfiniteProducts();

      expect(notified, true);
      expect(provider.infiniteProducts, isEmpty);
      expect(provider.infiniteLoading, false);
      expect(provider.infiniteHasMore, true);
      expect(provider.infiniteInitialized, false);
    });
  });

  group('HomeScreen Infinite Scroll Widget Tests', () {
    Product makeProduct(int id, String name, double rating, int reviewsCount) {
      return Product(
        id: id,
        name: name,
        slug: 'product-$id',
        price: 999.0,
        stockQuantity: 10,
        rating: rating,
        reviewsCount: reviewsCount,
        isActive: true,
      );
    }

    Widget createTestApp(ProductProvider productProvider) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
          ChangeNotifierProvider<ProductProvider>.value(value: productProvider),
          ChangeNotifierProvider<PersonalizationProvider>(create: (_) => PersonalizationProvider()),
          ChangeNotifierProvider<NotificationProvider>(create: (_) => NotificationProvider()),
          ChangeNotifierProvider<WishlistProvider>(create: (_) => WishlistProvider()),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<AddressProvider>(create: (_) => AddressProvider()),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      );
    }

    testWidgets('renders infinite scroll sentinel button before user scrolls to bottom', (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final productProvider = ProductProvider();

      await tester.pumpWidget(createTestApp(productProvider));
      await tester.pump();

      final sentinelFinder = find.byKey(const Key('infinite_scroll_sentinel_btn'));
      expect(sentinelFinder, findsOneWidget);
      expect(find.text('Scroll to load more products'), findsOneWidget);
    });

    testWidgets('shows loading message when infiniteLoading is true and products are empty', (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final productProvider = ProductProvider();
      productProvider.setInfiniteForTesting(
        products: [],
        loading: true,
        hasMore: true,
        initialized: true,
      );

      await tester.pumpWidget(createTestApp(productProvider));
      await tester.pump();

      expect(find.text('Loading fresh orchard harvest...'), findsOneWidget);
    });

    testWidgets('displays Explore All Products header and items when loaded', (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final productProvider = ProductProvider();
      final items = List.generate(
        10,
        (i) => makeProduct(i + 1, 'Kashmiri Apple $i', 4.8, 12),
      );
      productProvider.setInfiniteForTesting(
        products: items,
        loading: false,
        hasMore: true,
        initialized: true,
      );

      await tester.pumpWidget(createTestApp(productProvider));
      await tester.pump();

      expect(find.text('Explore All Products'), findsOneWidget);
      expect(find.text('10 items'), findsOneWidget);
      expect(find.text('Fresh Kashmiri harvest • Top rated reviews first'), findsOneWidget);
    });

    testWidgets('shows end-of-catalog banner and Back to Top button when infiniteHasMore is false', (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final productProvider = ProductProvider();
      final items = List.generate(
        10,
        (i) => makeProduct(i + 1, 'Kashmiri Apple $i', 4.8, 12),
      );
      productProvider.setInfiniteForTesting(
        products: items,
        loading: false,
        hasMore: false,
        initialized: true,
      );

      await tester.pumpWidget(createTestApp(productProvider));
      await tester.pump();

      final backToTopFinder = find.byKey(const Key('infinite_back_to_top_btn'));
      expect(backToTopFinder, findsOneWidget);

      expect(find.text("You've reached the end of our orchard catalog"), findsOneWidget);
      expect(find.text('Showing all 10 verified products sorted by rating'), findsOneWidget);

      // Verify tap on Back to Top executes smoothly
      await tester.tap(backToTopFinder);
      await tester.pumpAndSettle();
    });
  });
}
