import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../services/razorpay_factory.dart';
import '../services/razorpay_helper.dart';
import '../services/api_service.dart';

class WalletTopUpScreen extends StatefulWidget {
  const WalletTopUpScreen({super.key});

  @override
  State<WalletTopUpScreen> createState() => _WalletTopUpScreenState();
}

class _WalletTopUpScreenState extends State<WalletTopUpScreen> {
  final _amountController = TextEditingController();
  late final RazorpayHelper _razorpay;
  bool _isLoading = false;
  String? _razorpayOrderId;
  double _topUpAmount = 0;

  static const List<double> _presetAmounts = [100, 200, 500, 1000, 2000, 5000];

  @override
  void initState() {
    super.initState();
    _razorpay = createRazorpay();
    _razorpay.on('payment.success', _handlePaymentSuccess);
    _razorpay.on('payment.error', _handlePaymentError);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  double? _getAmount() {
    return double.tryParse(_amountController.text.trim());
  }

  Future<void> _initiateTopUp() async {
    final amount = _getAmount();
    if (amount == null || amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount (min ₹1)'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.post('/wallet/topup', body: {'amount': amount});
      final data = response['data'] ?? response;

      _topUpAmount = amount;
      _razorpayOrderId = data['razorpay_order_id'];

      final options = {
        'key': data['key'] ?? '',
        'amount': (amount * 100).toInt(),
        'name': 'Magray Orchards',
        'order_id': _razorpayOrderId,
        'description': 'Wallet Top-up',
      };

      _razorpay.open(options);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : 'Could not initiate payment. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _rzpVal(dynamic r, String key) {
    if (r is Map) return r['razorpay_${key}_id'] ?? r[key] ?? '';
    if (key == 'order_id') return r.orderId ?? '';
    if (key == 'payment_id') return r.paymentId ?? '';
    if (key == 'signature') return r.signature ?? '';
    return r[key] ?? '';
  }

  void _handlePaymentSuccess(dynamic response) async {
    setState(() => _isLoading = true);
    // IdentityMap uses identical() — convert to regular map for safe key lookup
    final data = Map<String, String>.from(response as Map);
    try {
      final wallet = context.read<WalletProvider>();
      final success = await wallet.verifyTopUp(
        razorpayOrderId: data['razorpay_order_id'] ?? '',
        razorpayPaymentId: data['razorpay_payment_id'] ?? '',
        razorpaySignature: data['razorpay_signature'] ?? '',
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('₹${_topUpAmount.toStringAsFixed(0)} added to your wallet!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment received but wallet update is pending. Please check your balance.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : 'Could not verify payment. Please check your balance.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handlePaymentError(dynamic response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${response is Map ? (response['message'] ?? 'Please try again.') : (response.message ?? 'Please try again.')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Money to Wallet'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Balance', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Text(
                      '₹${wallet.balance.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cs.primary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Select Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presetAmounts.map((amount) {
                final isSelected = _amountController.text == amount.toStringAsFixed(0);
                return GestureDetector(
                  onTap: () => setState(() => _amountController.text = amount.toStringAsFixed(0)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primary : cs.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? cs.primary : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '₹${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Custom Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _initiateTopUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Proceed to Pay',
                        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
