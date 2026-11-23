import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../screens/checkout_screen.dart';
import '../screens/product_detail_screen.dart';
import '../utils/app_navigation.dart';
import '../utils/formatters.dart';
import 'app_network_image.dart';

/// Shared responsive grid delegate for product listings across mobile, tablet, and web.
SliverGridDelegateWithMaxCrossAxisExtent responsiveProductGridDelegate({
  double spacing = 12,
  double mainAxisExtent = 296,
}) {
  return SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 215,
    mainAxisExtent: mainAxisExtent,
    crossAxisSpacing: spacing,
    mainAxisSpacing: spacing,
  );
}

/// Premium product card used across home, search, and category screens.
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final bool showBuyButtons;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.showBuyButtons = true,
  });

  Future<void> _handleBuyNow(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please login to continue to checkout'),
            backgroundColor: Colors.orange,
          ),
        );
      Navigator.of(context).pushNamed('/login');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          expressItems: [CartItem(product: product, quantity: 1)],
        ),
      ),
    );
  }

  void _handleAddToCart(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.read<CartProvider>();
    cart.addItem(product);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Added to cart'),
          backgroundColor: theme.colorScheme.primary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'VIEW CART',
            textColor: Colors.white,
            onPressed: () => AppNavigation.openCart(context),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final discount = product.discountPercent;
    final inStock = product.inStock;
    final brandLabel = product.brandInfo?.name ?? product.brand ?? '';

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: InkWell(
        onTap: onTap ??
            () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: product),
                  ),
                ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                    child: product.image != null
                        ? AppNetworkImage(
                            imageUrl: '${ApiConfig.imageBaseUrl}${product.image}',
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Center(
                              child: Icon(Icons.eco, size: 40, color: primary),
                            ),
                            errorWidget: (_, __, ___) => Center(
                              child: Icon(Icons.eco, size: 40, color: primary),
                            ),
                          )
                        : Center(child: Icon(Icons.eco, size: 40, color: primary)),
                  ),
                  if (discount > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-$discount%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  if (brandLabel.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 88),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            brandLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Info ──
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, height: 1.25),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.rating > 0) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  product.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.star_rounded, size: 11, color: Colors.white),
                              ],
                            ),
                          ),
                          if (product.reviewsCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${product.reviewsCount})',
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            formatCurrency(product.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14),
                          ),
                        ),
                        if (product.comparePrice != null &&
                            product.comparePrice! > product.price) ...[
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Text(
                              formatCurrency(product.comparePrice),
                              style: const TextStyle(
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    if (inStock && showBuyButtons)
                      Row(
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: IconButton.outlined(
                              tooltip: 'Add to Cart',
                              onPressed: () => _handleAddToCart(context),
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(
                                side: BorderSide(color: primary),
                                foregroundColor: primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: FilledButton(
                                onPressed: () => _handleBuyNow(context),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text(
                                  'Buy Now',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (!inStock)
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Out of Stock', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
