import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/address_provider.dart';
import '../providers/order_provider.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/razorpay_factory.dart';
import '../services/razorpay_helper.dart';
import '../services/shop_config.dart';
import '../services/sound_service.dart';
import '../providers/wallet_provider.dart';
import '../utils/app_navigation.dart';
import '../utils/formatters.dart';
import '../widgets/app_network_image.dart';
import '../widgets/empty_state.dart';
import 'home_screen.dart';
import 'address_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItem>? expressItems;

  const CheckoutScreen({super.key, this.expressItems});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _couponController = TextEditingController();
  late final RazorpayHelper _razorpay;
  int? _selectedAddressId;
  String _paymentMethod = 'cod';
  String? _couponCode;
  double _couponDiscount = 0;
  bool _couponApplied = false;
  bool _couponLoading = false;
  bool _placingOrder = false;
  double? _apiShipping;
  bool _freeDelivery = false;
  bool _shippingLoading = false;
  bool? _serviceable;
  String? _shippingMessage;
  int? _estimatedDays;
  double _walletBalance = 0;

  bool get _isExpress =>
      widget.expressItems != null && widget.expressItems!.isNotEmpty;

  List<CartItem> _activeItems(CartProvider cart) =>
      _isExpress ? widget.expressItems! : cart.items;

  List<Map<String, dynamic>> _orderItemsPayload(CartProvider cart) =>
      CartProvider.itemsToOrderPayload(_activeItems(cart));

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _razorpay = createRazorpay();
    _razorpay.on('payment.success', _handlePaymentSuccess);
    _razorpay.on('payment.error', _handlePaymentError);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final addressProvider = context.read<AddressProvider>();
      addressProvider.fetchAddresses().then((_) {
        if (!mounted) return;
        final selected = addressProvider.selectedAddress;
        if (selected != null) {
          setState(() => _selectedAddressId = selected.id);
          _fetchShippingForPincode(selected.pincode);
        }
      });
      final walletProvider = context.read<WalletProvider>();
      walletProvider.fetchBalance().then((_) {
        if (mounted) setState(() => _walletBalance = walletProvider.balance);
      });
    });
  }

  @override
  void dispose() {
    _couponController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  double _getSubtotal(CartProvider cart) {
    return _activeItems(cart).fold(
      0.0,
      (sum, item) => sum + item.unitPrice * item.quantity,
    );
  }

  double _getTax(double subtotal) {
    return ShopConfig.calculateTax(subtotal);
  }

  double _getShipping(AddressProvider addressProvider) {
    if (_freeDelivery) return 0;
    if (_apiShipping != null) return _apiShipping!;
    return _getLocalShipping(addressProvider);
  }

  double _getLocalShipping(AddressProvider addressProvider) {
    if (addressProvider.selectedAddress != null) {
      final pin = addressProvider.selectedAddress!.pincode;
      if (pin.isNotEmpty) {
        final pinNum = int.tryParse(pin);
        if (pinNum != null) {
          if (pinNum >= 100000 && pinNum <= 199999) return 50;
          if (pinNum >= 200000 && pinNum <= 299999) return 40;
          if (pinNum >= 300000 && pinNum <= 399999) return 55;
          if (pinNum >= 400000 && pinNum <= 499999) return 60;
          if (pinNum >= 500000 && pinNum <= 599999) return 35;
          if (pinNum >= 600000 && pinNum <= 699999) return 45;
          if (pinNum >= 700000 && pinNum <= 799999) return 50;
          if (pinNum >= 800000 && pinNum <= 899999) return 65;
          if (pinNum >= 900000 && pinNum <= 999999) return 70;
        }
      }
    }
    return 50;
  }

  Future<void> _fetchShippingForPincode(String pincode) async {
    if (pincode.isEmpty) return;
    setState(() {
      _shippingLoading = true;
      _serviceable = null;
      _shippingMessage = null;
    });
    try {
      final cart = context.read<CartProvider>();
      final response = await ApiService.post('/shipping-rate', body: {
        'pincode': pincode,
        'items': _orderItemsPayload(cart),
        'subtotal': _getSubtotal(cart),
      });
      final data = response['data'] ?? response;
      setState(() {
        _apiShipping = _toDouble(data['delivery_charge'] ?? 50);
        _freeDelivery = data['free_delivery'] == true;
        _serviceable = data['serviceable'] as bool?;
        _shippingMessage = data['message']?.toString();
        final days = data['estimated_days'];
        _estimatedDays = days is num ? days.toInt() : (days is String ? int.tryParse(days) : null);
      });
    } catch (_) {
      setState(() {
        _apiShipping = null;
        _freeDelivery = false;
        _serviceable = null;
        _shippingMessage = null;
        _estimatedDays = null;
      });
    } finally {
      if (mounted) setState(() => _shippingLoading = false);
    }
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a coupon code'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _couponLoading = true);
    try {
      final cart = context.read<CartProvider>();
      final response = await ApiService.post('/coupons/validate', body: {
        'code': code,
        'subtotal': _getSubtotal(cart),
      });
      final data = response['data'] ?? response;
      setState(() {
        _couponCode = code;
        _couponDiscount = _toDouble(data['discount']);
        _couponApplied = true;
      });
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Coupon applied! You save Rs. ${_couponDiscount.toStringAsFixed(0)}'),
            backgroundColor: cs.primary,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _couponCode = null;
        _couponDiscount = 0;
        _couponApplied = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${e is ApiException ? e.message : 'This coupon code is not valid.'}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _couponLoading = false);
    }
  }

  void _removeCoupon() {
    setState(() {
      _couponCode = null;
      _couponDiscount = 0;
      _couponApplied = false;
      _couponController.clear();
    });
  }

  Future<void> _placeOrder() async {
    final auth = context.read<AuthProvider>();
    final cart = context.read<CartProvider>();
    final addressProvider = context.read<AddressProvider>();
    final orderProvider = context.read<OrderProvider>();

    if (addressProvider.selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_activeItems(cart).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty'), backgroundColor: Colors.orange),
      );
      return;
    }

    final total = _calculateTotal(cart, addressProvider);
    final maxOrderAmount = ShopConfig.maxOrderAmount;
    if (maxOrderAmount > 0 && total > maxOrderAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This order exceeds the maximum order amount of ${formatCurrency(maxOrderAmount, alwaysShowDecimals: true)}. Please reduce the items in your cart.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _placingOrder = true);

    try {
      if (_paymentMethod == 'cod') {
        await _placeCodOrder(auth, cart, addressProvider, orderProvider);
      } else if (_paymentMethod == 'wallet') {
        await _placeWalletOrder(auth, cart, addressProvider, orderProvider);
      } else {
        await _placeRazorpayOrder(auth, cart, addressProvider, orderProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'We couldn\'t place your order. Please try again.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  Future<void> _placeCodOrder(
    AuthProvider auth,
    CartProvider cart,
    AddressProvider addressProvider,
    OrderProvider orderProvider,
  ) async {
    final order = await orderProvider.createOrder(
      addressId: addressProvider.selectedAddress!.id,
      paymentMethod: 'cod',
      items: _orderItemsPayload(cart),
      couponCode: _couponCode,
      notes: _couponCode != null ? 'Coupon: $_couponCode' : null,
    );
    if (!_isExpress) await cart.clearCart();
    if (mounted) {
      _showSuccessDialog(
        'Order Placed Successfully!',
        'Your order has been placed. Pay via Cash on Delivery.',
        orderNumber: order?.orderNumber,
      );
    }
  }

  Future<void> _placeRazorpayOrder(
    AuthProvider auth,
    CartProvider cart,
    AddressProvider addressProvider,
    OrderProvider orderProvider,
  ) async {
    final order = await orderProvider.createOrder(
      addressId: addressProvider.selectedAddress!.id,
      paymentMethod: 'razorpay',
      items: _orderItemsPayload(cart),
      couponCode: _couponCode,
      notes: _couponCode != null ? 'Coupon: $_couponCode' : null,
    );
    if (order == null) throw Exception('Failed to create order');

    try {
      final response = await ApiService.post('/payment/razorpay/create', body: {
        'order_id': order.id,
        'amount': order.totalAmount,
      });
      final data = response['data'] ?? response;
      final razorpayKeyId = data['key'] ?? '';
      final razorpayOrderId = data['razorpay_order_id'] ?? data['order_id'] ?? '';
      final amount = (data['amount'] ?? 0);
      final userName = auth.user?.name ?? 'Customer';
      final userEmail = auth.user?.email ?? '';
      final userPhone = auth.user?.phone ?? '';

      final razorpayAmount = (amount is num) ? (amount * 100).toInt() : 0;
      var options = {
        'key': razorpayKeyId,
        'amount': razorpayAmount,
        'name': 'Magray Orchards',
        'order_id': razorpayOrderId,
        'description': 'Order ${order.orderNumber}',
        'prefill': {
          'contact': userPhone,
          'email': userEmail,
          'name': userName,
        },
      };
      _razorpay.open(options);
    } catch (e) {
      throw Exception('Failed to initiate payment: ${e.toString()}');
    }
  }

  Future<void> _placeWalletOrder(
    AuthProvider auth,
    CartProvider cart,
    AddressProvider addressProvider,
    OrderProvider orderProvider,
  ) async {
    final total = _calculateTotal(cart, addressProvider);
    final walletBalance = context.read<WalletProvider>().balance;

    if (walletBalance >= total) {
      // Full wallet payment
      final order = await orderProvider.createOrder(
        addressId: addressProvider.selectedAddress!.id,
        paymentMethod: 'wallet',
        items: _orderItemsPayload(cart),
        couponCode: _couponCode,
        notes: _couponCode != null ? 'Coupon: $_couponCode' : null,
        walletAmountUsed: total,
      );
      if (!_isExpress) await cart.clearCart();
      if (!mounted) return;
      await context.read<WalletProvider>().fetchBalance();
      if (mounted) {
        _showSuccessDialog(
          'Order Placed Successfully!',
          '${formatCurrency(total)} paid from wallet.',
          orderNumber: order?.orderNumber,
        );
      }
    } else {
      // Partial wallet + Razorpay
      final remaining = total - walletBalance;
      final order = await orderProvider.createOrder(
        addressId: addressProvider.selectedAddress!.id,
        paymentMethod: 'partial_wallet',
        items: _orderItemsPayload(cart),
        couponCode: _couponCode,
        notes: _couponCode != null ? 'Coupon: $_couponCode' : null,
        walletAmountUsed: walletBalance,
      );
      if (order == null) throw Exception('Failed to create order');

      try {
        final response = await ApiService.post('/payment/razorpay/create', body: {
          'order_id': order.id,
          'amount': remaining,
        });
        final data = response['data'] ?? response;
        final razorpayKeyId = data['key'] ?? '';
        final razorpayOrderId = data['razorpay_order_id'] ?? data['order_id'] ?? '';
        final userName = auth.user?.name ?? 'Customer';
        final userEmail = auth.user?.email ?? '';
        final userPhone = auth.user?.phone ?? '';

        var options = {
          'key': razorpayKeyId,
          'amount': (remaining * 100).toInt(),
          'name': 'Magray Orchards',
          'order_id': razorpayOrderId,
          'description': 'Order ${order.orderNumber} (${formatCurrency(walletBalance)} from wallet)',
          'prefill': {
            'contact': userPhone,
            'email': userEmail,
            'name': userName,
          },
        };
        _razorpay.open(options);
      } catch (e) {
        throw Exception('Failed to initiate remaining payment: ${e.toString()}');
      }
    }
  }

  double _calculateTotal(CartProvider cart, AddressProvider addressProvider) {
    final subtotal = _getSubtotal(cart);
    final tax = _getTax(subtotal);
    final shipping = _getShipping(addressProvider);
    return subtotal + tax + shipping - _couponDiscount;
  }

  void _handlePaymentSuccess(dynamic response) async {
    // IdentityMap uses identical() — convert to regular map for safe key lookup
    final data = Map<String, String>.from(response as Map);
    final oid = data['razorpay_order_id'] ?? '';
    final pid = data['razorpay_payment_id'] ?? '';
    final sig = data['razorpay_signature'] ?? '';
    try {
      await ApiService.post('/payment/razorpay/verify', body: {
        'razorpay_order_id': oid,
        'razorpay_payment_id': pid,
        'razorpay_signature': sig,
      });
      if (mounted) {
        if (!_isExpress) await context.read<CartProvider>().clearCart();
        if (!mounted) return;
        final orderNum = context.read<OrderProvider>().lastCreatedOrder?.orderNumber;
        _showSuccessDialog(
          'Payment Successful!',
          'Your order has been placed and payment received.',
          orderNumber: orderNum,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Payment could not be verified. Please check your order status.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handlePaymentError(dynamic response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${response is Map ? (response['message'] ?? 'Something went wrong with the payment. Please try again.') : (response.message ?? 'Something went wrong with the payment. Please try again.')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessDialog(String title, String message, {String? orderNumber}) {
    final cs = Theme.of(context).colorScheme;
    SoundService.playOrderSuccess();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.check_circle, color: cs.primary, size: 64),
        title: Text(title, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (orderNumber != null && orderNumber.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Order $orderNumber',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.primary),
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continue Shopping', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final addressProvider = context.watch<AddressProvider>();
    final cs = Theme.of(context).colorScheme;
    final activeItems = _activeItems(cart);
    final subtotal = _getSubtotal(cart);
    final tax = _getTax(subtotal);
    final shipping = _getShipping(addressProvider);
    final total = subtotal + tax + shipping - _couponDiscount;
    final hasAddress = addressProvider.selectedAddress != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isExpress ? 'Express Checkout' : 'Checkout'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: activeItems.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Add farming supplies before heading to checkout',
              actionLabel: 'Browse Products',
              actionIcon: Icons.storefront_outlined,
              onAction: () => AppNavigation.goToTab(context, 0),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStepProgressHeader(cs, hasAddress: hasAddress),
                      const SizedBox(height: 16),
                      _buildFreeShippingBanner(subtotal),
                      const SizedBox(height: 16),
                      _buildSectionTitle('Delivery Address'),
                      const SizedBox(height: 8),
                      _buildAddressSection(addressProvider),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Order Summary'),
                      const SizedBox(height: 8),
                      _buildOrderSummary(cart),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Coupon Code'),
                      const SizedBox(height: 8),
                      _buildCouponSection(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Price Details'),
                      const SizedBox(height: 8),
                      _buildPriceDetails(subtotal, tax, shipping, total),
                      if (ShopConfig.maxOrderAmount > 0 && total > ShopConfig.maxOrderAmount) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This order exceeds the maximum order amount of ${formatCurrency(ShopConfig.maxOrderAmount)}. Please reduce items to place this order.',
                                  style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _buildSectionTitle('Payment Method'),
                      const SizedBox(height: 8),
                      _buildPaymentMethod(total),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: activeItems.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _buildPlaceOrderButton(total),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStepProgressHeader(ColorScheme cs, {required bool hasAddress}) {
    final steps = [
      ('Address', true, hasAddress),
      ('Review', hasAddress, hasAddress),
      ('Pay', hasAddress, false),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: List.generate(steps.length, (i) {
            final (label, active, done) = steps[i];
            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: done
                          ? cs.primary
                          : active
                              ? cs.secondary
                              : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? cs.primary : Colors.grey,
                      ),
                    ),
                  ),
                  if (i < steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        color: done ? cs.primary : Colors.grey.shade300,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildFreeShippingBanner(double subtotal) {
    final cs = Theme.of(context).colorScheme;
    final threshold = ShopConfig.freeDeliveryThreshold;
    final remaining = threshold - subtotal;
    if (remaining <= 0) {
      return Card(
        color: cs.primary.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.local_shipping, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'You qualify for free shipping!',
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      color: Colors.orange.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.local_shipping_outlined, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Free shipping on orders above ${formatCurrency(threshold)}. Add ${formatCurrency(remaining)} more!',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: cs.primary,
      ),
    );
  }

  Widget _buildAddressSection(AddressProvider addressProvider) {
    final cs = Theme.of(context).colorScheme;
    if (addressProvider.isLoading) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(color: cs.primary)),
        ),
      );
    }

    if (addressProvider.addresses.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.location_off, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('No addresses found', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddressScreen()),
                ).then((_) => addressProvider.fetchAddresses()),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add Address', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        RadioGroup<int>(
          groupValue: _selectedAddressId,
          onChanged: (value) {
            if (value == null) return;
            final selected = addressProvider.addresses.firstWhere((a) => a.id == value);
            setState(() {
              _selectedAddressId = value;
              _apiShipping = null;
            });
            addressProvider.selectAddress(selected.id);
            _fetchShippingForPincode(selected.pincode);
          },
          child: Column(
            children: addressProvider.addresses.map((address) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: RadioListTile<int>(
                  value: address.id,
                  activeColor: cs.primary,
                  title: Text(address.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(address.fullAddress, maxLines: 2, overflow: TextOverflow.ellipsis),
                  secondary: address.isDefault
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Default', style: TextStyle(fontSize: 10, color: cs.primary, fontWeight: FontWeight.bold)),
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        if (_shippingLoading || _serviceable != null) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _shippingLoading
                  ? cs.primary.withValues(alpha: 0.06)
                  : (_serviceable == true
                      ? Colors.green.shade50
                      : Colors.orange.shade50),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _shippingLoading
                    ? cs.primary.withValues(alpha: 0.2)
                    : (_serviceable == true
                        ? Colors.green.shade200
                        : Colors.orange.shade200),
              ),
            ),
            child: Row(
              children: [
                if (_shippingLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                  )
                else
                  Icon(
                    _serviceable == true
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    size: 18,
                    color: _serviceable == true
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _shippingLoading
                        ? 'Checking delivery availability...'
                        : (_serviceable == true
                            ? (_estimatedDays != null
                                ? 'Delivery available • Est. $_estimatedDays day${_estimatedDays == 1 ? '' : 's'}'
                                : 'Delivery available to selected pincode')
                            : (_shippingMessage ?? 'Delivery may not be available for this pincode')),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: _shippingLoading
                          ? cs.primary
                          : (_serviceable == true
                              ? Colors.green.shade800
                              : Colors.orange.shade900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddressScreen()),
            ).then((_) => addressProvider.fetchAddresses()),
            icon: Icon(Icons.add, color: cs.primary),
            label: Text('Add New Address', style: TextStyle(color: cs.primary)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cs.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary(CartProvider cart) {
    final cs = Theme.of(context).colorScheme;
    final items = _activeItems(cart);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: item.product.image != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AppNetworkImage(
                                imageUrl:
                                    '${ApiConfig.imageBaseUrl}${item.product.image}',
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    Icon(Icons.eco, color: cs.primary, size: 22),
                              ),
                            )
                          : Icon(Icons.eco, color: cs.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.variant != null
                                ? '${item.product.name} (${item.variant!.name})'
                                : item.product.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Qty: ${item.quantity}',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatCurrency(item.unitPrice * item.quantity),
                      style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCouponSection() {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _couponApplied
            ? Row(
                children: [
                  Icon(Icons.local_offer, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _couponCode!,
                          style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        Text(
                          'Discount: Rs. ${_couponDiscount.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 13, color: cs.primary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _removeCoupon,
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _couponController,
                      decoration: InputDecoration(
                        hintText: 'Enter coupon code',
                        hintStyle: const TextStyle(fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _couponLoading ? null : _applyCoupon,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _couponLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Apply', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPriceDetails(double subtotal, double tax, double shipping, double total) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildPriceRow('Subtotal', formatCurrency(subtotal)),
            if (tax > 0) ...[
              const SizedBox(height: 8),
              _buildPriceRow('Tax (${ShopConfig.taxRate.toStringAsFixed(0)}%)', formatCurrency(tax)),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Shipping', style: TextStyle(color: Colors.grey)),
                _shippingLoading
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
                    : Text(
                        _freeDelivery ? 'Free' : formatCurrency(shipping),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _freeDelivery ? Colors.green : null,
                        ),
                      ),
              ],
            ),
            if (_estimatedDays != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estimated Delivery', style: TextStyle(color: Colors.grey)),
                  Text(
                    'In $_estimatedDays day${_estimatedDays == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            if (_couponApplied && _couponDiscount > 0) ...[
              const SizedBox(height: 8),
              _buildPriceRow('Coupon Discount', '- ${formatCurrency(_couponDiscount)}', isDiscount: true),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  formatCurrency(total),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDiscount ? Colors.green : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethod(double total) {
    final cs = Theme.of(context).colorScheme;
    final walletCanPayFull = _walletBalance >= total && total > 0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: RadioGroup<String>(
        groupValue: _paymentMethod,
        onChanged: (value) {
          if (value != null) setState(() => _paymentMethod = value);
        },
        child: Column(
          children: [
            if (_walletBalance > 0) ...[
              RadioListTile<String>(
                value: 'wallet',
                activeColor: cs.primary,
                title: const Text('Pay with Wallet'),
                subtitle: Text(
                  walletCanPayFull
                      ? 'Balance: ${formatCurrency(_walletBalance)} — covers full amount'
                      : 'Balance: ${formatCurrency(_walletBalance)} — ${formatCurrency(total - _walletBalance)} via Razorpay',
                ),
                secondary: Icon(Icons.account_balance_wallet, color: cs.primary),
              ),
              const Divider(height: 1),
            ],
            RadioListTile<String>(
              value: 'cod',
              activeColor: cs.primary,
              title: const Text('Cash on Delivery'),
              subtitle: const Text('Pay when your order arrives'),
              secondary: Icon(Icons.money, color: cs.primary),
            ),
            const Divider(height: 1),
            RadioListTile<String>(
              value: 'razorpay',
              activeColor: cs.primary,
              title: const Text('Pay with Razorpay'),
              subtitle: const Text('UPI, Cards, Net Banking & more'),
              secondary: Icon(Icons.credit_card, color: cs.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceOrderButton(double total) {
    final cs = Theme.of(context).colorScheme;
    String buttonText;
    switch (_paymentMethod) {
      case 'wallet':
        buttonText = _walletBalance >= total
            ? 'Pay ${formatCurrency(total)} from Wallet'
            : 'Pay ${formatCurrency(_walletBalance)} from Wallet + Razorpay';
        break;
      case 'cod':
        buttonText = 'Place Order - ${formatCurrency(total)}';
        break;
      default:
        buttonText = 'Pay Now - ${formatCurrency(total)}';
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _placingOrder ? null : _placeOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.secondary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _placingOrder
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                buttonText,
                style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
