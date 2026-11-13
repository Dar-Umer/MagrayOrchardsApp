import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magray_orchards/models/service_model.dart';
import 'package:magray_orchards/providers/auth_provider.dart';
import 'package:magray_orchards/providers/product_provider.dart';
import 'package:magray_orchards/screens/tabs/services_tab.dart';
import 'package:magray_orchards/screens/service_detail_screen.dart';

class TestProductProvider extends ProductProvider {
  final List<ServiceModel> testServices;

  TestProductProvider(this.testServices);

  @override
  List<ServiceModel> get services => testServices;

  @override
  bool get servicesLoading => false;

  @override
  Future<void> fetchServices({bool refresh = false}) async {
    // No-op for tests
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final sampleServices = [
    ServiceModel(
      id: 1,
      name: 'High-Density Orchard Pruning',
      slug: 'orchard-pruning',
      description: 'Professional tree pruning by certified orchardists.',
      shortDescription: 'Tree pruning for fruit trees',
      basePrice: 50.0,
      priceUnit: 'per_tree',
      priceUnitLabel: 'Per Tree',
      serviceType: 'physical',
      minQuantity: 10,
      maxQuantity: 500,
      durationEstimate: '1-2 days',
      isFeatured: true,
      categoryName: 'Tree Care',
    ),
    ServiceModel(
      id: 2,
      name: 'Pesticide & Nutrient Spraying',
      slug: 'pesticide-spraying',
      description: 'Motorized pesticide spraying service.',
      shortDescription: 'Motorized spray coverage',
      basePrice: 150.0,
      priceUnit: 'per_kanal',
      priceUnitLabel: 'Per Kanal',
      serviceType: 'physical',
      durationEstimate: '1 day',
      isFeatured: true,
      categoryName: 'Sprayers',
    ),
    ServiceModel(
      id: 3,
      name: 'Soil Testing & Analysis',
      slug: 'soil-testing',
      description: 'Full soil health and nutrient testing.',
      shortDescription: 'Laboratory soil testing',
      basePrice: 350.0,
      priceUnit: 'per_kanal',
      priceUnitLabel: 'Per Kanal',
      serviceType: 'physical',
      durationEstimate: '7 days',
      isFeatured: false,
      categoryName: 'Testing',
    ),
  ];

  testWidgets('ServicesTab renders hero banner, search bar, filter chips, and rich service cards',
      (tester) async {
    final testProvider = TestProductProvider(sampleServices);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider<ProductProvider>.value(value: testProvider),
        ],
        child: const MaterialApp(
          home: ServicesTab(),
        ),
      ),
    );

    await tester.pump();

    // Verify AppBar and Hero Banner
    expect(find.text('Orchard Services'), findsOneWidget);
    expect(find.text('Doorstep Orchard Care'), findsOneWidget);
    expect(find.text('Per Tree & Per Kanal'), findsOneWidget);

    // Verify Search Box and Filter Chips
    expect(find.byType(TextField), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'All (3)'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Per Tree'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Per Kanal'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Featured'), findsOneWidget);

    // Verify Service Cards and Formatted Prices
    expect(find.text('High-Density Orchard Pruning'), findsOneWidget);
    expect(find.text('Rs. 50 / Tree'), findsOneWidget);
    expect(find.text('10 – 500 trees'), findsOneWidget);
    expect(find.text('Pesticide & Nutrient Spraying'), findsOneWidget);
    expect(find.text('Rs. 150 / Kanal'), findsOneWidget);
    expect(find.text('Soil Testing & Analysis'), findsOneWidget);
    expect(find.text('Rs. 350 / Kanal'), findsOneWidget);

    // Verify "Book Service" CTA buttons exist
    expect(find.text('Book Service'), findsNWidgets(3));
  });

  testWidgets('ServicesTab filters by Per Tree and Per Kanal chips',
      (tester) async {
    final testProvider = TestProductProvider(sampleServices);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider<ProductProvider>.value(value: testProvider),
        ],
        child: const MaterialApp(
          home: ServicesTab(),
        ),
      ),
    );

    await tester.pump();

    // Tap "Per Tree" filter chip
    await tester.tap(find.widgetWithText(ChoiceChip, 'Per Tree'));
    await tester.pump();

    // Only Pruning should be displayed
    expect(find.text('High-Density Orchard Pruning'), findsOneWidget);
    expect(find.text('Pesticide & Nutrient Spraying'), findsNothing);
    expect(find.text('Soil Testing & Analysis'), findsNothing);

    // Tap "Per Kanal" filter chip
    await tester.tap(find.widgetWithText(ChoiceChip, 'Per Kanal'));
    await tester.pump();

    // Both Spraying and Soil Testing should be displayed
    expect(find.text('High-Density Orchard Pruning'), findsNothing);
    expect(find.text('Pesticide & Nutrient Spraying'), findsOneWidget);
    expect(find.text('Soil Testing & Analysis'), findsOneWidget);
  });

  testWidgets('ServicesTab search field filters services dynamically',
      (tester) async {
    final testProvider = TestProductProvider(sampleServices);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider<ProductProvider>.value(value: testProvider),
        ],
        child: const MaterialApp(
          home: ServicesTab(),
        ),
      ),
    );

    await tester.pump();

    // Search "soil"
    await tester.enterText(find.byType(TextField), 'soil');
    await tester.pump();

    expect(find.text('Soil Testing & Analysis'), findsOneWidget);
    expect(find.text('High-Density Orchard Pruning'), findsNothing);
    expect(find.text('Pesticide & Nutrient Spraying'), findsNothing);
  });

  testWidgets('ServiceDetailScreen displays Payment Method options and updates CTA button',
      (tester) async {
    final pruningService = sampleServices[0];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: MaterialApp(
          home: ServiceDetailScreen(service: pruningService),
        ),
      ),
    );

    await tester.pump();

    // Verify Payment Method header and options exist
    expect(find.text('Payment Method'), findsOneWidget);
    expect(find.text('Pay on Visit (Cash / UPI)'), findsOneWidget);
    expect(find.text('Pay Online Now'), findsOneWidget);

    // Initial button text for 'visit' method
    expect(find.textContaining('Confirm Booking'), findsOneWidget);

    // Tap Pay Online Now option
    await tester.tap(find.text('Pay Online Now'), warnIfMissed: false);
    await tester.pump();

    // Button updates to Pay Online
    expect(find.textContaining('Pay Online'), findsOneWidget);
  });
}
