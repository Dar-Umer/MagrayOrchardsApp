import 'package:flutter/material.dart';
import '../services/shop_config.dart';

class MaintenanceScreen extends StatefulWidget {
  final Future<void> Function()? onRetry;
  const MaintenanceScreen({super.key, this.onRetry});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  bool _isChecking = false;

  Future<void> _handleRetry() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    try {
      if (widget.onRetry != null) {
        await widget.onRetry!();
      } else {
        await ShopConfig.load();
        if (!ShopConfig.maintenanceEnabled && mounted) {
          Navigator.of(context).pop();
        }
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final message = ShopConfig.maintenanceMessage;
    final until = ShopConfig.maintenanceUntil;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.construction, size: 48, color: primary),
              ),
              const SizedBox(height: 24),
              Text(
                'Under Maintenance',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (until.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 18, color: primary),
                      const SizedBox(width: 6),
                      Text(
                        'Expected to resume: $until',
                        style: TextStyle(fontWeight: FontWeight.w600, color: primary),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isChecking ? null : _handleRetry,
                  icon: _isChecking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(_isChecking ? 'Checking...' : 'Check Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
