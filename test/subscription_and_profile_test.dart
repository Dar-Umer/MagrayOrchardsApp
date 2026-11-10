import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magray_orchards/providers/auth_provider.dart';
import 'package:magray_orchards/providers/subscription_provider.dart';
import 'package:magray_orchards/screens/change_password_screen.dart';
import 'package:magray_orchards/screens/edit_profile_screen.dart';
import 'package:magray_orchards/screens/forgot_password_screen.dart';
import 'package:magray_orchards/screens/subscription_screen.dart';

class _FakeSubscriptionProvider extends SubscriptionProvider {
  @override
  Map<String, dynamic>? get lastSubscription => const {
        'id': 1,
        'status': 'expired',
        'end_date': '2026-09-15T18:30:00.000000Z',
        'plan': {'name': 'Basic', 'price': '99.00', 'billing_period': 'monthly'},
      };

  @override
  Future<void> loadMySubscription() async {}

  @override
  Future<void> loadPaidContents() async {}
}

void main() {
  group('Subscription date and price formatting', () {
    test('formatSubscriptionDate removes raw ISO timestamps and trailing zeros', () {
      const raw = '2026-09-15T18:30:00.000000Z';
      final expected = DateFormat('d MMM yyyy').format(DateTime.parse(raw).toLocal());

      final formatted = formatSubscriptionDate(raw);

      expect(formatted, expected);
      expect(formatted, isNot(contains('000000')));
      expect(formatted, isNot(contains('T')));
      expect(
        formatSubscriptionDate('2026-10-05'),
        DateFormat('d MMM yyyy').format(DateTime.parse('2026-10-05').toLocal()),
      );
      expect(formatSubscriptionDate(null), '');
    });

    test('formatSubscriptionPrice strips trailing .00 zeros cleanly', () {
      expect(formatSubscriptionPrice('99.00'), '99');
      expect(formatSubscriptionPrice(199.0), '199');
      expect(formatSubscriptionPrice(199.5), '199.50');
    });

    testWidgets('SubscriptionScreen renders formatted date without zeros', (tester) async {
      SharedPreferences.setMockInitialValues({});
      const raw = '2026-09-15T18:30:00.000000Z';
      final expected = DateFormat('d MMM yyyy').format(DateTime.parse(raw).toLocal());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider<SubscriptionProvider>(
              create: (_) => _FakeSubscriptionProvider(),
            ),
          ],
          child: const MaterialApp(
            home: SubscriptionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ended $expected'), findsOneWidget);
      expect(find.textContaining('000000Z'), findsNothing);
      expect(find.text('No Active Subscription'), findsOneWidget);
    });
  });

  group('Profile Password Reset Navigation Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('EditProfileScreen shows Reset Password button and opens ChangePasswordScreen', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
          child: const MaterialApp(
            home: EditProfileScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Reset Password'), findsOneWidget);

      await tester.ensureVisible(find.text('Reset Password'));
      await tester.tap(find.text('Reset Password'));
      await tester.pumpAndSettle();

      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      expect(find.text('Update your password'), findsOneWidget);

      final otpButton = find.text('Reset via Mobile OTP');
      expect(otpButton, findsOneWidget);
      await tester.ensureVisible(otpButton);
      await tester.tap(otpButton);
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });
  });
}
