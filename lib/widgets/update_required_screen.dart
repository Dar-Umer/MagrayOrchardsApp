import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/shop_config.dart';

class UpdateRequiredScreen extends StatelessWidget {
  final String installedVersion;
  const UpdateRequiredScreen({super.key, required this.installedVersion});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final storeUrl = ShopConfig.storeUrl;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
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
                child: Icon(Icons.system_update_alt, size: 48, color: primary),
              ),
              const SizedBox(height: 24),
              Text(
                'Update Required',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'A new version of Magray Orchards is available. Please update the app to continue.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Your version', style: Theme.of(context).textTheme.bodySmall),
                        Text(installedVersion, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Required version', style: Theme.of(context).textTheme.bodySmall),
                        Text('${ShopConfig.latestVersion}+', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (ShopConfig.updateNotes.isNotEmpty) ...[
                      const Divider(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          ShopConfig.updateNotes,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (storeUrl.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(storeUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.storefront),
                    label: const Text('Update Now'),
                  ),
                )
              else
                const Text(
                  'Please update the app from your app store.',
                  style: TextStyle(color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
