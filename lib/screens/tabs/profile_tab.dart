import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/pro_member_badge.dart';
import '../address_screen.dart';
import '../change_password_screen.dart';
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
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final primary = Theme.of(context).colorScheme.primary;

    if (!auth.isLoggedIn) {
      return SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                const SizedBox(height: 32),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: primary.withValues(alpha: 0.1),
                  child: Text(
                    (user?.name ?? 'U').isNotEmpty
                        ? (user?.name ?? 'U')[0].toUpperCase()
                        : 'U',
                    style: TextStyle(fontSize: 36, color: primary),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user?.name ?? '',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (user?.isProMember == true) ...[
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
                        leading: Icon(Icons.lock_reset, color: primary),
                        title: const Text('Reset Password'),
                        subtitle: const Text('Change password or recover via OTP'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChangePasswordScreen(),
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
                    onPressed: () => auth.logout(),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label:
                        const Text('Logout', style: TextStyle(color: Colors.red)),
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
