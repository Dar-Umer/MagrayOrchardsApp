import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_box.dart';
import '../config/api_config.dart';
import '../models/service_booking.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/booking_payment.dart';
import '../utils/formatters.dart';
import 'booking_detail_screen.dart';
import 'login_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  static const _statuses = ['All', 'Pending', 'Confirmed', 'In Progress', 'Completed', 'Cancelled'];

  List<ServiceBookingModel> _bookings = [];
  bool _loading = true;
  String? _error;
  int? _payingId;
  String? _statusFilter;
  String _searchQuery = '';
  final _searchController = TextEditingController();

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
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Login to view your bookings',
          message: 'Sign in to check scheduled visits and payments',
          actionLabel: 'Login',
          actionIcon: Icons.login,
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: _buildBody(cs),
    );
  }

  List<ServiceBookingModel> get _filteredBookings {
    return _bookings.where((b) {
      if (_statusFilter != null && b.status.toLowerCase() != _statusFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return b.serviceName.toLowerCase().contains(q) ||
            '${b.id}'.contains(q) ||
            (b.address?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: const ShimmerCardList(itemCount: 4, itemHeight: 148),
        ),
      );
    }

    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load bookings',
        message: _error,
        actionLabel: 'Try Again',
        onAction: _loadBookings,
      );
    }

    if (_bookings.isEmpty) {
      return const EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'No bookings yet',
        message: 'Book a service to see it here',
      );
    }

    final filtered = _filteredBookings;

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _statuses.map((label) {
                        final normalized = label.toLowerCase().replaceAll(' ', '_');
                        final isActive =
                            (label == 'All' && _statusFilter == null) ||
                                _statusFilter == normalized;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            selected: isActive,
                            onSelected: (_) => setState(() {
                              _statusFilter = label == 'All' ? null : normalized;
                            }),
                            selectedColor: cs.primary.withValues(alpha: 0.15),
                            checkmarkColor: cs.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search by service or address...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.search_off,
                    title: 'No bookings match your filters',
                    message: 'Try a different status or search term',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildBookingCard(filtered[index], cs),
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
    final date = booking.bookingDate;
    final canPay = !booking.isPaid && !booking.isCancelled;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookingDetailScreen(booking: booking),
            ),
          );
          if (mounted) {
            _loadBookings();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Booking Number & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          booking.bookingNumber,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (booking.formattedScope != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          booking.formattedScope!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      booking.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Middle: Service Name & Schedule (List Type)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.construction, color: cs.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.serviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 12, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              formatDate(date),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.access_time,
                                size: 12, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                booking.timeSlotLabel.split('(').first.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                ],
              ),

              if (booking.hasAssignedStaff) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_pin_circle_outlined,
                          size: 14, color: Colors.green.shade800),
                      const SizedBox(width: 6),
                      Text(
                        'Assigned: ${booking.assignedStaffName!}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 20),

              // Bottom Row: Price, Payment Status & Method
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        formatCurrency(booking.totalAmount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: payColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          payLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: payColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        booking.isPayOnVisit ? 'Pay on Visit' : 'Paid Online',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• Details',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (canPay) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: _payingId == booking.id
                        ? null
                        : () => _payNow(booking),
                    icon: _payingId == booking.id
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.payment, size: 14),
                    label: const Text('Pay Online Now',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ],
          ),
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
