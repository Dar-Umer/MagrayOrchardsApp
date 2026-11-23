import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/app_network_image.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_box.dart';
import '../config/api_config.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../utils/app_navigation.dart';
import '../utils/formatters.dart';
import 'login_screen.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchController = TextEditingController();
  final _statuses = [
    'All',
    'Pending',
    'Confirmed',
    'Processing',
    'Shipped',
    'Delivered',
    'Cancelled',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        context.read<OrderProvider>().fetchOrders();
      }
    });
  }

  (Color bg, Color text, IconData icon) _statusStyle(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'delivered':
        return (const Color(0xFFECFDF5), const Color(0xFF059669), Icons.check_circle_rounded);
      case 'confirmed':
        return (const Color(0xFFEFF6FF), const Color(0xFF2563EB), Icons.thumb_up_alt_rounded);
      case 'shipped':
        return (const Color(0xFFF0FDF4), const Color(0xFF16A34A), Icons.local_shipping_rounded);
      case 'processing':
        return (const Color(0xFFEEF2FF), const Color(0xFF4F46E5), Icons.inventory_2_rounded);
      case 'pending':
        return (const Color(0xFFFFFBEB), const Color(0xFFD97706), Icons.hourglass_top_rounded);
      case 'cancelled':
        return (const Color(0xFFFEF2F2), const Color(0xFFDC2626), Icons.cancel_rounded);
      case 'refunded':
        return (const Color(0xFFFAF5FF), const Color(0xFF9333EA), Icons.currency_rupee_rounded);
      case 'returned':
        return (const Color(0xFFF0FDFA), const Color(0xFF0D9488), Icons.keyboard_return_rounded);
      default:
        return (const Color(0xFFF1F5F9), const Color(0xFF64748B), Icons.info_outline_rounded);
    }
  }

  void _reorder(Order order) {
    final cart = context.read<CartProvider>();
    int addedCount = 0;
    for (final item in order.items) {
      if (item.productId == null) continue;
      cart.addItem(
        Product(
          id: item.productId!,
          name: item.name,
          slug: '',
          price: item.unitPrice,
          image: item.image,
        ),
        quantity: item.quantity,
      );
      addedCount++;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('$addedCount item(s) added to cart'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    if (!auth.isLoggedIn) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.bold)),
          elevation: 0,
        ),
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Login to view your orders',
          message: 'Sign in to track live purchases and reorder farm inputs',
          actionLabel: 'Login to Account',
          actionIcon: Icons.login_rounded,
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: Consumer<OrderProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.orders.isEmpty) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: const ShimmerCardList(itemCount: 4, itemHeight: 140),
              ),
            );
          }
          if (provider.orders.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'No orders yet',
              message: 'Your past orders and live tracking will appear here.',
              actionLabel: 'Browse Products',
              actionIcon: Icons.storefront_outlined,
              onAction: () => AppNavigation.goToTab(context, 0),
            );
          }

          final filtered = provider.filteredOrders;

          return RefreshIndicator(
            color: cs.primary,
            onRefresh: () => provider.fetchOrders(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: _buildSearchBar(provider, cs),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildFilterChips(provider, cs),
                      ),
                    ),
                    if (filtered.isEmpty && provider.orders.isNotEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No orders found',
                          message: 'Try clearing your search or checking another status filter.',
                          actionLabel: 'Clear Filters',
                          actionIcon: Icons.refresh_rounded,
                          onAction: () {
                            _searchController.clear();
                            provider.setSearchQuery('');
                            provider.setStatusFilter(null);
                          },
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final order = filtered[index];
                              return _buildOrderCard(order, cs);
                            },
                            childCount: filtered.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(OrderProvider provider, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: provider.setSearchQuery,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          hintText: 'Search by order # or product name...',
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.grey.shade500),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    provider.setSearchQuery('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterChips(OrderProvider provider, ColorScheme cs) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _statuses.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = _statuses[index];
          final isActive = (label == 'All' && provider.statusFilter == null) ||
              provider.statusFilter == label.toLowerCase();

          return InkWell(
            onTap: () {
              provider.setStatusFilter(label == 'All' ? null : label.toLowerCase());
            },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? cs.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? cs.primary : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(Order order, ColorScheme cs) {
    final status = _statusStyle(order.status);
    final firstItem = order.items.isNotEmpty ? order.items.first : null;
    final itemImage = firstItem?.image;
    final imageUrl = itemImage != null ? '${ApiConfig.imageBaseUrl}$itemImage' : null;

    final isDelivered = order.status.toLowerCase() == 'delivered' || order.status.toLowerCase() == 'completed';
    final isCancelled = order.status.toLowerCase() == 'cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Order ID + Date & Status Pill
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.receipt_long_rounded, size: 16, color: Colors.grey.shade700),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${order.orderNumber}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            if (order.createdAt != null)
                              Text(
                                formatDate(order.createdAt),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    // Single Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: status.$1,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: status.$2.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(status.$3, size: 13, color: status.$2),
                          const SizedBox(width: 4),
                          Text(
                            order.status[0].toUpperCase() + order.status.substring(1),
                            style: TextStyle(
                              color: status.$2,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

              // Middle Item Details
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Product Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: imageUrl != null
                            ? AppNetworkImage(
                                imageUrl: imageUrl,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => _itemPlaceholder(cs),
                              )
                            : _itemPlaceholder(cs),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Product Title & Item Count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            firstItem?.name ?? 'Order Items',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: Color(0xFF1E293B),
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Text(
                                '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (order.items.length > 1) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '+${order.items.length - 1} more',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Tap Indicator Chevron
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Summary & Quick Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(
                    top: BorderSide(color: Color(0xFFF1F5F9)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Price + Payment Mode
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              formatCurrency(order.totalAmount),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                color: cs.primary,
                              ),
                            ),
                            if (order.paymentMethod != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: order.paymentStatus?.toLowerCase() == 'paid'
                                      ? const Color(0xFFECFDF5)
                                      : const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  order.paymentMethod == 'cod'
                                      ? 'COD'
                                      : (order.paymentStatus?.toLowerCase() == 'paid' ? 'Paid' : 'Unpaid'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: order.paymentStatus?.toLowerCase() == 'paid'
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),

                    // Quick Actions
                    Row(
                      children: [
                        if (isDelivered || isCancelled)
                          OutlinedButton.icon(
                            onPressed: () => _reorder(order),
                            icon: Icon(Icons.refresh_rounded, size: 15, color: cs.primary),
                            label: Text(
                              'Buy Again',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              backgroundColor: cs.primary.withValues(alpha: 0.04),
                            ),
                          )
                        else
                          TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
                            ),
                            icon: const Text(
                              'View Details',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                            label: const Icon(Icons.arrow_forward_rounded, size: 14),
                            style: TextButton.styleFrom(
                              foregroundColor: cs.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemPlaceholder(ColorScheme cs) {
    return Container(
      color: cs.primary.withValues(alpha: 0.06),
      child: Icon(Icons.eco_outlined, color: cs.primary.withValues(alpha: 0.6), size: 24),
    );
  }
}
