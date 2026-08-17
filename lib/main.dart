import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'services/shop_config.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ShopConfig.load();
  runApp(const MagrayOrchardsApp());
}

class MagrayOrchardsApp extends StatelessWidget {
  const MagrayOrchardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => AddressProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => ReelsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Magray Orchards',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
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
            },
          );
        },
      ),
    );
  }
}
