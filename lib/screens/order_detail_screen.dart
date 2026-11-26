import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../services/api_service.dart';
import '../services/shop_config.dart';
import '../utils/formatters.dart';
import '../widgets/app_network_image.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order? order;
  final int? orderId;

  const OrderDetailScreen({super.key, this.order, this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Order? _order;

  /// Non-null accessor used after [build] has verified the order exists.
  Order get _o => _order!;

  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    if (_order == null && widget.orderId != null) {
      _fetchByOrderId(widget.orderId!);
    } else {
      _fetchFresh();
    }
  }

  Future<void> _fetchByOrderId(int id) async {
    setState(() => _loadingDetail = true);
    final fetched = await context.read<OrderProvider>().fetchOrderDetail(id);
    if (mounted) {
      setState(() {
        _order = fetched;
        _loadingDetail = false;
      });
    }
  }

  Future<void> _fetchFresh() async {
    if (_order == null) return;
    setState(() => _loadingDetail = true);
    final fresh = await context.read<OrderProvider>().fetchOrderDetail(_order!.id);
    if (mounted && fresh != null) {
      setState(() {
        _order = fresh;
        _loadingDetail = false;
      });
    } else if (mounted) {
      setState(() => _loadingDetail = false);
    }
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

  static const _cancelReasons = [
    'Changed my mind',
    'Ordered by mistake',
    'Delivery takes too long',
    'Found better price elsewhere',
    'Payment issue',
    'Other',
  ];

  static const _cancellableShipmentStatuses = [
    'pending',
    'created',
    'manifested',
    'error',
  ];

  bool get _canCancel {
    if (_o.status != 'pending') return false;
    final shipment = _o.shipment;
    if (shipment == null) return true;
    final status = (shipment['status'] as String?) ?? '';
    return status.isEmpty || _cancellableShipmentStatuses.contains(status);
  }

  Future<void> _cancelOrder() async {
    String? reason;
    String? refundMethod = 'wallet';
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.cancel_rounded, color: Colors.red, size: 48),
          title: const Text('Cancel Order?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(
                  labelText: 'Reason for cancelling',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _cancelReasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setDialogState(() => reason = v),
                validator: (v) => v == null ? 'Please select a reason' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: refundMethod,
                decoration: const InputDecoration(
                  labelText: 'Refund method',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'wallet', child: Text('Refund to Wallet (Instant)')),
                  DropdownMenuItem(value: 'original', child: Text('Original Payment Method')),
                ],
                onChanged: (v) => setDialogState(() => refundMethod = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Order'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reason == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a reason for cancelling'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                _confirmCancel(reason!, refundMethod!);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Continue', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(String reason, String refundMethod) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Cancellation', style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(
          'Cancel order #${_o.orderNumber}? Refund will be processed to your $refundMethod method.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No, Go Back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel Order', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.patch(
        '/orders/${_o.id}/cancel',
        body: {'refund_method': refundMethod, 'cancellation_reason': reason},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Order cancelled successfully'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        setState(() {
          _order = Order(
            id: _o.id,
            orderNumber: _o.orderNumber,
            type: _o.type,
            status: 'cancelled',
            subtotal: _o.subtotal,
            discount: _o.discount,
            tax: _o.tax,
            shippingCharge: _o.shippingCharge,
            pincodeDeliveryCharge: _o.pincodeDeliveryCharge,
            totalAmount: _o.totalAmount,
            paymentMethod: _o.paymentMethod,
            paymentStatus: _o.paymentStatus,
            razorpayOrderId: _o.razorpayOrderId,
            razorpayPaymentId: _o.razorpayPaymentId,
            shippingAddress: _o.shippingAddress,
            billingAddress: _o.billingAddress,
            notes: _o.notes,
            cancellationReason: reason,
            cancelledAt: DateTime.now(),
            shipment: _o.shipment,
            items: _o.items,
            walletAmountUsed: _o.walletAmountUsed,
            createdAt: _o.createdAt,
            deliveredAt: _o.deliveredAt,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'We couldn\'t cancel this order. It may already be processing.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _reorder() {
    final cart = context.read<CartProvider>();
    int addedCount = 0;
    for (final item in _o.items) {
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

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_order == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Order Details', style: TextStyle(fontWeight: FontWeight.bold)),
          elevation: 0,
        ),
        body: Center(
          child: _loadingDetail
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey.shade400),
                    const SizedBox(height: 14),
                    const Text(
                      'This order could not be found.',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
        ),
      );
    }

    final order = _o;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Order #${order.orderNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 19),
            tooltip: 'Copy Order Number',
            onPressed: () => _copyToClipboard(order.orderNumber, 'Order Number'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 21),
            tooltip: 'Refresh Status',
            onPressed: _fetchFresh,
          ),
        ],
      ),
      body: _loadingDetail
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusHero(cs),
                      const SizedBox(height: 16),
                      if (order.shipment != null) ...[
                        _buildShipmentCard(cs),
                        const SizedBox(height: 16),
                      ],
                      _buildItemsCard(cs),
                      const SizedBox(height: 16),
                      _buildPriceCard(cs),
                      const SizedBox(height: 16),
                      if (order.shippingAddress != null) ...[
                        _buildAddressCard(cs),
                        const SizedBox(height: 16),
                      ],
                      if (order.paymentMethod != null) _buildPaymentCard(cs),
                    ],
                  ),
                ),
              ),
            ),
      bottomSheet: _buildBottomBar(cs),
    );
  }

  Widget _buildStatusHero(ColorScheme cs) {
    final status = _statusStyle(_o.status);
    final isCancelled = _o.status == 'cancelled';
    final isRefunded = _o.status == 'refunded';
    final isDelivered = _o.status == 'delivered' || _o.status == 'completed';

    final steps = ['pending', 'confirmed', 'shipped', 'delivered'];
    final currentIdx = steps.indexOf(_o.status);
    final displayIdx = currentIdx >= 0 ? currentIdx : (_o.status == 'processing' ? 1 : 0);

    return Container(
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: status.$1,
                  shape: BoxShape.circle,
                  border: Border.all(color: status.$2.withValues(alpha: 0.25)),
                ),
                child: Icon(status.$3, size: 24, color: status.$2),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCancelled
                          ? 'Order Cancelled'
                          : isRefunded
                              ? 'Refund Processed'
                              : isDelivered
                                  ? 'Delivered Successfully'
                                  : 'Order ${_o.status[0].toUpperCase()}${_o.status.substring(1)}',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: status.$2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _o.createdAt != null
                          ? 'Placed on ${formatDate(_o.createdAt)}'
                          : 'Order registered',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isCancelled && _o.cancellationReason != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: ${_o.cancellationReason}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (!isCancelled && !isRefunded) ...[
            const SizedBox(height: 20),
            // Sleek Step Progress Indicator
            Row(
              children: List.generate(steps.length, (i) {
                final isDone = i <= displayIdx;
                final isCurrent = i == displayIdx;
                final isLast = i == steps.length - 1;

                final stepLabels = ['Placed', 'Confirmed', 'Shipped', 'Delivered'];

                return Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDone ? cs.primary : const Color(0xFFF1F5F9),
                              border: Border.all(
                                color: isDone ? cs.primary : const Color(0xFFCBD5E1),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              isDone ? (i < displayIdx ? Icons.check : Icons.circle) : Icons.circle_outlined,
                              size: i < displayIdx ? 14 : 9,
                              color: isDone ? Colors.white : Colors.transparent,
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                height: 3,
                                color: i < displayIdx ? cs.primary : const Color(0xFFE2E8F0),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        stepLabels[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrent ? FontWeight.w700 : (isDone ? FontWeight.w600 : FontWeight.w400),
                          color: isDone ? const Color(0xFF0F172A) : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShipmentCard(ColorScheme cs) {
    final s = _o.shipment!;
    final trackingUrl = s['tracking_url'] as String?;
    final courierPartner = s['courier_partner'] is Map ? (s['courier_partner'] as Map)['name'] : null;
    final trackingNumber = s['tracking_number']?.toString();

    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Courier & Tracking',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (courierPartner != null) ...[
            _infoRow('Courier Partner', courierPartner),
            const SizedBox(height: 8),
          ],

          if (trackingNumber != null && trackingNumber.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tracking Number', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                Row(
                  children: [
                    Text(
                      trackingNumber,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, fontFamily: 'monospace'),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _copyToClipboard(trackingNumber, 'Tracking Number'),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.copy_rounded, size: 15, color: cs.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          if (s['status'] != null) ...[
            _infoRow(
              'Shipment Status',
              '${s['status'][0].toUpperCase()}${s['status'].substring(1)}',
              valueColor: const Color(0xFF2563EB),
            ),
            const SizedBox(height: 8),
          ],

          if (s['current_location'] != null) ...[
            _infoRow('Current Location', '${s['current_location']}'),
            const SizedBox(height: 8),
          ],

          if (s['estimated_delivery'] != null) ...[
            _infoRow('Est. Delivery', formatDate(s['estimated_delivery'])),
            const SizedBox(height: 8),
          ],

          if (trackingUrl != null && trackingUrl.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openTrackingUrl(trackingUrl),
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: const Text('Track Package on Courier Website', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.primary,
                  side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsCard(ColorScheme cs) {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Items (${_o.items.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              Text(
                formatCurrency(_o.subtotal),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: cs.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _o.items.length,
            separatorBuilder: (context, index) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Color(0xFFF8FAFC)),
            ),
            itemBuilder: (context, index) {
              final item = _o.items[index];
              final imageUrl = item.image != null && item.image!.trim().isNotEmpty
                  ? ApiConfig.resolveImageUrl(item.image)
                  : null;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: imageUrl != null
                          ? AppNetworkImage(
                              imageUrl: imageUrl,
                              width: 58,
                              height: 58,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => _itemPlaceholder(cs),
                            )
                          : _itemPlaceholder(cs),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Qty: ${item.quantity}  ×  ${formatCurrency(item.unitPrice)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatCurrency(item.totalPrice),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(ColorScheme cs) {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Price Summary',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          _priceRow('Subtotal', formatCurrency(_o.subtotal)),
          if (_o.tax > 0)
            _priceRow('Tax (${ShopConfig.taxRate.toStringAsFixed(0)}%)', formatCurrency(_o.tax)),
          _priceRow(
            'Shipping Charge',
            _o.shippingCharge > 0 ? formatCurrency(_o.shippingCharge) : 'FREE',
            color: _o.shippingCharge > 0 ? null : const Color(0xFF059669),
          ),
          if (_o.pincodeDeliveryCharge > 0)
            _priceRow('Local Delivery Charge', formatCurrency(_o.pincodeDeliveryCharge)),
          if (_o.discount > 0)
            _priceRow('Discount Applied', '- ${formatCurrency(_o.discount)}', color: const Color(0xFF059669)),
          if ((_o.walletAmountUsed ?? 0) > 0)
            _priceRow('Wallet Deduction', '- ${formatCurrency(_o.walletAmountUsed!)}', color: const Color(0xFF059669)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Payable',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
              ),
              Text(
                formatCurrency(_o.totalAmount),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: cs.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(ColorScheme cs) {
    final a = _o.shippingAddress!;
    final name = a['name'] ?? '';
    final phone = a['phone'] ?? '';
    final line1 = a['address_line1'] ?? '';
    final line2 = a['address_line2'];
    final cityState = '${a['city'] ?? ''}${a['city'] != null && a['state'] != null ? ', ' : ''}${a['state'] ?? ''} ${a['pincode'] ?? ''}'.trim();

    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_rounded, color: Color(0xFF16A34A), size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Delivery Address',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (name.isNotEmpty) ...[
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 2),
          ],
          if (phone.isNotEmpty) ...[
            Text(
              phone,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
          ],
          if (line1.isNotEmpty)
            Text(
              line1,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.3),
            ),
          if (line2 != null && line2.toString().isNotEmpty)
            Text(
              line2.toString(),
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.3),
            ),
          if (cityState.isNotEmpty)
            Text(
              cityState,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(ColorScheme cs) {
    final methodLabel = _o.paymentMethod == 'cod'
        ? 'Cash on Delivery (COD)'
        : _o.paymentMethod == 'wallet'
            ? 'Magray Wallet'
            : 'Online Payment (Razorpay)';

    final isPaid = _o.paymentStatus?.toLowerCase() == 'paid';

    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payment_rounded, color: Color(0xFF9333EA), size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Payment Details',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                methodLabel,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPaid ? 'PAID' : 'PENDING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isPaid ? const Color(0xFF059669) : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          if (_o.razorpayPaymentId != null && _o.razorpayPaymentId!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow('Payment Ref', _o.razorpayPaymentId!),
          ],
        ],
      ),
    );
  }

  Widget? _buildBottomBar(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_canCancel) ...[
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: _cancelOrder,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    foregroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _reorder,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reorder All Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: valueColor ?? const Color(0xFF0F172A)),
        ),
      ],
    );
  }

  Widget _priceRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: color ?? const Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _itemPlaceholder(ColorScheme cs) {
    return Container(
      color: cs.primary.withValues(alpha: 0.06),
      child: Icon(Icons.eco_outlined, color: cs.primary.withValues(alpha: 0.6), size: 22),
    );
  }

  Future<void> _openTrackingUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the tracking link.')),
      );
    }
  }
}
