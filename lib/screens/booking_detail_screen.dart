import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../models/service_booking.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/booking_payment.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';

class BookingDetailScreen extends StatefulWidget {
  final ServiceBookingModel? booking;
  final int? bookingId;

  const BookingDetailScreen({super.key, this.booking, this.bookingId})
      : assert(booking != null || bookingId != null,
            'Either booking or bookingId must be provided');

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  ServiceBookingModel? _booking;
  bool _loading = false;
  String? _error;
  bool _cancelling = false;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _fetchDetail();
  }

  int get _id => _booking?.id ?? widget.bookingId!;

  Future<void> _fetchDetail() async {
    setState(() {
      _loading = _booking == null;
      _error = null;
    });

    try {
      final fresh = await ApiService.fetchBookingDetail(_id);
      if (mounted) {
        setState(() {
          _booking = fresh;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException
              ? e.message
              : 'Could not load booking details.';
          _loading = false;
        });
      }
    }
  }

  void _toast(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color ?? Theme.of(context).colorScheme.primary,
    ));
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'in_progress':
      case 'assigned':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Color _paymentStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'unpaid':
      case 'pending':
        return Colors.orange;
      case 'refunded':
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _callPhone(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleaned');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _toast('Could not open phone dialer for $phone', color: Colors.orange);
      }
    } catch (_) {
      _toast('Could not call $phone', color: Colors.orange);
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _toast('Could not open map.', color: Colors.orange);
      }
    } catch (_) {
      _toast('Could not open map.', color: Colors.orange);
    }
  }

  Future<void> _confirmCancel() async {
    final booking = _booking;
    if (booking == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: Text(
          'Are you sure you want to cancel booking ${booking.bookingNumber} for ${booking.serviceName}?\n\nThis will release your scheduled time slot.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _cancelling = true);
    try {
      final updated = await ApiService.cancelBooking(booking.id);
      if (mounted) {
        setState(() {
          _booking = updated;
          _cancelling = false;
        });
        _toast('Booking ${booking.bookingNumber} has been cancelled.',
            color: Colors.red.shade700);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        _toast(
          e is ApiException
              ? e.message
              : 'Could not cancel booking. Please try again.',
          color: Colors.red,
        );
      }
    }
  }

  Future<void> _payNow() async {
    final booking = _booking;
    if (booking == null) return;
    final auth = context.read<AuthProvider>();

    setState(() => _paying = true);
    try {
      final result = await BookingPayment.start(
        bookingId: booking.id,
        description: '${booking.serviceName} booking',
        customerName: auth.user?.name,
        customerEmail: auth.user?.email,
        customerPhone: auth.user?.phone,
      );

      if (!mounted) return;
      switch (result) {
        case BookingPaymentResult.success:
          _toast('Payment received! Booking confirmed.', color: Colors.green);
          await _fetchDetail();
        case BookingPaymentResult.cancelled:
          _toast('Payment cancelled.', color: Colors.orange);
        case BookingPaymentResult.failed:
          _toast('Payment failed. Please try again or pay on visit.',
              color: Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _toast(
          e is ApiException ? e.message : 'Could not initiate online payment.',
          color: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading && _booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load booking',
          message: _error!,
          actionLabel: 'Retry',
          onAction: _fetchDetail,
        ),
      );
    }

    final b = _booking!;
    final statusColor = _statusColor(b.status);
    final payColor = _paymentStatusColor(b.paymentStatus);
    final imageUrl = b.serviceImage != null
        ? '${ApiConfig.imageBaseUrl}${b.serviceImage}'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Booking ${b.bookingNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _fetchDetail,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDetail,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Service Header Card
                  _buildServiceHeaderCard(b, imageUrl, cs),
                  const SizedBox(height: 14),

                  // 2. Status & Payment Badges Card
                  _buildStatusCard(b, statusColor, payColor, cs),
                  const SizedBox(height: 14),

                  // 3. Assigned Staff Card
                  _buildAssignedStaffCard(b, cs),
                  const SizedBox(height: 14),

                  // 4. Schedule & Scope Card
                  _buildScheduleCard(b, cs),
                  const SizedBox(height: 14),

                  // 5. Farm / Orchard Location Card
                  _buildLocationCard(b, cs),
                  const SizedBox(height: 14),

                  // 6. Payment & Price Breakdown Card
                  _buildPaymentCard(b, cs),
                  const SizedBox(height: 20),

                  // 7. Actions: Pay Online (if unpaid) & Cancel (if cancellable)
                  if (!b.isPaid && !b.isCancelled) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _paying ? null : _payNow,
                        icon: _paying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.payment, size: 20),
                        label: Text(
                          _paying
                              ? 'Opening Payment...'
                              : 'Pay Online Now — ${formatCurrency(b.totalAmount)}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (b.isCancellable) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _cancelling ? null : _confirmCancel,
                        icon: _cancelling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.red),
                              )
                            : const Icon(Icons.cancel_outlined,
                                color: Colors.red, size: 20),
                        label: Text(
                          _cancelling
                              ? 'Cancelling Booking...'
                              : 'Cancel Booking',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Pending unpaid bookings can be cancelled anytime with zero fee.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  ],

                  if (b.isCancelled)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This booking has been cancelled.',
                              style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceHeaderCard(
      ServiceBookingModel b, String? imageUrl, ColorScheme cs) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _servicePlaceholder(cs),
                    )
                  : _servicePlaceholder(cs),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.bookingNumber,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    b.serviceName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (b.formattedScope != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.yard_outlined, size: 14, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(
                          b.formattedScope!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ServiceBookingModel b, Color statusColor,
      Color payColor, ColorScheme cs) {
    final payLabel = b.paymentStatus.isEmpty
        ? 'Unpaid'
        : b.paymentStatus[0].toUpperCase() + b.paymentStatus.substring(1);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Booking Status',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SERVICE STATUS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          b.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: payColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: payColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PAYMENT STATUS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: payColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (b.isPayOnVisit ? Colors.blue : Colors.purple)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    b.isPayOnVisit ? Icons.handshake_outlined : Icons.lock_clock,
                    size: 16,
                    color: b.isPayOnVisit
                        ? Colors.blue.shade800
                        : Colors.purple.shade800,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Payment Method: ${b.paymentMethodFullLabel}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: b.isPayOnVisit
                            ? Colors.blue.shade800
                            : Colors.purple.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedStaffCard(ServiceBookingModel b, ColorScheme cs) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_pin_circle_outlined,
                    color: cs.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Assigned Specialist',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (b.hasAssignedStaff) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    child: Text(
                      b.assignedStaffName![0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.assignedStaffName!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (b.assignedStaffRole != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            b.assignedStaffRole!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                        if (b.hasAssignedStaffPhone) ...[
                          const SizedBox(height: 4),
                          Text(
                            b.assignedStaffPhone!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (b.hasAssignedStaffPhone)
                    ElevatedButton.icon(
                      onPressed: () => _callPhone(b.assignedStaffPhone!),
                      icon: const Icon(Icons.call, size: 16),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'A certified orchard specialist will be assigned shortly before your scheduled visit. You will receive an SMS and their contact info will appear here.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(ServiceBookingModel b, ColorScheme cs) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Schedule & Service Scope',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            _infoRow(
              icon: Icons.calendar_today,
              label: 'Scheduled Date',
              value: formatDate(b.bookingDate),
              cs: cs,
            ),
            const SizedBox(height: 8),
            _infoRow(
              icon: Icons.access_time,
              label: 'Time Slot',
              value: b.timeSlotLabel,
              cs: cs,
            ),
            if (b.formattedScope != null) ...[
              const SizedBox(height: 8),
              _infoRow(
                icon: Icons.grass,
                label: 'Service Scope',
                value: b.formattedScope!,
                cs: cs,
              ),
            ],
            if (b.createdAt != null) ...[
              const SizedBox(height: 8),
              _infoRow(
                icon: Icons.history,
                label: 'Booked On',
                value: formatDate(b.createdAt!),
                cs: cs,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(ServiceBookingModel b, ColorScheme cs) {
    final hasAddress = b.address != null && b.address!.trim().isNotEmpty;
    final hasCoords = b.latitude != null && b.longitude != null;
    final hasNotes = b.notes != null && b.notes!.trim().isNotEmpty;
    final hasOrchardDetails =
        b.orchardDetails != null && b.orchardDetails!.trim().isNotEmpty;

    if (!hasAddress && !hasCoords && !hasNotes && !hasOrchardDetails) {
      return const SizedBox.shrink();
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Farm Location & Notes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (hasCoords)
                  TextButton.icon(
                    onPressed: () => _openMap(b.latitude!, b.longitude!),
                    icon: const Icon(Icons.map, size: 16),
                    label: const Text('Open Map', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (hasAddress)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b.address!,
                      style: const TextStyle(fontSize: 13, height: 1.3),
                    ),
                  ),
                ],
              ),
            if (hasCoords) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.my_location, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'GPS: ${b.latitude!.toStringAsFixed(5)}, ${b.longitude!.toStringAsFixed(5)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
            if (hasOrchardDetails) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orchard Requirements',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b.orchardDetails!,
                      style: const TextStyle(fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
            if (hasNotes) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${b.notes!}',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(ServiceBookingModel b, ColorScheme cs) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment & Charges',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            _quoteRow('Base Service Charge', formatCurrency(b.baseCharge)),
            if (b.travelCharge > 0)
              _quoteRow(
                b.distanceKm > 0
                    ? 'Travel Charge (${b.distanceKm.toStringAsFixed(1)} km)'
                    : 'Travel Charge',
                formatCurrency(b.travelCharge),
              ),
            const Divider(height: 20),
            _quoteRow(
              'Total Amount',
              formatCurrency(b.totalAmount),
              bold: true,
              highlighted: true,
              color: cs.primary,
            ),
            const SizedBox(height: 10),
            _quoteRow('Payment Method', b.paymentMethodLabel),
            _quoteRow(
              'Payment Status',
              b.paymentStatus.toUpperCase(),
              bold: true,
              color: _paymentStatusColor(b.paymentStatus),
            ),
            if (b.razorpayOrderId != null && b.razorpayOrderId!.isNotEmpty)
              _quoteRow('Razorpay Order ID', b.razorpayOrderId!),
            if (b.razorpayPaymentId != null &&
                b.razorpayPaymentId!.isNotEmpty)
              _quoteRow('Payment Reference', b.razorpayPaymentId!),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme cs,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _quoteRow(String label, String value,
      {bool bold = false, bool highlighted = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color ?? Colors.grey[800])),
          Text(value,
              style: TextStyle(
                  fontSize: highlighted ? 15 : 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  color: color ?? Colors.grey[800])),
        ],
      ),
    );
  }

  Widget _servicePlaceholder(ColorScheme cs) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.construction, color: cs.primary, size: 32),
    );
  }
}
