import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../models/product.dart';
import '../models/product_variant.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../providers/wishlist_provider.dart';
import '../providers/personalization_provider.dart';
import '../services/api_service.dart';
import '../utils/app_navigation.dart';
import '../utils/formatters.dart';
import '../widgets/review_card.dart';
import '../widgets/write_review_form.dart';
import 'product_image_gallery.dart';
import 'category_products_screen.dart';
import 'checkout_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product? product;
  final int? productId;
  final String? productSlug;

  const ProductDetailScreen({
    super.key,
    this.product,
    this.productId,
    this.productSlug,
  }) : assert(product != null || productId != null || productSlug != null,
            'At least one of product, productId, or productSlug must be provided.');

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  ProductVariant? _selectedVariant;
  final int _selectedImageIndex = 0;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_product != null) {
        context.read<PersonalizationProvider>().logProductView(_product!);
      }
    });
  }

  void _maybeAutoCheckDefaultAddress() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (!auth.isLoggedIn) return;

      var pin = auth.user?.defaultPincode;
      if (pin == null) {
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

  Product get _p => (_product ?? widget.product)!;

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
      final lookup = widget.productSlug ??
          widget.productId?.toString() ??
          (_product?.slug ?? widget.product?.slug);
      if (lookup == null || lookup.isEmpty) return;

      final provider = context.read<ProductProvider>();
      final detail = await provider.fetchProductDetail(lookup);
      if (detail != null && mounted) {
        setState(() {
          _product = detail;
        });
        context.read<PersonalizationProvider>().logProductView(detail);
      }
    } catch (_) {}
  }

  Future<void> _checkPincode() async {
    if (_product == null && widget.product == null) return;
    final pin = _pincodeController.text.trim();
    if (pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid 6-digit pincode'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _pincodeLoading = true;
      _pincodeResult = null;
    });
    try {
      final response = await ApiService.get('/pincodes/$pin/check?product_id=${_p.id}');
      setState(() {
        _pincodeResult = response['data'] ?? response;
      });
    } catch (e) {
      setState(() {
        _pincodeResult = {'is_serviceable': false, 'message': 'Unable to check delivery'};
      });
    }
    if (mounted) setState(() => _pincodeLoading = false);
  }

  String _courierName(String slug) => switch (slug) {
        'delhivery' => 'Delhivery Express',
        'shiprocket' => 'Shiprocket',
        'local' => 'Magray Express Dispatch',
        _ => slug,
      };

  void _addToCart() {
    final cart = context.read<CartProvider>();
    cart.addItem(_p, quantity: _quantity, variant: _selectedVariant);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedVariant != null
                    ? 'Added ${_p.name} (${_selectedVariant!.name}) to cart'
                    : 'Added ${_p.name} to cart',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'VIEW CART',
          textColor: Colors.white,
          onPressed: () => AppNavigation.openCart(context),
        ),
      ),
    );
  }

  Future<void> _buyNow() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please login to continue to checkout'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      Navigator.of(context).pushNamed('/login');
      return;
    }
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckoutScreen(
            expressItems: [
              CartItem(
                product: _p,
                quantity: _quantity,
                variant: _selectedVariant,
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_product == null && widget.product == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cartCount = context.watch<CartProvider>().itemCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 0,
                pinned: true,
                elevation: 0,
                scrolledUnderElevation: 1,
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                title: Text(
                  _p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                actions: [
                  // Wishlist Icon
                  Builder(builder: (context) {
                    final auth = context.watch<AuthProvider>();
                    final wishlist = context.watch<WishlistProvider>();
                    if (!auth.isLoggedIn) return const SizedBox.shrink();
                    final saved = wishlist.isInWishlist(_p.id);
                    return IconButton(
                      tooltip: saved ? 'Remove from Wishlist' : 'Save to Wishlist',
                      icon: Icon(
                        saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: saved ? Colors.redAccent.shade100 : Colors.white,
                      ),
                      onPressed: () async {
                        final nowSaved = await wishlist.toggleWishlist(_p.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                nowSaved ? 'Saved to wishlist' : 'Removed from wishlist',
                              ),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                      },
                    );
                  }),

                  // Cart Icon with Badge
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Shopping Cart',
                        icon: const Icon(Icons.shopping_bag_outlined),
                        onPressed: () => AppNavigation.openCart(context),
                      ),
                      if (cartCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '$cartCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
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
                            Expanded(
                              child: ProductImageGallery(
                                imageUrls: _p.allImageUrls.map((e) => _imageUrl(e)).toList(),
                                initialIndex: _selectedImageIndex,
                              ),
                            ),
                            const SizedBox(width: 32),
                            Expanded(child: _buildDetails(theme, cs)),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProductImageGallery(
                            imageUrls: _p.allImageUrls.map((e) => _imageUrl(e)).toList(),
                            initialIndex: _selectedImageIndex,
                          ),
                          _buildDetails(theme, cs),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildMobileBottomBar(theme, cs),
    );
  }

  Widget _buildDetails(ThemeData theme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Brand Tag & Category Breadcrumb
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_p.brand != null && _p.brand!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _p.brand!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade700,
                      letterSpacing: 1.1,
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),

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
                      Text(
                        _p.categoryName!,
                        style: TextStyle(
                          color: cs.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 16, color: cs.primary),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Product Title
          Text(
            _p.name,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              height: 1.3,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),

          // 3. Ratings (if present)
          if (_p.reviews.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 15, color: Color(0xFFD97706)),
                      const SizedBox(width: 3),
                      Text(
                        (_p.reviews.fold(0, (s, r) => s + r.rating) / _p.reviews.length).toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${_p.reviews.length} ${_p.reviews.length == 1 ? 'review' : 'reviews'})',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // 4. Price & Discount Block
          _buildPriceBlock(theme, cs),
          const SizedBox(height: 14),

          // 5. Stock Status
          _buildStockStatus(cs),
          const SizedBox(height: 16),

          // 6. Active Composition / Laboratory Formulation Card
          if (_p.composition != null && _p.composition!.isNotEmpty) ...[
            _buildCompositionCard(cs),
            const SizedBox(height: 16),
          ],

          // 7. Variant / Size Selector
          if (_p.variants.isNotEmpty) ...[
            _buildVariantSelector(cs),
            const SizedBox(height: 20),
          ],

          // 8. Delivery Information & Pincode Checker
          _buildPincodeCheck(theme, cs),
          const SizedBox(height: 20),

          // 9. Interactive Tabs: Description, Dosage, Reviews
          _buildTabs(theme, cs),
        ],
      ),
    );
  }

  Widget _buildPriceBlock(ThemeData theme, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                formatCurrency(_currentPrice),
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                  letterSpacing: -0.5,
                ),
              ),
              if (_currentComparePrice != null && _currentComparePrice! > _currentPrice) ...[
                Text(
                  formatCurrency(_currentComparePrice),
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade400,
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    '$_discountPercent% OFF',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Inclusive of all GST taxes · Eligible for free orchard delivery',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildStockStatus(ColorScheme cs) {
    if (!_inStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_rounded, size: 14, color: Color(0xFFDC2626)),
            SizedBox(width: 5),
            Text(
              'Currently Out of Stock',
              style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_currentStock <= 5) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFD97706)),
            const SizedBox(width: 4),
            Text(
              'Only $_currentStock left in stock - Order Soon!',
              style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
          const SizedBox(width: 5),
          Text(
            'In Stock ($_currentStock available)',
            style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCompositionCard(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.science_rounded, size: 16, color: cs.primary),
              ),
              const SizedBox(width: 8),
              const Text(
                'Active Composition & Formulation',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _p.composition!,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF334155),
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantSelector(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Pack Size / Variant',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _p.variants.map((v) {
            final selected = _selectedVariant?.id == v.id;
            final discount = v.discountPercent;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedVariant = v;
                _quantity = 1;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? cs.primary.withValues(alpha: 0.06) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? cs.primary : const Color(0xFFCBD5E1),
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          v.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected ? cs.primary : const Color(0xFF1E293B),
                            fontSize: 13.5,
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.check_circle_rounded, size: 14, color: cs.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatCurrency(v.price),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: selected ? cs.primary : const Color(0xFF0F172A),
                          ),
                        ),
                        if (discount > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '$discount% off',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPincodeCheck(ThemeData theme, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_shipping_outlined, size: 17, color: Color(0xFF16A34A)),
              ),
              const SizedBox(width: 8),
              const Text(
                'Delivery & Service Availability',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_usingDefaultPincode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Delivering to ${_pincodeController.text}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
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
                        color: cs.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: _pincodeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        hintText: 'Enter 6-digit Pincode',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                        counterText: '',
                        prefixIcon: Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _pincodeLoading ? null : _checkPincode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: _pincodeLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Check', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 17),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Delivery Available to ${_pincodeResult!['city'] ?? 'Location'}, ${_pincodeResult!['state'] ?? ''}',
                            style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _pincodeResult!['delivery_charge'] == '0.00' || _pincodeResult!['delivery_charge'] == 0
                          ? 'FREE Standard Shipping on this item'
                          : 'Standard Delivery Charge: ${formatCurrency(_pincodeResult!['delivery_charge'])}',
                      style: const TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w600, fontSize: 12.5),
                    ),
                    if (_pincodeResult!['courier'] != null)
                      Text(
                        'Fulfilled via ${_courierName(_pincodeResult!['courier'])}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    if (_pincodeResult!['estimated_days'] != null)
                      Text(
                        'Estimated delivery within ${_pincodeResult!['estimated_days']} business days',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pincodeResult!['message'] ?? 'Delivery not serviceable to this pincode',
                        style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w600, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabs(ThemeData theme, ColorScheme cs) {
    final tabs = ['Description'];
    if (_p.dosage != null && _p.dosage!.isNotEmpty) tabs.add('Dosage & Usage');
    tabs.add('Reviews (${_p.reviews.length})');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final active = _selectedTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      tabs[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13,
                        color: active ? cs.primary : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedTab == 0) _buildDescriptionTab(theme, cs),
        if (_selectedTab == 1 && _p.dosage != null && _p.dosage!.isNotEmpty) _buildDosageTab(theme, cs),
        if (_selectedTab == tabs.length - 1) _buildReviewsTab(theme, cs),
      ],
    );
  }

  Widget _buildDescriptionTab(ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_p.description != null && _p.description!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              _p.description!,
              style: const TextStyle(
                color: Color(0xFF334155),
                height: 1.6,
                fontSize: 14.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        const SizedBox(height: 14),

        // Recommended Crops
        if (_p.recommendedCrops != null && _p.recommendedCrops!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.park_rounded, size: 16, color: Color(0xFF16A34A)),
                    SizedBox(width: 6),
                    Text(
                      'Recommended Crops',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _p.recommendedCrops!
                      .split(',')
                      .map((c) => c.trim())
                      .where((c) => c.isNotEmpty)
                      .map((crop) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Text(
                        crop,
                        style: const TextStyle(
                          color: Color(0xFF15803D),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Product Specifications
        if (_p.sku != null || _p.classification != null || _p.brand != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Technical Specifications',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                if (_p.brand != null) _detailRow('Brand', _p.brand!),
                if (_p.classification != null) _detailRow('Classification', _p.classification!),
                if (_p.sku != null) _detailRow('SKU Code', _p.sku!),
                if (_p.categoryName != null) _detailRow('Category', _p.categoryName!),
              ],
            ),
          ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDosageTab(ThemeData theme, ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Color(0xFFD97706), size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Dosage, Dilution & Usage Directions',
                style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _p.dosage!,
            style: const TextStyle(color: Color(0xFF334155), height: 1.6, fontSize: 14),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Always wear protective gloves and glasses when handling orchard chemical sprays.',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab(ThemeData theme, ColorScheme cs) {
    final auth = context.watch<AuthProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (auth.isLoggedIn) ...[
          WriteReviewForm(productId: _p.id, onSubmitted: _loadProductDetail),
          const SizedBox(height: 16),
        ],
        if (_p.reviews.isEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('No reviews yet', style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Be the first orchardist to review this product', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          ..._p.reviews.map((r) => ReviewCard(review: r)),
      ],
    );
  }

  Widget? _buildMobileBottomBar(ThemeData theme, ColorScheme cs) {
    if (!_inStock) {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Currently Out of Stock', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Quantity Stepper
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_rounded, size: 16),
                    onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                    visualDensity: VisualDensity.compact,
                    splashRadius: 16,
                  ),
                  Text(
                    '$_quantity',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 16),
                    onPressed: _quantity < _currentStock ? () => setState(() => _quantity++) : null,
                    visualDensity: VisualDensity.compact,
                    splashRadius: 16,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Add to Cart Button
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _addToCart,
                  icon: Icon(Icons.shopping_bag_outlined, size: 16, color: cs.primary),
                  label: Text(
                    'Add to Cart',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: cs.primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.primary, width: 1.5),
                    backgroundColor: cs.primary.withValues(alpha: 0.04),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Buy Now Button
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _buyNow,
                  icon: const Icon(Icons.bolt_rounded, size: 17, color: Colors.white),
                  label: const Text(
                    'Buy Now',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
