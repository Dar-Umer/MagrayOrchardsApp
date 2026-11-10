import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magray_orchards/models/product.dart';
import 'package:magray_orchards/providers/address_provider.dart';
import 'package:magray_orchards/providers/auth_provider.dart';
import 'package:magray_orchards/providers/cart_provider.dart';
import 'package:magray_orchards/providers/wallet_provider.dart';
import 'package:magray_orchards/screens/checkout_screen.dart';
import 'package:magray_orchards/screens/tabs/cart_tab.dart';
import 'package:magray_orchards/utils/formatters.dart';

void main() {
  group('Shared Formatters Tests', () {
    test('formatCurrency consistently formats amounts with Rs. prefix', () {
      expect(formatCurrency(0), 'Rs. 0');
      expect(formatCurrency(99), 'Rs. 99');
      expect(formatCurrency(1250), 'Rs. 1,250');
      expect(formatCurrency(1250.5), 'Rs. 1,250.50');
      expect(formatCurrency(99, alwaysShowDecimals: true), 'Rs. 99.00');
      expect(formatCurrency(-40), '-Rs. 40');
    });

    test('formatDate and formatDateTime format ISO timestamps cleanly', () {
      expect(formatDate('2026-09-15T18:30:00.000000Z'), isNot(contains('000000')));
      expect(formatDateTime('2026-09-15T18:30:00.000000Z'), isNotEmpty);
      expect(formatDateTime('short'), 'short');
    });
  });

  group('CartTab and Express Checkout UI Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('CartTab shows line total, savings banner, and Undo on item removal', (tester) async {
      final cart = CartProvider();
      final product = Product(
        id: 101,
        name: 'Neem Oil Spray',
        slug: 'neem-oil-spray',
        price: 250,
        comparePrice: 350,
      );
      await cart.addItem(product, quantity: 1);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider<CartProvider>.value(value: cart),
          ],
          child: const MaterialApp(
            home: CartTab(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rs. 250'), findsAtLeastNWidgets(1));
      expect(find.text('You are saving Rs. 100 on this order'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove item'));
      await tester.pumpAndSettle();

      expect(cart.items, isEmpty);
      expect(find.text('UNDO'), findsOneWidget);

      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();

      expect(cart.items.length, 1);
      expect(cart.items.first.product.id, 101);
    });

    testWidgets('Express Checkout renders express items without wiping existing cart', (tester) async {
      final cart = CartProvider();
      final savedCartItem = Product(
        id: 1,
        name: 'Saved Pruning Shear',
        slug: 'pruning-shear',
        price: 499,
      );
      final expressItem = Product(
        id: 2,
        name: 'Orchard Copper Fungicide',
        slug: 'copper-fungicide',
        price: 899,
      );
      await cart.addItem(savedCartItem, quantity: 1);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider<CartProvider>.value(value: cart),
            ChangeNotifierProvider(create: (_) => AddressProvider()),
            ChangeNotifierProvider(create: (_) => WalletProvider()),
          ],
          child: MaterialApp(
            home: CheckoutScreen(
              expressItems: [CartItem(product: expressItem, quantity: 2)],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Express Checkout'), findsOneWidget);
      expect(find.text('Orchard Copper Fungicide'), findsOneWidget);
      expect(find.text('Saved Pruning Shear'), findsNothing);
      expect(cart.items.length, 1);
      expect(cart.items.first.product.id, 1);
    });
  });
}
