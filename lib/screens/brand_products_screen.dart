import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';

class BrandProductsScreen extends StatefulWidget {
  final int brandId;
  final String brandName;

  const BrandProductsScreen({
    super.key,
    required this.brandId,
    required this.brandName,
  });

  @override
  State<BrandProductsScreen> createState() => _BrandProductsScreenState();
}

class _BrandProductsScreenState extends State<BrandProductsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().fetchProducts(
            brandId: widget.brandId,
            page: 1,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.brandName),
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.brandLoading && provider.brandProducts.isEmpty) {
            return _buildShimmer();
          }

          if (provider.brandProducts.isEmpty) {
            return _buildEmpty();
          }

          return RefreshIndicator(
            color: primary,
            onRefresh: () => provider.fetchProducts(
              brandId: widget.brandId,
              page: 1,
            ),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification &&
                    notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 200) {
                  provider.loadMore(brandId: widget.brandId);
                }
                return false;
              },
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: responsiveProductGridDelegate(),
                itemCount: provider.brandProducts.length,
                itemBuilder: (context, index) {
                  final product = provider.brandProducts[index];
                  return ProductCard(
                    product: product,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ProductDetailScreen(product: product)),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: responsiveProductGridDelegate(),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No products found',
            style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'This brand has no products yet',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
