import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/empty_state.dart';
import '../config/api_config.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import 'login_screen.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchController = TextEditingController();
  final _statuses = ['All', 'Pending', 'Confirmed', 'Processing', 'Shipped', 'Delivered', 'Cancelled', 'Refunded', 'Returned'];

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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'refunded':
        return Colors.orange;
      case 'returned':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Color _paymentStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
      case 'completed':
        return Colors.green;
      case 'pending':
      case 'unpaid':
        return Colors.orange;
      case 'failed':
      case 'refunded':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _reorder(Order order) {
    final cart = context.read<CartProvider>();
    for (final item in order.items) {
      if (item.productId == null) continue;
      cart.addItem(Product(
        id: item.productId!,
        name: item.name,
        slug: '',
        price: item.unitPrice,
        image: item.image,
      ), quantity: item.quantity);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${order.items.length} item(s) added to cart'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Orders')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Login to view your orders',
                  style: TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Login', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: Consumer<OrderProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.orders.isEmpty) {
            return Center(child: CircularProgressIndicator(color: cs.primary));
          }
          if (provider.orders.isEmpty) {
            return const EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'No orders yet',
              message: 'Start shopping to see your orders here',
            );
          }

          final filtered = provider.filteredOrders;

          return RefreshIndicator(
            onRefresh: () => provider.fetchOrders(),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildFilterChips(provider, cs)),
                SliverToBoxAdapter(child: _buildSearchBar(provider, cs)),
                if (filtered.isEmpty && provider.orders.isNotEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: const EmptyState(
                      icon: Icons.search_off,
                      title: 'No orders match your filters',
                      message: 'Try a different search or status',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final order = filtered[index];
                          return _buildOrderCard(order, cs, provider);
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(OrderProvider provider, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _statuses.map((label) {
            final isActive = (label == 'All' && provider.statusFilter == null) ||
                provider.statusFilter == label.toLowerCase();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(label, style: TextStyle(fontSize: 13, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
                selected: isActive,
                onSelected: (_) {
                  provider.setStatusFilter(label == 'All' ? null : label.toLowerCase());
                  provider.setSearchQuery('');
                  _searchController.clear();
                },
                selectedColor: cs.primary.withValues(alpha: 0.15),
                checkmarkColor: cs.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchBar(OrderProvider provider, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: provider.setSearchQuery,
        decoration: InputDecoration(
          hintText: 'Search by order number...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    provider.setSearchQuery('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order, ColorScheme cs, OrderProvider provider) {
    final payColor = _paymentStatusColor(order.paymentStatus);
    final payLabel = order.paymentStatus != null
        ? (order.paymentStatus![0].toUpperCase() + order.paymentStatus!.substring(1))
        : 'Pending';
    final itemImage = order.items.isNotEmpty ? order.items.first.image : null;
    final imageUrl = itemImage != null ? '${ApiConfig.imageBaseUrl}$itemImage' : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: imageUrl != null
                        ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _itemPlaceholder(cs))
                        : _itemPlaceholder(cs),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order ${order.orderNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('${order.items.length} item(s)',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        const SizedBox(height: 2),
                        Text('Rs. ${order.totalAmount.toStringAsFixed(0)}',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.primary)),
                        if (order.createdAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${order.createdAt!.day}/${order.createdAt!.month}/${order.createdAt!.year}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(order.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          order.status[0].toUpperCase() + order.status.substring(1),
                          style: TextStyle(
                            color: _statusColor(order.status),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: payColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(payLabel, style: TextStyle(fontSize: 10, color: payColor, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reorder(order),
                      icon: const Icon(Icons.replay, size: 16),
                      label: const Text('Reorder', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('Details', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemPlaceholder(ColorScheme cs) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.eco, color: cs.primary, size: 28),
    );
  }
}
