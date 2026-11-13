import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magray_orchards/models/user.dart';
import 'package:magray_orchards/providers/address_provider.dart';
import 'package:magray_orchards/providers/auth_provider.dart';
import 'package:magray_orchards/providers/cart_provider.dart';
import 'package:magray_orchards/providers/notification_provider.dart';
import 'package:magray_orchards/providers/order_provider.dart';
import 'package:magray_orchards/providers/product_provider.dart';
import 'package:magray_orchards/providers/reels_provider.dart';
import 'package:magray_orchards/providers/subscription_provider.dart';
import 'package:magray_orchards/providers/theme_provider.dart';
import 'package:magray_orchards/providers/wallet_provider.dart';
import 'package:magray_orchards/providers/wishlist_provider.dart';
import 'package:magray_orchards/screens/splash_screen.dart';
import 'package:magray_orchards/services/shop_config.dart';

class _MockAuthProvider extends AuthProvider {
  User? _mockUser;
  bool _mockIsLoggedIn = false;
  bool logoutCalled = false;
  bool checkAccountStatusCalled = false;

  void setMockLoggedIn(User user) {
    _mockUser = user;
    _mockIsLoggedIn = true;
  }

  @override
  User? get user => _mockUser;

  @override
  bool get isLoggedIn => _mockIsLoggedIn;

  @override
  Future<void> logout() async {
    logoutCalled = true;
    _mockUser = null;
    _mockIsLoggedIn = false;
    notifyListeners();
  }

  @override
  Future<User?> checkAccountStatus() async {
    checkAccountStatusCalled = true;
    if (_mockUser != null && !_mockUser!.isActive) {
      await logout();
      throw const AccountBlockedException('Your Account Has Been Blocked');
    }
    return _mockUser;
  }
}

class _MockThemeProvider extends ThemeProvider {
  @override
  Future<void> init() async {}
}

class _MockCartProvider extends CartProvider {
  @override
  Future<void> loadFromLocal() async {}
}

Widget _buildSplashTestApp({
  required _MockAuthProvider authProvider,
  _MockThemeProvider? themeProvider,
  _MockCartProvider? cartProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<ThemeProvider>.value(
        value: themeProvider ?? _MockThemeProvider(),
      ),
      ChangeNotifierProvider<CartProvider>.value(
        value: cartProvider ?? _MockCartProvider(),
      ),
      ChangeNotifierProvider(create: (_) => ProductProvider()),
      ChangeNotifierProvider(create: (_) => OrderProvider()),
      ChangeNotifierProvider(create: (_) => AddressProvider()),
      ChangeNotifierProvider(create: (_) => WishlistProvider()),
      ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ChangeNotifierProvider(create: (_) => WalletProvider()),
      ChangeNotifierProvider(create: (_) => ReelsProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
    ],
    child: const MaterialApp(
      home: SplashScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Magray Orchards',
      packageName: 'com.magray.orchards',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    SplashScreen.minSplashDuration = Duration.zero;
    SplashScreen.stepPacing = Duration.zero;
    ShopConfig.mockLoaderForTesting = () async => true;
    ShopConfig.setMaintenanceForTesting(false);
    ShopConfig.setMinVersionForTesting('1.0.0');
  });

  tearDown(() {
    SplashScreen.minSplashDuration = const Duration(seconds: 3);
    SplashScreen.stepPacing = const Duration(milliseconds: 600);
    ShopConfig.mockLoaderForTesting = null;
  });

  group('SplashScreen Gate Checks & UI', () {
    testWidgets('renders clean splash screen with text, loading bar and Kashmir footer', (tester) async {
      SplashScreen.stepPacing = const Duration(milliseconds: 100);
      final auth = _MockAuthProvider();

      await tester.pumpWidget(_buildSplashTestApp(authProvider: auth));
      await tester.pump();

      expect(find.text('Magray Orchards'), findsOneWidget);
      expect(find.text('Premium Agriculture & Orchard Care'), findsOneWidget);
      expect(find.text('Made in Kashmir with ♡ '), findsOneWidget);
      expect(find.byType(Icon), findsNothing);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
    });

    testWidgets('shows No Internet Connection when network check fails', (tester) async {
      ShopConfig.mockLoaderForTesting = () async => false;

      final auth = _MockAuthProvider();
      await tester.pumpWidget(_buildSplashTestApp(authProvider: auth));
      await tester.pumpAndSettle();

      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(find.text('Retry Connection'), findsOneWidget);
    });

    testWidgets('shows Under Maintenance when maintenance mode is active', (tester) async {
      ShopConfig.setMaintenanceForTesting(
        true,
        'Upgrading our orchards portal. Back soon!',
        '10:30 PM',
      );

      final auth = _MockAuthProvider();
      await tester.pumpWidget(_buildSplashTestApp(authProvider: auth));
      await tester.pumpAndSettle();

      expect(find.text('Under Maintenance'), findsOneWidget);
      expect(find.text('Upgrading our orchards portal. Back soon!'), findsOneWidget);
      expect(find.text('Expected back: 10:30 PM'), findsOneWidget);
      expect(find.text('Check Again'), findsOneWidget);
    });

    testWidgets('shows Update Required when installed version is below minimum', (tester) async {
      ShopConfig.setMinVersionForTesting('9.9.9');

      final auth = _MockAuthProvider();
      await tester.pumpWidget(_buildSplashTestApp(authProvider: auth));
      await tester.pumpAndSettle();

      expect(find.text('Update Required'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
      expect(find.textContaining('Required: 9.9.9+'), findsOneWidget);
    });

    testWidgets('logs out inactive user and displays Your Account Has Been Blocked', (tester) async {
      final auth = _MockAuthProvider();
      auth.setMockLoggedIn(User(
        id: 42,
        name: 'Blocked User',
        phone: '9999999999',
        isActive: false,
      ));

      await tester.pumpWidget(_buildSplashTestApp(authProvider: auth));
      await tester.pumpAndSettle();

      expect(auth.checkAccountStatusCalled, isTrue);
      expect(auth.logoutCalled, isTrue);
      expect(find.text('Account Blocked'), findsOneWidget);
      expect(find.text('Your Account Has Been Blocked. You have been signed out.'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
      expect(find.text('Log in with Another Account'), findsOneWidget);
    });

    test('AccountBlockedException preserves custom message', () {
      const defaultEx = AccountBlockedException();
      expect(defaultEx.message, 'Your Account Has Been Blocked');
      expect(defaultEx.toString(), 'Your Account Has Been Blocked');

      const customEx = AccountBlockedException('Account suspended by admin');
      expect(customEx.message, 'Account suspended by admin');
      expect(customEx.toString(), 'Account suspended by admin');
    });
  });
}
