import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/address_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/reels_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/personalization_provider.dart';
import 'services/shop_config.dart';
import 'services/push_service.dart';
import 'services/location_service.dart';
import 'services/analytics_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/phone_input_screen.dart';
import 'screens/otp_verify_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/address_screen.dart';
import 'screens/wishlist_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/booking_detail_screen.dart';
import 'utils/app_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeProvider = ThemeProvider();
  await Future.wait([
    themeProvider.init().catchError((_) {}),
    ShopConfig.loadFromCache().catchError((_) => false),
  ]);
  try {
    await ShopConfig.load().timeout(const Duration(seconds: 3));
  } catch (_) {}
  await AnalyticsService.instance.init();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushService.instance.initialize();
  await PushService.instance.requestPermission();
  runApp(MagrayOrchardsApp(themeProvider: themeProvider));
  setupPushListeners();
}

/// Global navigator key so push deep-links can navigate from anywhere.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Wires push message listeners (foreground banner + deep-link navigation)
/// once the app has a navigator. Called after runApp.
void setupPushListeners() {
  final push = PushService.instance;
  if (!push.isInitialized) return;

  // Foreground: show an in-app banner.
  push.onMessage.listen((message) {
    final n = push.messageToNotification(message);
    final ctx = appNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      showForegroundPushBanner(ctx, n);
    }
    // Refresh unread badge.
    final navCtx = appNavigatorKey.currentContext;
    if (navCtx != null && navCtx.mounted) {
      final provider = navCtx.read<NotificationProvider>();
      provider.loadUnreadCount();
    }
  });

  // Background/terminated → user taps the notification → deep link.
  push.onMessageOpenedApp.listen((message) {
    _handlePushNavigation(message);
  });

  // App opened from a terminated-state notification.
  push.getInitialMessage().then((message) {
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePushNavigation(message);
      });
    }
  });
}

void _handlePushNavigation(RemoteMessage message) {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return;

  final target = PushService.instance.parseTarget(message);
  switch (target.screen) {
    case 'cart':
      navigator.popUntil((route) => route.isFirst);
      AppNavigation.requestedTab.value = 3;
      break;
    case 'product':
      if (target.id != null || (target.slug != null && target.slug!.isNotEmpty)) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              productId: target.id,
              productSlug: target.slug,
            ),
          ),
        );
      }
      break;
    case 'order':
      if (target.id != null) {
        navigator.push(
          MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: target.id)),
        );
      }
      break;
    case 'booking':
      if (target.id != null) {
        navigator.push(
          MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: target.id)),
        );
      } else {
        navigator.push(
          MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
        );
      }
      break;
    case 'subscription':
      navigator.push(
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
      );
      break;
    case 'notifications':
      navigator.push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
      break;
  }
}

class MagrayOrchardsApp extends StatelessWidget {
  final ThemeProvider? themeProvider;

  const MagrayOrchardsApp({super.key, this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        if (themeProvider != null)
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider!)
        else
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => AddressProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => ReelsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => PersonalizationProvider()),
        ChangeNotifierProvider.value(value: LocationService.instance),
      ],
      child: _SessionCoordinator(
        child: Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            return MaterialApp(
              title: 'Magray Orchards',
              debugShowCheckedModeBanner: false,
              navigatorKey: appNavigatorKey,
              theme: themeProvider.themeData,
              builder: (context, child) {
                if (child == null) return const SizedBox.shrink();
                return SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  bottom: true,
                  child: child,
                );
              },
              home: const SplashScreen(),
              routes: {
                '/home': (_) => const HomeScreen(),
                '/login': (_) => const PhoneInputScreen(),
                '/otp-verify': (_) => const OtpVerifyScreen(),
                '/orders': (_) => const OrdersScreen(),
                '/addresses': (_) => const AddressScreen(),
                '/wishlist': (_) => const WishlistScreen(),
                '/checkout': (_) => const CheckoutScreen(),
                '/wallet': (_) => const WalletScreen(),
                '/bookings': (_) => const MyBookingsScreen(),
                '/notifications': (_) => const NotificationsScreen(),
              },
            );
          },
        ),
      ),
    );
  }
}

class _SessionCoordinator extends StatefulWidget {
  final Widget child;
  const _SessionCoordinator({required this.child});

  @override
  State<_SessionCoordinator> createState() => _SessionCoordinatorState();
}

class _SessionCoordinatorState extends State<_SessionCoordinator> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    auth.setSessionCallbacks(
      onSessionCleared: () {
        if (!mounted) return;
        context.read<CartProvider>().reset();
        context.read<AddressProvider>().reset();
        context.read<OrderProvider>().reset();
        context.read<WalletProvider>().reset();
        context.read<WishlistProvider>().reset();
        context.read<SubscriptionProvider>().reset();
        context.read<NotificationProvider>().reset();
        context.read<PersonalizationProvider>().reset();
      },
      onAuthenticated: () async {
        if (!mounted) return;
        await Future.wait([
          context.read<CartProvider>().pushLocalToServerAndSync(),
          context.read<WishlistProvider>().fetchWishlist(),
          context.read<NotificationProvider>().loadUnreadCount(),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}