import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/address_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/pro_member_badge.dart';
import '../../widgets/profile_avatar.dart';
import '../address_screen.dart';
import '../edit_profile_screen.dart';
import '../login_screen.dart';
import '../my_bookings_screen.dart';
import '../notifications_screen.dart';
import '../orders_screen.dart';
import '../register_screen.dart';
import '../subscription_screen.dart';
import '../wallet_screen.dart';
import '../wishlist_screen.dart';

/// Account & settings tab displayed from the root navigation shell.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _uploadingAvatar = false;

  Future<void> _handleAvatarUpload(XFile file) async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await file.readAsBytes();
      final ok = await auth.uploadAvatar(bytes, file.name);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Profile picture updated!'
                : (auth.errorMessage ?? 'Could not upload profile picture.'),
          ),
          backgroundColor: ok ? primary : Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final primary = Theme.of(context).colorScheme.primary;
    final isSubscribed = (user?.isProMember == true) ||
        (user?.currentPlan != null && user!.currentPlan!.isNotEmpty) ||
        context.watch<SubscriptionProvider>().currentSubscription != null;

    if (!auth.isLoggedIn) {
      return SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    child: const Icon(Icons.person, size: 50, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Guest',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Login to access your account',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Create Account',
                        style: TextStyle(fontSize: 16, color: primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                const SizedBox(height: 24),
                ProfileAvatar(
                  initial: (user?.name ?? 'U').isNotEmpty
                      ? (user?.name ?? 'U')[0].toUpperCase()
                      : 'U',
                  avatarPath: user?.avatar,
                  primaryColor: primary,
                  isSubscribed: isSubscribed,
                  isUploading: _uploadingAvatar,
                  onPickImage: _handleAvatarUpload,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        user?.name ?? '',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSubscribed) ...[
                      const SizedBox(width: 8),
                      const ProMemberBadge(isProMember: true, compact: true),
                    ],
                  ],
                ),
                Text(user?.email ?? '', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.edit, color: primary),
                        title: const Text('Edit Profile'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        ),
                      ),
                      const Divider(indent: 52),
                      ListTile(
                        leading: Icon(Icons.workspace_premium, color: primary),
                        title: const Text('My Subscription'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        ),
                      ),
                      const Divider(indent: 52),
                      ListTile(
                        leading: Icon(Icons.shopping_bag, color: primary),
                        title: const Text('My Orders'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OrdersScreen()),
                        ),
                      ),
                      const Divider(indent: 52),
                      ListTile(
                        leading: Icon(Icons.calendar_month, color: primary),
                        title: const Text('My Bookings'),
                        subtitle: const Text('Service visits & payments'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyBookingsScreen(),
                          ),
                        ),
                      ),
                      const Divider(indent: 52),
                      ListTile(
                        leading:
                            Icon(Icons.account_balance_wallet, color: primary),
                        title: const Text('My Wallet'),
                        subtitle: const Text('View balance & transactions'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const WalletScreen()),
                        ),
                      ),
                      const Divider(indent: 52),
                      ListTile(
                        leading: Icon(Icons.notifications_none, color: primary),
                        title: const Text('Notifications'),
                        subtitle: const Text('Order updates & offers'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                      ),
                      const Divider(indent: 52),
                      ListTile(
                        leading: Icon(Icons.location_on, color: primary),
                        title: const Text('Addresses'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddressScreen(),
                          ),
                        ),
                      ),
                      const Divider(indent: 52),
                      ListTile(
                        leading: Icon(Icons.favorite, color: primary),
                        title: const Text('Wishlist'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WishlistScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (context.mounted) {
                        context.read<AddressProvider>().reset();
                        context.read<OrderProvider>().reset();
                        context.read<WalletProvider>().reset();
                      }
                      await auth.logout();
                      if (context.mounted) {
                        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/login', (route) => false);
                      }
                    },
                    icon: const Icon(Icons.logout, color: Color(0xFFDC2626)),
                    label: const Text('Logout', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
