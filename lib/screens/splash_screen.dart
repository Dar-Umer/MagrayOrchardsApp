import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/shop_config.dart';
import 'home_screen.dart';
import 'phone_input_screen.dart';

enum SplashCheckStep {
  initializing,
  checkingNetwork,
  checkingVersion,
  checkingMaintenance,
  checkingUser,
  complete,
}

enum SplashGateFailure {
  none,
  network,
  version,
  maintenance,
  blocked,
}

class SplashScreen extends StatefulWidget {
  @visibleForTesting
  static Duration minSplashDuration = const Duration(seconds: 3);
  @visibleForTesting
  static Duration stepPacing = const Duration(milliseconds: 600);

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  SplashCheckStep _currentStep = SplashCheckStep.initializing;
  SplashGateFailure _failure = SplashGateFailure.none;
  String? _failureMessage;
  String _installedVersion = '1.0.0';
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupChecks();
    });
  }

  double get _progressValue {
    switch (_currentStep) {
      case SplashCheckStep.initializing:
        return 0.10;
      case SplashCheckStep.checkingNetwork:
        return 0.30;
      case SplashCheckStep.checkingVersion:
        return 0.55;
      case SplashCheckStep.checkingMaintenance:
        return 0.75;
      case SplashCheckStep.checkingUser:
        return 0.90;
      case SplashCheckStep.complete:
        return 1.00;
    }
  }

  String get _stepLabel {
    switch (_currentStep) {
      case SplashCheckStep.initializing:
        return 'Starting Magray Orchards...';
      case SplashCheckStep.checkingNetwork:
        return 'Checking network connection...';
      case SplashCheckStep.checkingVersion:
        return 'Verifying app version...';
      case SplashCheckStep.checkingMaintenance:
        return 'Checking server maintenance...';
      case SplashCheckStep.checkingUser:
        return 'Verifying account status...';
      case SplashCheckStep.complete:
        return 'Ready! Welcome to Magray Orchards';
    }
  }

  Future<void> _runStartupChecks() async {
    final startTime = DateTime.now();

    if (!mounted) return;
    setState(() {
      _isRetrying = false;
      _failure = SplashGateFailure.none;
      _failureMessage = null;
      _currentStep = SplashCheckStep.checkingNetwork;
    });

    // ── 1. Network Check ─────────────────────────────────────────────────────
    if (SplashScreen.stepPacing > Duration.zero) {
      await Future.delayed(SplashScreen.stepPacing);
    }
    if (!mounted) return;

    try {
      final loaded = await ShopConfig.load(rethrowErrors: true);
      if (!loaded) {
        throw ApiException(
          statusCode: 0,
          message: 'Unable to connect to Magray Orchards servers. Please check your connection.',
        );
      }
      if (mounted) {
        try {
          await context.read<ThemeProvider>().refresh();
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failure = SplashGateFailure.network;
        _failureMessage = e is ApiException && e.message.isNotEmpty
            ? e.message
            : 'Unable to reach the server. Please check your internet connection.';
      });
      return;
    }

    // ── 2. Version Number Check ──────────────────────────────────────────────
    if (!mounted) return;
    setState(() => _currentStep = SplashCheckStep.checkingVersion);
    if (SplashScreen.stepPacing > Duration.zero) {
      await Future.delayed(SplashScreen.stepPacing);
    }
    if (!mounted) return;

    try {
      final info = await PackageInfo.fromPlatform();
      _installedVersion = info.version;
    } catch (_) {
      _installedVersion = '1.0.0';
    }

    final isBelowMin = ShopConfig.compareVersions(_installedVersion, ShopConfig.minVersion) < 0;
    if (isBelowMin) {
      if (!mounted) return;
      setState(() {
        _failure = SplashGateFailure.version;
        _failureMessage = 'An update is required to continue using Magray Orchards.';
      });
      return;
    }

    // ── 3. Maintenance Mode Check ────────────────────────────────────────────
    if (!mounted) return;
    setState(() => _currentStep = SplashCheckStep.checkingMaintenance);
    if (SplashScreen.stepPacing > Duration.zero) {
      await Future.delayed(SplashScreen.stepPacing);
    }
    if (!mounted) return;

    if (ShopConfig.maintenanceEnabled) {
      setState(() {
        _failure = SplashGateFailure.maintenance;
        _failureMessage = ShopConfig.maintenanceMessage.isNotEmpty
            ? ShopConfig.maintenanceMessage
            : 'We are currently performing scheduled maintenance. Please check back soon.';
      });
      return;
    }

    // ── 4. Logged-in User Active Check ───────────────────────────────────────
    if (!mounted) return;
    setState(() => _currentStep = SplashCheckStep.checkingUser);
    if (SplashScreen.stepPacing > Duration.zero) {
      await Future.delayed(SplashScreen.stepPacing);
    }
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    try {
      final user = await auth.checkAccountStatus();
      if (user != null && !user.isActive) {
        await auth.logout();
        if (!mounted) return;
        setState(() {
          _failure = SplashGateFailure.blocked;
          _failureMessage = 'Your Account Has Been Blocked';
        });
        return;
      }
    } on AccountBlockedException catch (e) {
      await auth.logout();
      if (!mounted) return;
      setState(() {
        _failure = SplashGateFailure.blocked;
        _failureMessage = e.message;
      });
      return;
    } catch (e) {
      debugPrint('User active check warning: $e');
    }

    // ── 5. Completion & Initialization ───────────────────────────────────────
    if (!mounted) return;
    setState(() => _currentStep = SplashCheckStep.complete);

    if (mounted) {
      try {
        final theme = context.read<ThemeProvider>();
        await theme.init();
      } catch (_) {}
    }
    if (mounted) {
      try {
        final cart = context.read<CartProvider>();
        await cart.loadFromLocal();
      } catch (_) {}
    }

    // Pre-fetch home screen feeds in the background while splash finishes
    if (mounted) {
      try {
        final pp = context.read<ProductProvider>();
        if (pp.products.isEmpty) {
          unawaited(Future.wait([
            pp.fetchProducts(isFeatured: true, page: 1, perPage: 15),
            pp.fetchProducts(sortBy: 'newest', page: 1, perPage: 15),
            pp.fetchCategories(),
            pp.fetchServices(),
            pp.fetchBanners(),
            pp.fetchOfferProducts(perPage: 20),
            pp.fetchBrands(),
          ]));
        }
      } catch (_) {}
    }

    // Ensure total splash duration meets the required timing (3 seconds)
    if (SplashScreen.minSplashDuration > Duration.zero) {
      final elapsed = DateTime.now().difference(startTime);
      final remaining = SplashScreen.minSplashDuration - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }
    }
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _handleContinueAsGuestAfterBlocked() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your Account Has Been Blocked'),
        backgroundColor: Color(0xFF991B1B),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _handleLoginAnotherAccount() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PhoneInputScreen()),
    );
  }

  Future<void> _handleLaunchStore() async {
    final url = ShopConfig.storeUrl;
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: primaryColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: primaryColor,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: primaryColor,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
          // ── Centered Main Content (Title, Subtitle, Progress / Action) ───
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Brand Title & Subtitle (Text Only - No Logo)
                    const Text(
                      'Magray Orchards',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Premium Agriculture & Orchard Care',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 0.2,
                      ),
                    ),

                    const SizedBox(height: 44),

                    // Loading Bar & Live Status (or Failure View)
                    if (_failure != SplashGateFailure.none)
                      _buildFailureView()
                    else
                      _buildProgressView(),
                  ],
                ),
              ),
            ),
          ),

          // ── Centered Footer Pinned at Bottom ─────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  'Made in Kashmir with ♡ ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.70),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildProgressView() {
    return SizedBox(
      width: 240,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: _progressValue),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 4,
                  width: double.infinity,
                  color: Colors.white.withValues(alpha: 0.22),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _stepLabel,
              key: ValueKey<String>(_stepLabel),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailureView() {
    switch (_failure) {
      case SplashGateFailure.network:
        return _buildCleanAction(
          title: 'No Internet Connection',
          message: _failureMessage ??
              'Unable to connect to server. Please check your connection.',
          actionLabel: _isRetrying ? 'Connecting...' : 'Retry Connection',
          onAction: _isRetrying
              ? null
              : () {
                  setState(() => _isRetrying = true);
                  _runStartupChecks();
                },
        );

      case SplashGateFailure.version:
        return _buildCleanAction(
          title: 'Update Required',
          message: 'A new version of Magray Orchards is available. Please update the app to continue.',
          detail: 'Installed: $_installedVersion  •  Required: ${ShopConfig.minVersion}+',
          actionLabel: 'Update Now',
          onAction: _handleLaunchStore,
        );

      case SplashGateFailure.maintenance:
        return _buildCleanAction(
          title: 'Under Maintenance',
          message: _failureMessage ??
              'We are currently undergoing maintenance. Please check back shortly.',
          detail: ShopConfig.maintenanceUntil.isNotEmpty
              ? 'Expected back: ${ShopConfig.maintenanceUntil}'
              : null,
          actionLabel: _isRetrying ? 'Checking...' : 'Check Again',
          onAction: _isRetrying
              ? null
              : () {
                  setState(() => _isRetrying = true);
                  _runStartupChecks();
                },
        );

      case SplashGateFailure.blocked:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Account Blocked',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Account Has Been Blocked. You have been signed out.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: _handleContinueAsGuestAfterBlocked,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                ),
                child: const Text(
                  'Continue as Guest',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _handleLoginAnotherAccount,
              child: Text(
                'Log in with Another Account',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        );

      case SplashGateFailure.none:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCleanAction({
    required String title,
    required String message,
    String? detail,
    required String actionLabel,
    required VoidCallback? onAction,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.35,
            ),
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 40,
          child: ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).colorScheme.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
