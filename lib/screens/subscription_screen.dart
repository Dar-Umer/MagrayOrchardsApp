import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/auth_provider.dart';
import '../models/paid_content.dart';
import '../utils/formatters.dart';
import 'paid_content_detail_screen.dart';
import 'subscription_plans_screen.dart';

/// Formats ISO-8601 API timestamps into a readable local date (`16 Sep 2026`).
String formatSubscriptionDate(dynamic raw) => formatDate(raw);

/// Formats numeric prices without redundant `.00` decimals.
String formatSubscriptionPrice(dynamic raw) {
  final value = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
  if (value == null) return '${raw ?? 0}';
  return value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isCancelling = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SubscriptionProvider>();
      provider.loadMySubscription();
      provider.loadPaidContents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Subscription'),
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, provider, child) {
          final currentSub = provider.currentSubscription;
          final lastSub = provider.lastSubscription;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (currentSub != null) ...[
                      _buildCurrentPlan(currentSub),
                    ] else ...[
                      if (lastSub != null &&
                          (lastSub['status'] == 'cancelled' || lastSub['status'] == 'expired')) ...[
                        _buildLastSubscriptionCard(lastSub),
                        const SizedBox(height: 16),
                      ],
                      _buildNoPlan(),
                    ],
                    const SizedBox(height: 24),
                    const Text('Available Content', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (provider.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (provider.paidContents.isEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: Text('No content available', style: TextStyle(color: Colors.grey))),
                          ),
                        ),
                      )
                    else
                      ...provider.paidContents.map((c) => _ContentCard(content: c)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentPlan(Map<String, dynamic> sub) {
    final plan = sub['plan'] as Map<String, dynamic>?;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                const Text('Current Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                _statusChip(sub['status']?.toString() ?? 'active'),
              ],
            ),
            const SizedBox(height: 12),
            Text(plan?['name'] ?? 'Unknown', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${formatCurrency(plan?['price'] ?? 0)} / ${plan?['billing_period'] ?? ''}',
                style: const TextStyle(fontSize: 14)),
            if (sub['end_date'] != null) ...[
              const SizedBox(height: 4),
              Text('Valid till ${formatSubscriptionDate(sub['end_date'])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
            if (plan?['has_free_delivery'] == true || plan?['has_fast_support'] == true) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (plan?['has_free_delivery'] == true)
                    Chip(label: const Text('Free Delivery', style: TextStyle(fontSize: 11)), backgroundColor: Colors.green.shade50, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  if (plan?['has_fast_support'] == true)
                    Chip(label: const Text('Fast Support', style: TextStyle(fontSize: 11)), backgroundColor: Colors.amber.shade50, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()),
                ),
                icon: const Icon(Icons.workspace_premium, size: 18),
                label: const Text('View Upgrade Options'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if ((sub['status']?.toString() ?? 'active') == 'active') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCancelling ? null : () => _confirmCancel(sub),
                  icon: _isCancelling
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(_isCancelling ? 'Cancelling...' : 'Cancel Subscription'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final Color color;
    final Color bg;
    final String label;
    switch (status) {
      case 'cancelled':
        label = 'CANCELLED';
        color = Colors.red;
        bg = Colors.red.shade100;
        break;
      case 'expired':
        label = 'EXPIRED';
        color = Colors.amber.shade900;
        bg = Colors.amber.shade100;
        break;
      default:
        label = 'ACTIVE';
        color = Colors.green;
        bg = Colors.green.shade100;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Future<void> _confirmCancel(Map<String, dynamic> sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: const Text(
            'Your subscription benefits (free delivery, fast support, paid content) will end immediately. '
            'If you paid with wallet, the unused portion will be refunded to your wallet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Subscription'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    final provider = context.read<SubscriptionProvider>();
    final message = await provider.cancelSubscription(sub['id'] as int);
    if (!mounted) return;
    setState(() => _isCancelling = false);

    if (message != null) {
      await context.read<AuthProvider>().loadProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green.shade700),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'Could not cancel subscription. Please try again.')),
      );
    }
  }

  Widget _buildLastSubscriptionCard(Map<String, dynamic> sub) {
    final plan = sub['plan'] as Map<String, dynamic>?;
    final status = sub['status']?.toString() ?? 'expired';
    final isCancelled = status == 'cancelled';
    final cancelledAt = sub['cancelled_at']?.toString();
    final reason = sub['cancellation_reason']?.toString();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isCancelled ? Icons.cancel : Icons.timer_off,
                    color: isCancelled ? Colors.red : Colors.amber.shade800),
                const SizedBox(width: 8),
                Text(isCancelled ? 'Subscription Cancelled' : 'Subscription Expired',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 8),
            Text('${plan?['name'] ?? 'Previous plan'}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (sub['end_date'] != null) ...[
              const SizedBox(height: 4),
              Text('Ended ${formatSubscriptionDate(sub['end_date'])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
            if (cancelledAt != null && cancelledAt.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Cancelled on ${formatSubscriptionDate(cancelledAt)}'
                  '${sub['cancelled_by'] == 'admin' ? ' (by admin)' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
            if (reason != null && reason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Reason: $reason',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPlan() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.workspace_premium_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text('No Active Subscription', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Subscribe to unlock premium content', style: TextStyle(color: Colors.grey.shade500)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()),
                ),
                icon: const Icon(Icons.workspace_premium),
                label: const Text('View Subscription Plans'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final PaidContent content;
  const _ContentCard({required this.content});

  @override
  Widget build(BuildContext context) {
    Color typeColor;
    switch (content.contentType) {
      case 'spray_schedule':
        typeColor = Colors.blue;
        break;
      case 'nutrition':
        typeColor = Colors.green;
        break;
      default:
        typeColor = Colors.purple;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => PaidContentDetailScreen(slug: content.slug),
          ));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  content.contentType == 'spray_schedule'
                      ? Icons.science
                      : content.contentType == 'nutrition'
                          ? Icons.eco
                          : Icons.menu_book,
                  color: typeColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(content.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (content.summary != null)
                      Text(content.summary!, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
