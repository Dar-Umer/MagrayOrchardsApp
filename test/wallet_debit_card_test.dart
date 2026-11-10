import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magray_orchards/widgets/wallet_debit_card.dart';

void main() {
  group('WalletDebitCard Widget Tests', () {
    testWidgets('renders debit card fields and toggles balance masking', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: WalletDebitCard(
                balance: 1250.50,
                cardHolderName: 'Aarif Magray',
                brandName: 'Magray Orchards',
                userId: 42,
                isProMember: true,
                isLoading: false,
                primaryColor: Color(0xFF0D9488),
              ),
            ),
          ),
        ),
      );

      expect(find.text('MAGRAY ORCHARDS'), findsOneWidget);
      expect(find.text('PREPAID WALLET'), findsOneWidget);
      expect(find.text('Rs. 1,250.50'), findsOneWidget);
      expect(find.text('6078  ••••  ••••  1042'), findsOneWidget);
      expect(find.text('AARIF MAGRAY'), findsOneWidget);
      expect(find.text('PRO ACTIVE'), findsOneWidget);

      await tester.tap(find.byTooltip('Hide balance'));
      await tester.pump();

      expect(find.text('Rs. •••••'), findsOneWidget);
      expect(find.text('Rs. 1,250.50'), findsNothing);

      await tester.tap(find.byTooltip('Show balance'));
      await tester.pump();

      expect(find.text('Rs. 1,250.50'), findsOneWidget);
    });

    testWidgets('fits small 360px screen with enlarged text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.35)),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: WalletDebitCard(
                  balance: 98420.00,
                  cardHolderName: 'Mohammad Tariq Magray',
                  brandName: 'Magray Orchards',
                  userId: 7,
                  isProMember: false,
                  isLoading: false,
                  primaryColor: Color(0xFF059669),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Rs. 98,420.00'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
    });
  });
}
