import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/auth_provider.dart';
import '../models/subscription_plan.dart';
import '../services/api_service.dart';
import '../services/razorpay_helper.dart';
import '../services/razorpay_factory.dart';
import '../utils/formatters.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  late final RazorpayHelper _razorpay;
  bool _processingPayment = false;

  @override
  void initState() {
    super.initState();
    _razorpay = createRazorpay();
    _razorpay.on('payment.success', _handlePaymentSuccess);
    _razorpay.on('payment.error', _handlePaymentError);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().loadPlans();
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(dynamic response) {
    final pid = response['razorpay_payment_id'] as String?;
    final oid = response['razorpay_order_id'] as String?;
    final sig = response['razorpay_signature'] as String?;
    if (pid == null || oid == null || sig == null) return;

    _verifyPayment(oid, pid, sig);
  }

  void _handlePaymentError(dynamic error) {
    if (!mounted) return;
    setState(() => _processingPayment = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${error is Map ? error['reason'] ?? 'Unknown error' : error}'),
          backgroundColor: Colors.red),
    );
  }

  Future<void> _verifyPayment(String oid, String pid, String sig) async {
    try {
      final res = await ApiService.post('/subscriptions/razorpay/verify', body: {
        'razorpay_order_id': oid,
        'razorpay_payment_id': pid,
        'razorpay_signature': sig,
      });
      final data = res is Map ? Map<String, dynamic>.from(res) : await res as Map<String, dynamic>;
      if (!mounted) return;
      if (data['success'] == true) {
        await context.read<SubscriptionProvider>().loadMySubscription();
        await context.read<AuthProvider>().loadProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscribed successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        setState(() => _processingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Verification failed'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification error. Please contact support.'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _onSubscribe(SubscriptionPlan plan) async {
    String confirmMessage;
    if (plan.isUpgrade && plan.proration != null) {
      confirmMessage = 'Upgrade to ${plan.name}?\n\n'
          'Original: ${formatCurrency(plan.proration!.originalPrice)}\n'
          'Credit: −${formatCurrency(plan.proration!.credit)} (${plan.proration!.remainingDays} days remaining)\n'
          'You pay: ${formatCurrency(plan.proration!.finalPrice)}';
    } else {
      confirmMessage = 'Subscribe to ${plan.name} for ${formatCurrency(plan.price)}/${plan.billingPeriod}?';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(plan.isUpgrade ? 'Confirm Upgrade' : 'Confirm Subscription'),
        content: Text(confirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(plan.isUpgrade ? 'Upgrade' : 'Subscribe'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final paymentMethod = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Choose Payment Method'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'razorpay'),
            child: const Text('Razorpay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'wallet'),
            child: const Text('Pay with Wallet'),
          ),
        ],
      ),
    );
    if (paymentMethod == null || !context.mounted) return;

    if (paymentMethod == 'wallet') {
      final provider = context.read<SubscriptionProvider>();
      final success = await provider.subscribe(plan.id, paymentMethod: paymentMethod);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Subscribed successfully!' : provider.errorMessage ?? 'Subscription couldn\'t be completed.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) {
        await context.read<AuthProvider>().loadProfile();
        Navigator.pop(context);
      }
      return;
    }

    setState(() => _processingPayment = true);

    try {
      final data = await ApiService.post('/subscriptions/razorpay/create', body: {
        'plan_id': plan.id,
      }) as Map<String, dynamic>;

      if (data['success'] != true || data['data'] == null) {
        if (!mounted) return;
        setState(() => _processingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to create payment order'),
              backgroundColor: Colors.red),
        );
        return;
      }

      final order = Map<String, dynamic>.from(data['data']);
      if (!mounted) return;
      _razorpay.open({
        'key': order['key'] ?? '',
        'order_id': order['razorpay_order_id'],
        'amount': (order['amount'] as num).toInt(),
        'currency': 'INR',
        'name': 'Magray Orchards',
        'description': 'Subscription: ${plan.name}',
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingPayment = false);
      final msg = e is ApiException ? e.message : 'Could not initiate payment. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Plans'),
      ),
      body: _processingPayment
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Processing payment...'),
                ],
              ),
            )
          : Consumer<SubscriptionProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null && provider.plans.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                          const SizedBox(height: 16),
                          Text(provider.errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () { provider.clearError(); provider.loadPlans(); },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: provider.plans.length,
                      itemBuilder: (context, index) {
                        return _PlanCard(plan: provider.plans[index], onSubscribe: _onSubscribe);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final void Function(SubscriptionPlan) onSubscribe;
  const _PlanCard({required this.plan, required this.onSubscribe});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: plan.isCurrentPlan
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top badges row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: plan.tier >= 3
                        ? Colors.purple.shade50
                        : plan.tier >= 2
                            ? Colors.blue.shade50
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Tier ${plan.tier}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: plan.tier >= 3
                          ? Colors.purple.shade700
                          : plan.tier >= 2
                              ? Colors.blue.shade700
                              : Colors.grey.shade700,
                    ),
                  ),
                ),
                if (plan.isCurrentPlan) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'CURRENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
                if (plan.isUpgrade) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'UPGRADE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
                if (plan.isDowngradeBlocked) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'HIGHER PLAN ACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (plan.hasFreeDelivery)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('FREE DELIVERY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.green)),
                  ),
                if (plan.hasFastSupport)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('FAST SUPPORT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.amber)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(plan.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (plan.description != null && plan.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(plan.description!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ),
            const SizedBox(height: 12),

            // Pricing
            if (plan.isUpgrade && plan.proration != null) ...[
              // Strikethrough original price
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(plan.proration!.originalPrice),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade400,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, left: 4),
                    child: Text('/ ${plan.billingPeriod}', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Prorated price
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(plan.proration!.finalPrice),
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green.shade600),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text('/ ${plan.billingPeriod}', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  ),
                ],
              ),
              // Credit breakdown
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.savings_outlined, size: 16, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Credit: ${formatCurrency(plan.proration!.credit)} (${plan.proration!.remainingDays} days remaining on ${plan.proration!.currentPlanName})',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatCurrency(plan.price), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text('/ ${plan.billingPeriod}', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  ),
                ],
              ),
            ],

            // Features
            if (plan.features != null && plan.features!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...plan.features!.take(5).map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green.shade500),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              )),
            ],
            const SizedBox(height: 16),

            // Action button
            if (plan.isCurrentPlan)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Text('Current Plan', style: TextStyle(color: Colors.grey.shade400)),
                ),
              )
            else if (plan.isDowngradeBlocked)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Text(plan.subscriptionReason ?? 'Cannot Downgrade',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ),
              )
            else if (plan.isUpgrade)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => onSubscribe(plan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Upgrade — ${formatCurrency(plan.proration!.finalPrice)}'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => onSubscribe(plan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Subscribe — ${formatCurrency(plan.price)}/${plan.billingPeriod}'),
                ),
              ),
          ],
        ),
      ),
    );
  }}
