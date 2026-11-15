import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magray_orchards/models/product.dart';
import 'package:magray_orchards/providers/personalization_provider.dart';
import 'package:magray_orchards/services/user_activity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Personalization & User Activity Tests', () {
    final sampleProduct1 = Product(
      id: 101,
      name: 'SK5 Orchard Lopper',
      slug: 'sk5-orchard-lopper',
      price: 1850.0,
      stockQuantity: 15,
      isActive: true,
      isFeatured: true,
      categoryId: 3,
    );

    final sampleProduct2 = Product(
      id: 102,
      name: 'Copper Oxychloride 50 WP',
      slug: 'copper-oxychloride-50-wp',
      price: 650.0,
      stockQuantity: 40,
      isActive: true,
      categoryId: 1,
    );

    test('UserActivityService persists and retrieves viewed products locally', () async {
      await UserActivityService.recordProductView(sampleProduct1);
      await UserActivityService.recordProductView(sampleProduct2);

      final recents = await UserActivityService.getLocalRecentProducts();
      expect(recents.length, 2);
      expect(recents[0].id, 102); // Most recent first
      expect(recents[1].id, 101);

      // Verify clear works
      await UserActivityService.clearLocalHistory();
      final cleared = await UserActivityService.getLocalRecentProducts();
      expect(cleared.isEmpty, true);
    });

    test('PersonalizationProvider logs product views and notifies listeners', () async {
      final provider = PersonalizationProvider();
      expect(provider.recentlyViewed.isEmpty, true);

      await provider.logProductView(sampleProduct1);
      expect(provider.recentlyViewed.length, 1);
      expect(provider.recentlyViewed.first.name, 'SK5 Orchard Lopper');

      await provider.logProductView(sampleProduct2);
      expect(provider.recentlyViewed.length, 2);
      expect(provider.recentlyViewed.first.name, 'Copper Oxychloride 50 WP');

      await provider.clearRecentlyViewed();
      expect(provider.recentlyViewed.isEmpty, true);
    });

    test('UserActivityService returns persistent device session ID', () async {
      final sid1 = await UserActivityService.getSessionId();
      final sid2 = await UserActivityService.getSessionId();
      expect(sid1.isNotEmpty, true);
      expect(sid1, sid2);
    });
  });
}
