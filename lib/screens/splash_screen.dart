import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/shop_config.dart';
import '../widgets/maintenance_screen.dart';
import '../widgets/update_required_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final theme = context.read<ThemeProvider>();
      await theme.init();
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      await _runGate();
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  Future<void> _runGate() async {
    // Maintenance mode blocks the app entirely.
    if (ShopConfig.maintenanceEnabled) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MaintenanceScreen()));
      return;
    }

    // Force update if the installed version is below the platform minimum.
    // Works on all platforms, including web (reads the app version).
    try {
      final info = await PackageInfo.fromPlatform();
      final installed = info.version;
      if (ShopConfig.compareVersions(installed, ShopConfig.minVersion) < 0) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UpdateRequiredScreen(installedVersion: installed)));
        return;
      }
    } catch (_) {
      // Unable to read version — continue to the app.
    }

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 80, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(height: 16),
            Text(
              'Magray Orchards',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Premium Agriculture & Farming',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
