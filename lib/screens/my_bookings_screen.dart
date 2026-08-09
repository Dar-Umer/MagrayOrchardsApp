import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/empty_state.dart';
import '../config/api_config.dart';
import '../models/service_booking.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/booking_payment.dart';
import 'login_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<ServiceBookingModel> _bookings = [];
  bool _loading = true;
  String? _error;
  int? _payingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        _loadBookings();
      } else {
        setState(() => _loading = false);
      }
    });
  }

  Future<void> _loadBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bookings = await ApiService.fetchMyBookings();
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException
              ? e.message
              : 'Could not load your bookings. Please try again.';
          _loading = false;
        });
      }
    }
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
      case 'completed':
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

  void _toast(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color ?? Theme.of(context).colorScheme.primary,
    ));
  }

  Future<void> _payNow(ServiceBookingModel booking) async {
    final auth = context.read<AuthProvider>();
    setState(() => _payingId = booking.id);
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
          _toast('Payment successful! Booking confirmed.');
          await _loadBookings();
        case BookingPaymentResult.cancelled:
          _toast('Payment cancelled.', color: Colors.orange);
        case BookingPaymentResult.failed:
          _toast('Payment could not be completed. Please try again.',
              color: Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _toast(
          e is ApiException ? e.message : 'Could not initiate payment.',
          color: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _payingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Bookings')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Login to view your bookings',
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
      appBar: AppBar(title: const Text('My Bookings')),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadBookings,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_bookings.isEmpty) {
      return const EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'No bookings yet',
        message: 'Book a service to see it here',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length,
        itemBuilder: (context, index) =>
            _buildBookingCard(_bookings[index], cs),
      ),
    );
  }

  Widget _buildBookingCard(ServiceBookingModel booking, ColorScheme cs) {
    final statusColor = _statusColor(booking.status);
    final payColor = _paymentStatusColor(booking.paymentStatus);
    final payLabel = booking.paymentStatus.isEmpty
        ? 'Pending'
        : booking.paymentStatus[0].toUpperCase() +
            booking.paymentStatus.substring(1);
    final imageUrl = booking.serviceImage != null
        ? '${ApiConfig.imageBaseUrl}${booking.serviceImage}'
        : null;
    final date = booking.bookingDate;
    final canPay = !booking.isPaid && !booking.isCancelled;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
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
                      ? Image.network(imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(cs))
                      : _placeholder(cs),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.serviceName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.event, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${date.day}/${date.month}/${date.year}',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(booking.timeSlotLabel,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[700])),
                          ),
                        ],
                      ),
                      if (booking.address != null &&
                          booking.address!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(booking.address!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey[700])),
                            ),
                          ],
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        booking.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
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
                          decoration: BoxDecoration(
                              color: payColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(payLabel,
                            style: TextStyle(
                                fontSize: 10, color: payColor)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Total: ',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                Text(
                  '₹${booking.totalAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: cs.primary),
                ),
              ],
            ),
            if (canPay) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _payingId == booking.id
                      ? null
                      : () => _payNow(booking),
                  icon: _payingId == booking.id
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.payment, size: 16),
                  label: const Text('Pay Now',
                      style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.construction, color: cs.primary, size: 28),
    );
  }
}
