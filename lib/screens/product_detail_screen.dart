import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../models/product.dart';
import '../models/product_variant.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../providers/wishlist_provider.dart';
import '../services/api_service.dart';
import '../widgets/star_rating.dart';
import '../widgets/review_card.dart';
import '../widgets/write_review_form.dart';
import 'product_image_gallery.dart';
import 'category_products_screen.dart';
import 'checkout_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  ProductVariant? _selectedVariant;
  int _selectedImageIndex = 0;
  int _selectedTab = 0;
  final _pincodeController = TextEditingController();
  Map<String, dynamic>? _pincodeResult;
  bool _pincodeLoading = false;
  bool _usingDefaultPincode = false;
  Product? _product;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _loadProductDetail();
    _maybeAutoCheckDefaultAddress();
  }

  void _maybeAutoCheckDefaultAddress() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (!auth.isLoggedIn) return;

      var pin = auth.user?.defaultPincode;
      if (pin == null) {
        // Profile may not carry the default address yet — refresh it once.
        await auth.loadProfile();
        if (!mounted) return;
        pin = auth.user?.defaultPincode;
      }

      final defaultPin = pin;
      if (defaultPin != null && defaultPin.length == 6) {
        setState(() {
          _usingDefaultPincode = true;
          _pincodeController.text = defaultPin;
        });
        _checkPincode();
      }
    });
  }

  @override
  void dispose() {
    _pincodeController.dispose();
    super.dispose();
  }

  Product get _p => _product ?? widget.product;

  double get _currentPrice => _selectedVariant?.price ?? _p.price;
  double? get _currentComparePrice => _selectedVariant?.comparePrice ?? _p.comparePrice;
  int get _currentStock => _selectedVariant?.stockQuantity ?? _p.stockQuantity;
  bool get _inStock => _currentStock > 0;
  int get _discountPercent {
    if (_currentComparePrice == null || _currentComparePrice! <= 0) return 0;
    return ((_currentComparePrice! - _currentPrice) / _currentComparePrice! * 100).round();
  }

  String _imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.imageBaseUrl}$path';
  }

  Future<void> _loadProductDetail() async {
    try {
      final provider = context.read<ProductProvider>();
      final detail = await provider.fetchProductDetail(_p.slug);
      if (detail != null && mounted) {
        setState(() { _product = detail; });
      }
    } catch (_) {}
  }

  Future<void> _checkPincode() async {
    final pin = _pincodeController.text.trim();
    if (pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 6-digit pincode'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() { _pincodeLoading = true; _pincodeResult = null; });
    try {
      final response = await ApiService.get('/pincodes/$pin/check?product_id=${_p.id}');
      setState(() { _pincodeResult = response['data'] ?? response; });
    } catch (e) {
      setState(() { _pincodeResult = {'is_serviceable': false, 'message': 'Unable to check delivery'}; });
    }
    if (mounted) setState(() => _pincodeLoading = false);
  }

  String _courierName(String slug) => switch (slug) {
        'delhivery' => 'Delhivery',
        'shiprocket' => 'Shiprocket',
        'local' => 'Local',
        _ => slug,
      };

  void _addToCart() {
    final cart = context.read<CartProvider>();
    cart.addItem(_p, quantity: _quantity);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Added to cart'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        action: SnackBarAction(label: 'VIEW CART', textColor: Colors.white, onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
        }),
      ),
    );
  }

  void _buyNow() {
    final cart = context.read<CartProvider>();
    cart.clearCart();
    cart.addItem(_p, quantity: _quantity);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartProvider>();

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 0,
                pinned: true,
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                title: Text(_p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
                actions: [
                  if (context.read<AuthProvider>().isLoggedIn)
                    IconButton(
                      icon: Icon(
                        context.read<WishlistProvider>().isInWishlist(_p.id) ? Icons.favorite : Icons.favorite_border,
                        color: context.read<WishlistProvider>().isInWishlist(_p.id) ? Colors.white : Colors.white,
                      ),
                      onPressed: () {
                        context.read<WishlistProvider>().toggleWishlist(_p.id);
                      },
                    ),
                ],
              ),
              if (isWide)
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Gallery (left, constrained width)
                            Expanded(
                              child: ProductImageGallery(
                                imageUrls: _p.allImageUrls.map((e) => _imageUrl(e)).toList(),
                                initialIndex: _selectedImageIndex,
                              ),
                            ),
                            const SizedBox(width: 32),
                            // Details (right)
                            Expanded(child: _buildDetails(theme)),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProductImageGallery(
                        imageUrls: _p.allImageUrls.map((e) => _imageUrl(e)).toList(),
                        initialIndex: _selectedImageIndex,
                      ),
                      _buildDetails(theme),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildMobileBottomBar(theme, cart),
    );
  }

  Widget _buildDetails(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_p.brand != null && _p.brand!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _p.brand!.toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1.2),
              ),
            ),
          Text(_p.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (_p.categoryName != null && _p.categoryId != null)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryProductsScreen(
                    categoryId: _p.categoryId!,
                    categoryName: _p.categoryName!,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_p.categoryName!, style: TextStyle(color: theme.colorScheme.primary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.primary),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (_p.reviews.isNotEmpty)
            Row(
              children: [
                StarRating(rating: _p.reviews.fold(0, (s, r) => s + r.rating) ~/ (_p.reviews.length), size: 18),
                const SizedBox(width: 6),
                Text('(${_p.reviews.length} reviews)', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ],
            ),
          const SizedBox(height: 12),
          if (_p.composition != null && _p.composition!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.science, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text('Composition', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_p.composition!, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14)),
                ],
              ),
            ),
          _buildPriceRow(theme),
          if (_p.variants.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildVariantSelector(theme),
          ],
          const SizedBox(height: 12),
          _buildStockStatus(theme),
          const SizedBox(height: 16),
          if (_p.shortDescription != null && _p.shortDescription!.isNotEmpty)
            Text(_p.shortDescription!, style: TextStyle(color: Colors.grey.shade700, fontSize: 15, height: 1.5)),
          const SizedBox(height: 20),
          _buildPincodeCheck(theme),
          const SizedBox(height: 20),
          _buildTabs(theme),
        ],
      ),
    );
  }

  Widget _buildPriceRow(ThemeData theme) {
    final gold = Theme.of(context).colorScheme.secondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('Rs. ${_currentPrice.toStringAsFixed(0)}', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
        if (_currentComparePrice != null && _currentComparePrice! > _currentPrice) ...[
          const SizedBox(width: 10),
          Text('Rs. ${_currentComparePrice!.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, color: Colors.grey.shade500, decoration: TextDecoration.lineThrough)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(6)),
            child: Text('$_discountPercent% OFF', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ],
    );
  }

  Widget _buildVariantSelector(ThemeData theme) {
    final gold = Theme.of(context).colorScheme.secondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Size', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _p.variants.map((v) {
            final selected = _selectedVariant?.id == v.id;
            final discount = v.discountPercent;
            return GestureDetector(
              onTap: () => setState(() { _selectedVariant = v; _quantity = 1; }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? gold : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? gold : Colors.grey.shade300,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(v.name, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? Colors.white : Colors.black87, fontSize: 14)),
                    if (discount > 0)
                      Text('$discount% off', style: TextStyle(fontSize: 11, color: selected ? Colors.white : Colors.green.shade600, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStockStatus(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: _inStock ? Colors.green : Colors.red, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          _inStock ? 'In Stock ($_currentStock available)' : 'Out of Stock',
          style: TextStyle(color: _inStock ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildPincodeCheck(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delivery Information', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 10),
          if (_usingDefaultPincode)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Delivering to ${_pincodeController.text}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _usingDefaultPincode = false;
                      _pincodeResult = null;
                    }),
                    child: Text(
                      'Change',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!_usingDefaultPincode)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: 'Enter pincode',
                      counterText: '',
                      prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _pincodeLoading ? null : _checkPincode,
                  child: _pincodeLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Check'),
                ),
              ),
            ],
          ),
          if (_pincodeResult != null) ...[
            const SizedBox(height: 12),
            if (_pincodeResult!['is_serviceable'] == true)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
                      const SizedBox(width: 6),
                      Text('Delivery Available', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                    ]),
                    if (_pincodeResult!['city'] != null)
                      Text('${_pincodeResult!['city']}, ${_pincodeResult!['state'] ?? ''}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      _pincodeResult!['delivery_charge'] == '0.00' || _pincodeResult!['delivery_charge'] == 0
                          ? 'Free Delivery'
                          : 'Delivery Charge: Rs. ${_pincodeResult!['delivery_charge']}',
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w500),
                    ),
                    if (_pincodeResult!['courier'] != null)
                      Text('via ${_courierName(_pincodeResult!['courier'])}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    if (_pincodeResult!['free_delivery'] == true)
                      Text('Free delivery applied on this order!', style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
                    if (_pincodeResult!['estimated_days'] != null)
                      Text('Estimated ${_pincodeResult!['estimated_days']} days', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                child: Row(children: [
                  Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_pincodeResult!['message'] ?? 'Not serviceable', style: TextStyle(color: Colors.red.shade700))),
                ]),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabs(ThemeData theme) {
    final tabs = ['Description'];
    if (_p.dosage != null && _p.dosage!.isNotEmpty) tabs.add('Dosage & Usage');
    tabs.add('Reviews (${_p.reviews.length})');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final active = _selectedTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : null,
                    ),
                    child: Text(
                      tabs[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: active ? FontWeight.bold : FontWeight.w500, fontSize: 13, color: active ? theme.colorScheme.primary : Colors.grey.shade600),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedTab == 0) _buildDescriptionTab(theme),
        if (_selectedTab == 1 && _p.dosage != null && _p.dosage!.isNotEmpty) _buildDosageTab(theme),
        if (_selectedTab == tabs.length - 1) _buildReviewsTab(theme),
      ],
    );
  }

  Widget _buildDescriptionTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_p.description != null && _p.description!.isNotEmpty)
          Text(_p.description!, style: TextStyle(color: Colors.grey.shade700, height: 1.6, fontSize: 15)),
        const SizedBox(height: 16),
        if (_p.sku != null || _p.classification != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Product Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                if (_p.brand != null) _detailRow('Brand', _p.brand!),
                if (_p.classification != null) _detailRow('Classification', _p.classification!),
                if (_p.sku != null) _detailRow('SKU', _p.sku!),
              ],
            ),
          ),
        if (_p.recommendedCrops != null && _p.recommendedCrops!.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Recommended Crops', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _p.recommendedCrops!.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).map((crop) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade200)),
                child: Text(crop, style: TextStyle(color: Colors.green.shade700, fontSize: 13, fontWeight: FontWeight.w500)),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildDosageTab(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science, color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 8),
              Text('Dosage & Usage', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_p.dosage!, style: TextStyle(color: Colors.amber.shade900, height: 1.6, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildReviewsTab(ThemeData theme) {
    final auth = context.watch<AuthProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (auth.isLoggedIn) ...[
          WriteReviewForm(productId: _p.id, onSubmitted: _loadProductDetail),
          const SizedBox(height: 20),
        ],
        if (_p.reviews.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No reviews yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Be the first to review this product', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          ..._p.reviews.map((r) => ReviewCard(review: r)),
      ],
    );
  }

  Widget _buildMobileBottomBar(ThemeData theme, CartProvider cart) {
    if (!_inStock) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  visualDensity: VisualDensity.compact,
                ),
                Text('$_quantity', style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: _quantity < _currentStock ? () => setState(() => _quantity++) : null,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _buyNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Buy Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
