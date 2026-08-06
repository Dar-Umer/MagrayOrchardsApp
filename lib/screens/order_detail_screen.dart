import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../services/api_service.dart';
import '../services/shop_config.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Order _order;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _fetchFresh();
  }

  Future<void> _fetchFresh() async {
    setState(() => _loadingDetail = true);
    final fresh = await context.read<OrderProvider>().fetchOrderDetail(_order.id);
    if (mounted && fresh != null) {
      setState(() { _order = fresh; _loadingDetail = false; });
    } else if (mounted) {
      setState(() => _loadingDetail = false);
    }
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
      case 'shipped':
        return Colors.blue;
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

  Widget _buildPaymentStatusBadge(String? status) {
    final color = _paymentStatusColor(status);
    final label = status != null
        ? (status[0].toUpperCase() + status.substring(1))
        : 'Pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
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
    if (_order.status != 'pending') return false;
    final shipment = _order.shipment;
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
          icon: const Icon(Icons.cancel, color: Colors.red, size: 48),
          title: const Text('Cancel Order?'),
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
                  DropdownMenuItem(value: 'wallet', child: Text('Refund to Wallet')),
                  DropdownMenuItem(value: 'original', child: Text('Original Method')),
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
            TextButton(
              onPressed: () {
                if (reason == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please select a reason for cancelling'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(ctx);
                _confirmCancel(reason!, refundMethod!);
              },
              child: const Text('Continue'),
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
        title: const Text('Confirm Cancellation'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text('Cancel order #${_order.orderNumber}? Refund will be processed to your $refundMethod method.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Order', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.patch('/orders/${_order.id}/cancel', body: {'refund_method': refundMethod, 'cancellation_reason': reason});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Order cancelled successfully'), backgroundColor: Theme.of(context).colorScheme.primary),
        );
        setState(() {
          _order = Order(
            id: _order.id,
            orderNumber: _order.orderNumber,
            type: _order.type,
            status: 'cancelled',
            subtotal: _order.subtotal,
            discount: _order.discount,
            tax: _order.tax,
            shippingCharge: _order.shippingCharge,
            pincodeDeliveryCharge: _order.pincodeDeliveryCharge,
            totalAmount: _order.totalAmount,
            paymentMethod: _order.paymentMethod,
            paymentStatus: _order.paymentStatus,
            razorpayOrderId: _order.razorpayOrderId,
            razorpayPaymentId: _order.razorpayPaymentId,
            shippingAddress: _order.shippingAddress,
            billingAddress: _order.billingAddress,
            notes: _order.notes,
            cancellationReason: reason,
            cancelledAt: DateTime.now(),
            shipment: _order.shipment,
            items: _order.items,
            walletAmountUsed: _order.walletAmountUsed,
            createdAt: _order.createdAt,
            deliveredAt: _order.deliveredAt,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'We couldn\'t cancel this order. It may already be processing.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _reorder() {
    final cart = context.read<CartProvider>();
    for (final item in _order.items) {
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
        content: Text('${_order.items.length} item(s) added to cart'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Order #${_order.orderNumber}')),
      body: _loadingDetail
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusTimeline(cs),
                  const SizedBox(height: 20),
                  _buildActionButtons(cs),
                  const SizedBox(height: 20),
                  _buildItemsSection(cs),
                  const SizedBox(height: 16),
                  _buildPriceSection(cs),
                  const SizedBox(height: 16),
                  if (_order.paymentMethod != null) _buildPaymentSection(cs),
                  const SizedBox(height: 16),
                  if (_order.shipment != null) _buildShipmentSection(cs),
                  const SizedBox(height: 16),
                  if (_order.shippingAddress != null) _buildAddressSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusTimeline(ColorScheme cs) {
    final steps = ['pending', 'confirmed', 'shipped', 'delivered'];
    final currentIdx = steps.indexOf(_order.status);
    final displayIdx = currentIdx >= 0 ? currentIdx : (_order.status == 'processing' ? 1 : 0);
    final isCancelled = _order.status == 'cancelled';
    final isRefunded = _order.status == 'refunded';
    final isReturned = _order.status == 'returned';

    if (isCancelled || isRefunded || isReturned) {
      final (icon, color, title) = isCancelled
          ? (Icons.cancel_outlined, Colors.red, 'Cancelled')
          : isRefunded
              ? (Icons.currency_rupee, Colors.orange, 'Refunded')
              : (Icons.local_shipping_outlined, Colors.teal, 'Returned');

      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              if (_order.cancellationReason != null && isCancelled) ...[
                const SizedBox(height: 6),
                Text('Reason: ${_order.cancellationReason}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
              if (_order.createdAt != null)
                Text('Placed on ${_order.createdAt!.day}/${_order.createdAt!.month}/${_order.createdAt!.year}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(steps.length, (i) {
                final isActive = i <= displayIdx;
                final isLast = i == steps.length - 1;
                return Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive ? cs.primary : Colors.grey.shade300,
                            ),
                            child: Icon(
                              i < displayIdx ? Icons.check : (isActive ? Icons.circle : Icons.circle_outlined),
                              size: i < displayIdx ? 14 : 10,
                              color: Colors.white,
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: i < displayIdx ? cs.primary : Colors.grey.shade300,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[i][0].toUpperCase() + steps[i].substring(1),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          color: isActive ? cs.primary : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            if (_order.createdAt != null) ...[
              const SizedBox(height: 10),
              Center(
                child: Text('Placed on ${_order.createdAt!.day}/${_order.createdAt!.month}/${_order.createdAt!.year}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme cs) {
    final buttons = <Widget>[];
    if (_canCancel) {
      buttons.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _cancelOrder,
            icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
            label: const Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      );
    }
    if (_order.items.any((i) => i.productId != null)) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 10));
      buttons.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _reorder,
            icon: Icon(Icons.replay, size: 18, color: cs.primary),
            label: Text('Reorder', style: TextStyle(color: cs.primary, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cs.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      );
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Row(children: buttons);
  }

  Widget _buildItemsSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._order.items.map((item) {
          final imageUrl = item.image != null ? '${ApiConfig.imageBaseUrl}${item.image}' : null;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imageUrl != null
                        ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _itemPlaceholder(cs))
                        : _itemPlaceholder(cs),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Qty: ${item.quantity}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                  ),
                  Text('Rs. ${item.totalPrice.toStringAsFixed(0)}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _itemPlaceholder(ColorScheme cs) {
    return Container(
      width: 50, height: 50,
      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(Icons.eco, color: cs.primary, size: 24),
    );
  }

  Widget _buildPriceSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Price Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _priceRow('Subtotal', 'Rs. ${_order.subtotal.toStringAsFixed(0)}'),
                if (_order.tax > 0)
                  _priceRow('Tax (${ShopConfig.taxRate.toStringAsFixed(0)}%)', 'Rs. ${_order.tax.toStringAsFixed(0)}'),
                if (_order.shippingCharge > 0)
                  _priceRow('Shipping', 'Rs. ${_order.shippingCharge.toStringAsFixed(0)}'),
                if (_order.pincodeDeliveryCharge > 0)
                  _priceRow('Delivery Charge', 'Rs. ${_order.pincodeDeliveryCharge.toStringAsFixed(0)}'),
                if (_order.discount > 0)
                  _priceRow('Discount', '- Rs. ${_order.discount.toStringAsFixed(0)}'),
                if ((_order.walletAmountUsed ?? 0) > 0)
                  _priceRow('Paid via Wallet', '- Rs. ${_order.walletAmountUsed!.toStringAsFixed(0)}', color: Colors.green),
                const Divider(),
                _priceRow('Total', 'Rs. ${_order.totalAmount.toStringAsFixed(0)}', isBold: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _order.paymentMethod == 'cod' ? Icons.money : Icons.payment,
                    color: cs.primary,
                  ),
                  title: Text(_order.paymentMethod == 'cod'
                      ? 'Cash on Delivery'
                      : _order.paymentMethod == 'wallet'
                          ? 'Wallet Payment'
                          : 'Razorpay'),
                  subtitle: Text(_order.paymentStatus ?? 'Pending'),
                  trailing: _buildPaymentStatusBadge(_order.paymentStatus),
                ),
                if (_order.razorpayPaymentId != null && _order.razorpayPaymentId!.isNotEmpty) ...[
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment ID', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      Flexible(
                        child: Text(_order.razorpayPaymentId!,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
                if (_order.razorpayOrderId != null && _order.razorpayOrderId!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Order Ref', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      Flexible(
                        child: Text(_order.razorpayOrderId!,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShipmentSection(ColorScheme cs) {
    final s = _order.shipment!;
    final trackingUrl = s['tracking_url'] as String?;
    final courierResponse = s['courier_response'];
    final timeline = courierResponse is Map && courierResponse['timeline'] is List
        ? (courierResponse['timeline'] as List).cast<Map<String, dynamic>>()
        : const <Map<String, dynamic>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Shipment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s['courier_partner'] is Map) ...[
                  _shipmentRow(Icons.business, 'Courier', (s['courier_partner'] as Map)['name'] ?? ''),
                  const SizedBox(height: 8),
                ],
                if (s['tracking_number'] != null) ...[
                  _shipmentRow(Icons.qr_code, 'Tracking #', s['tracking_number']),
                  const SizedBox(height: 8),
                ],
                _shipmentRow(
                  Icons.circle,
                  'Status',
                  s['status'] != null ? '${s['status'][0].toUpperCase()}${s['status'].substring(1)}' : 'N/A',
                  valueColor: _statusColor(s['status'] ?? ''),
                ),
                if (s['current_location'] != null) ...[
                  const SizedBox(height: 8),
                  _shipmentRow(Icons.location_on, 'Location', s['current_location']),
                ],
                if (s['estimated_delivery'] != null) ...[
                  const SizedBox(height: 8),
                  _shipmentRow(Icons.calendar_today, 'Est. Delivery', s['estimated_delivery']),
                ],
                if (timeline.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  const Text('Tracking Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  ...timeline.map((entry) => _buildTimelineRow(entry, cs)),
                ],
                if (trackingUrl != null && trackingUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openTrackingUrl(trackingUrl),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Track Shipment', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cs.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineRow(Map<String, dynamic> entry, ColorScheme cs) {
    final status = entry['status'] ?? '';
    final location = entry['location'] ?? '';
    final rawDate = entry['date'] ?? '';
    final date = rawDate is String && rawDate.isNotEmpty
        ? rawDate.replaceFirst('T', ' ').substring(0, 16)
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 10, color: _statusColor('$status')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$status', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (location.isNotEmpty)
                  Text('$location', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                if (date.isNotEmpty)
                  Text(date, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
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

  Widget _shipmentRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Expanded(
          child: Text(value,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: valueColor)),
        ),
      ],
    );
  }

  Widget _buildAddressSection() {
    final a = _order.shippingAddress!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Shipping Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(a['phone'] ?? ''),
                const SizedBox(height: 4),
                Text(a['address_line1'] ?? ''),
                if (a['address_line2'] != null) Text(a['address_line2']),
                Text('${a['city'] ?? ''}, ${a['state'] ?? ''} ${a['pincode'] ?? ''}'),
                Text(a['country'] ?? ''),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _priceRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}
