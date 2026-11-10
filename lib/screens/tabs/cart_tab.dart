import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import '../../services/shop_config.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/empty_state.dart';
import '../login_screen.dart';
import '../product_search_screen.dart';

/// Shopping cart tab displayed from the root navigation shell.
class CartTab extends StatefulWidget {
  const CartTab({super.key});

  @override
  State<CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<CartTab> {
  final _pincodeController = TextEditingController();
  bool _usingDefaultPincode = false;
  bool _autoCheckStarted = false;
  bool _shippingLoading = false;
  Map<String, dynamic>? _shippingResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDefaultShipping());
  }

  Future<void> _initDefaultShipping() async {
    if (!mounted || _autoCheckStarted) return;
    final cart = context.read<CartProvider>();
    final authNow = context.read<AuthProvider>();
    if (cart.items.isEmpty || !authNow.isLoggedIn) return;
    _autoCheckStarted = true;

    var pin = authNow.user?.defaultPincode;
    if (pin == null) {
      await authNow.loadProfile();
      if (!mounted) return;
      pin = authNow.user?.defaultPincode;
    }

    if (pin != null && pin.length == 6 && !_usingDefaultPincode) {
      _pincodeController.text = pin;
      setState(() => _usingDefaultPincode = true);
      _fetchShipping(pin);
    }
  }

  @override
  void dispose() {
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchShipping(String pincode) async {
    if (pincode.length != 6) return;
    setState(() {
      _shippingLoading = true;
      _shippingResult = null;
    });
    try {
      final cart = context.read<CartProvider>();
      final data = await ApiService.fetchShippingRate(
        pincode: pincode,
        items: cart.toOrderItems(),
        subtotal: cart.total,
      );
      if (mounted) setState(() => _shippingResult = data);
    } catch (e) {
      if (mounted) {
        setState(
          () => _shippingResult = {
            'serviceable': false,
            'message': e is ApiException ? e.message : 'Could not check delivery',
          },
        );
      }
    }
    if (mounted) setState(() => _shippingLoading = false);
  }

  void _decrementOrRemove(CartProvider cart, CartItem item) {
    if (item.quantity > 1) {
      cart.updateQuantity(
        item.product.id,
        item.quantity - 1,
        variantId: item.variant?.id,
      );
      return;
    }

    final removedProduct = item.product;
    final removedVariant = item.variant;
    cart.updateQuantity(
      removedProduct.id,
      0,
      variantId: removedVariant?.id,
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed ${removedProduct.name} from cart'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.amberAccent,
            onPressed: () {
              cart.addItem(
                removedProduct,
                quantity: 1,
                variant: removedVariant,
              );
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final double freeDeliveryThreshold = ShopConfig.freeDeliveryThreshold;

    if (cart.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart')),
        body: EmptyState(
          icon: Icons.shopping_cart_outlined,
          title: 'Your cart is empty',
          message: 'Explore pesticides, nutrients, and tools for your orchard',
          actionLabel: 'Browse Products',
          actionIcon: Icons.storefront_outlined,
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductSearchScreen()),
          ),
        ),
      );
    }

    final subtotal = cart.total;
    final savings = cart.mrpSavings;
    final amountNeeded = freeDeliveryThreshold - subtotal;
    final freeShippingReached = amountNeeded <= 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Cart (${cart.itemCount})'),
        actions: [
          TextButton(
            onPressed: () => cart.clearCart(),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Clear All'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              // ── Free shipping progress ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: freeShippingReached
                            ? 1.0
                            : (subtotal / freeDeliveryThreshold).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        color: freeShippingReached ? Colors.green : primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (freeShippingReached)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "You've unlocked free delivery!",
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Add ${formatCurrency(amountNeeded)} more for free delivery!',
                        style: TextStyle(
                          color: primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),

              if (savings > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_offer_outlined,
                            size: 15, color: Colors.green.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'You are saving ${formatCurrency(savings)} on this order',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    final lineTotal = item.unitPrice * item.quantity;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.05),
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
                                            Icon(Icons.eco, color: primary),
                                      ),
                                    )
                                  : Icon(Icons.eco, color: primary),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        formatCurrency(lineTotal),
                                        style: TextStyle(
                                          color: primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (item.quantity > 1) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '(${formatCurrency(item.unitPrice)} each)',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: item.quantity > 1
                                      ? 'Decrease quantity'
                                      : 'Remove item',
                                  icon: Icon(
                                    item.quantity > 1
                                        ? Icons.remove_circle_outline
                                        : Icons.delete_outline,
                                    size: 22,
                                    color: item.quantity == 1 ? Colors.red.shade400 : null,
                                  ),
                                  onPressed: () => _decrementOrRemove(cart, item),
                                ),
                                Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Increase quantity',
                                  icon: Icon(
                                    Icons.add_circle_outline,
                                    size: 22,
                                    color: primary,
                                  ),
                                  onPressed: () => cart.updateQuantity(
                                    item.product.id,
                                    item.quantity + 1,
                                    variantId: item.variant?.id,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Total & Checkout ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_usingDefaultPincode)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Delivering to ${_pincodeController.text}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () => setState(() {
                                  _usingDefaultPincode = false;
                                  _shippingResult = null;
                                }),
                                child: Text(
                                  'Change',
                                  style: TextStyle(
                                    color: primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _pincodeController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  decoration: InputDecoration(
                                    hintText: 'Enter pincode',
                                    counterText: '',
                                    isDense: true,
                                    prefixIcon: const Icon(
                                      Icons.location_on_outlined,
                                      size: 18,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 40,
                                child: ElevatedButton(
                                  onPressed: _shippingLoading
                                      ? null
                                      : () => _fetchShipping(
                                            _pincodeController.text.trim(),
                                          ),
                                  child: _shippingLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Check'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_shippingResult != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Shipping',
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                              if (_shippingResult!['serviceable'] == true)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _shippingResult!['free_delivery'] == true
                                          ? 'Free'
                                          : formatCurrency(
                                              _shippingResult!['delivery_charge'] ?? 0,
                                            ),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _shippingResult!['free_delivery'] ==
                                                true
                                            ? Colors.green
                                            : null,
                                      ),
                                    ),
                                    if (_shippingResult!['estimated_days'] != null)
                                      Text(
                                        'Est. ${_shippingResult!['estimated_days']} days',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                )
                              else
                                Flexible(
                                  child: Text(
                                    _shippingResult!['message']?.toString() ??
                                        'Not serviceable',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            formatCurrency(cart.total),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            if (!auth.isLoggedIn) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Login to place order'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                              return;
                            }
                            Navigator.pushNamed(context, '/checkout');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            auth.isLoggedIn
                                ? 'Proceed to Checkout'
                                : 'Login to Checkout',
                            style: const TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
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
