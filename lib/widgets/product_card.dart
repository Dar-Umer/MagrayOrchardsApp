import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import 'app_network_image.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final discount = product.discountPercent;
    final inStock = product.inStock;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──
            Expanded(
              flex: 4,
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-$discount%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  if (product.brandInfo?.name != null ||
                      (product.brand != null && product.brand!.isNotEmpty))
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.brandInfo?.name ?? product.brand ?? '',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
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
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Rs. ${product.price.toStringAsFixed(0)}',
                          style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 14),
                        ),
                        if (product.comparePrice != null) ...[
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Text(
                              'Rs. ${product.comparePrice!.toStringAsFixed(0)}',
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
                    if (!inStock)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Out of Stock',
                            style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    const Spacer(),
                    if (inStock && showBuyButtons) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: FilledButton(
                          onPressed: () {
                            final cart = context.read<CartProvider>();
                            cart.clearCart();
                            cart.addItem(product);
                            Navigator.of(context).pushNamed('/checkout');
                          },
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Buy Now',
                              style: TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: OutlinedButton(
                          onPressed: () {
                            final cart = context.read<CartProvider>();
                            cart.addItem(product);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Added to cart'),
                                backgroundColor: theme.colorScheme.primary,
                                action: SnackBarAction(
                                  label: 'VIEW CART',
                                  textColor: Colors.white,
                                  onPressed: () =>
                                      Navigator.of(context).pushNamed('/checkout'),
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: BorderSide(color: primary),
                            foregroundColor: primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Add to Cart', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ] else if (!inStock)
                      SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
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
