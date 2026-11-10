import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../models/service_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/booking_payment.dart';
import '../utils/formatters.dart';
import 'login_screen.dart';
import 'my_bookings_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  final ServiceModel service;

  const ServiceDetailScreen({super.key, required this.service});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  final _orchardDetailsController = TextEditingController();
  final _addressController = TextEditingController();

  Map<String, Map<String, dynamic>> _availability = {};
  bool _loadingAvailability = true;

  double? _latitude;
  double? _longitude;
  bool _gettingLocation = false;
  bool _fetchingQuote = false;
  Map<String, dynamic>? _quote;

  bool _isBooking = false;

  static const Map<String, String> _timeSlotLabels = {
    'morning': 'Morning (8 AM - 12 PM)',
    'afternoon': 'Afternoon (12 PM - 4 PM)',
    'evening': 'Evening (4 PM - 7 PM)',
  };

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  @override
  void dispose() {
    _orchardDetailsController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailability() async {
    try {
      final map = await ApiService.fetchAvailabilityRange();
      if (mounted) {
        setState(() => _availability = map);
      }
    } catch (_) {
      // Guests can't fetch availability; the calendar stays fully enabled and
      // the server re-validates when the booking is created.
    } finally {
      if (mounted) {
        setState(() => _loadingAvailability = false);
      }
    }
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isDateOpen(DateTime d) {
    if (_availability.isEmpty) return true;
    final a = _availability[_dateStr(d)];
    return a != null && a['open'] == true;
  }

  bool get _hasAnyOpenDate =>
      _availability.values.any((a) => a['open'] == true);

  String get _dateSubtitle {
    if (_selectedDate == null) return 'Available dates shown in calendar';
    final a = _availability[_dateStr(_selectedDate!)];
    if (a == null) return 'Selected date';
    final rem = a['remaining'];
    if (rem is num) {
      return rem > 0 ? 'Selected date — $rem slot(s) left' : 'Fully booked';
    }
    return 'Selected date';
  }

  Future<void> _pickDate() async {
    if (_loadingAvailability) {
      _toast('Loading available dates...');
      return;
    }
    if (_availability.isNotEmpty && !_hasAnyOpenDate) {
      _toast('No dates are available for booking right now. Please check back later.');
      return;
    }
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 29)),
      selectableDayPredicate: _isDateOpen,
    );
    if (date != null && mounted) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _useGps() async {
    setState(() => _gettingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const FormatException(
            'Location services are disabled. Please enable them and try again.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const FormatException(
            'Location permission is needed to use GPS. Please allow access and try again.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      try {
        final geo = await ApiService.reverseGeocode(_latitude!, _longitude!);
        if (mounted && geo['address'] is String) {
          _addressController.text = geo['address'] as String;
        }
      } catch (_) {
        if (mounted) {
          _addressController.text =
              '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}';
        }
      }
      await _fetchQuote();
    } catch (e) {
      if (mounted) {
        _toast(e is FormatException
            ? e.message
            : 'Could not get your location. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _searchAddress() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) {
      _toast('Please enter an address to search.');
      return;
    }
    setState(() => _gettingLocation = true);
    try {
      final geo = await ApiService.geocodeAddress(query);
      if (!mounted) return;
      setState(() {
        _latitude = (geo['latitude'] as num).toDouble();
        _longitude = (geo['longitude'] as num).toDouble();
        _addressController.text = geo['address'] as String? ?? query;
      });
      await _fetchQuote();
    } catch (e) {
      if (mounted) {
        _toast(e is ApiException
            ? e.message
            : 'Could not find that location. Try a more specific address.');
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _fetchQuote() async {
    if (!widget.service.isTravel ||
        _latitude == null ||
        _longitude == null) {
      return;
    }
    setState(() => _fetchingQuote = true);
    try {
      final data = await ApiService.fetchQuote(
        widget.service.slug,
        latitude: _latitude,
        longitude: _longitude,
      );
      if (mounted && data['quote'] is Map) {
        setState(() =>
            _quote = Map<String, dynamic>.from(data['quote'] as Map));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _quote = null);
        _toast(e is ApiException
            ? e.message
            : 'Could not fetch the price for your location.');
      }
    } finally {
      if (mounted) setState(() => _fetchingQuote = false);
    }
  }

  double get _totalAmount {
    if (widget.service.isTravel && _quote != null) {
      return (_quote!['total_amount'] as num).toDouble();
    }
    return widget.service.basePrice;
  }

  void _toast(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color ?? Theme.of(context).colorScheme.primary,
    ));
  }

  void _showPaymentPending(int bookingId, double amount) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Booking created, but payment is incomplete (${formatCurrency(amount)}). You can pay from My Bookings.'),
      backgroundColor: Colors.orange,
      action: SnackBarAction(
        label: 'VIEW',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
        ),
      ),
    ));
  }

  Future<void> _bookNow() async {
    if (_selectedDate == null || _selectedTimeSlot == null) {
      _toast('Please select a date and time slot.', color: Colors.orange);
      return;
    }
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      _toast('Login to book services', color: Colors.orange);
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    if (widget.service.isTravel &&
        (_latitude == null ||
            _longitude == null ||
            _addressController.text.trim().isEmpty)) {
      _toast(
        'Please set your farm location using GPS or by searching your address.',
        color: Colors.orange,
      );
      return;
    }

    setState(() => _isBooking = true);

    try {
      final details = _orchardDetailsController.text.trim();
      final booking = await ApiService.createServiceBooking(
        slug: widget.service.slug,
        bookingDate: _selectedDate!,
        timeSlot: _selectedTimeSlot!,
        latitude: _latitude,
        longitude: _longitude,
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        notes: details.isEmpty ? null : details,
      );
      final bookingId = booking['id'] as int;
      final amount = (booking['total_amount'] as num).toDouble();
      if (!mounted) return;
      setState(() => _isBooking = false);

      final result = await BookingPayment.start(
        bookingId: bookingId,
        description: '${widget.service.name} booking',
        customerName: auth.user?.name,
        customerEmail: auth.user?.email,
        customerPhone: auth.user?.phone,
      );

      if (!mounted) return;
      switch (result) {
        case BookingPaymentResult.success:
          _toast(
            'Booking confirmed! Payment of ${formatCurrency(amount)} received.',
          );
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MyBookingsScreen()));
        case BookingPaymentResult.cancelled:
          _showPaymentPending(bookingId, amount);
        case BookingPaymentResult.failed:
          _showPaymentPending(bookingId, amount);
      }
    } catch (e) {
      if (mounted) {
        _toast(
          e is ApiException
              ? e.message
              : 'We couldn\'t complete your booking. Please try again.',
          color: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(service.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: service.image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        '${ApiConfig.imageBaseUrl}${service.image}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.construction,
                            size: 80,
                            color: cs.primary),
                      ),
                    )
                  : Icon(Icons.construction,
                      size: 80, color: cs.primary),
            ),
            const SizedBox(height: 16),
            Text(service.name,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                    formatCurrency(service.basePrice),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.primary)),
                if (service.priceUnit != null) ...[
                  const SizedBox(width: 4),
                  Text('/ ${service.priceUnit}',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ],
            ),
            if (service.durationEstimate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(service.durationEstimate!,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ],
            if (service.categoryName != null) ...[
              const SizedBox(height: 8),
              Chip(
                label: Text(service.categoryName!),
                backgroundColor: cs.primary.withValues(alpha: 0.1),
              ),
            ],
            if (service.isTravel) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.local_shipping,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                        'Travel charges apply based on the distance from our base location.',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (service.description != null) ...[
              const Text('Description',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(service.description!,
                  style: const TextStyle(height: 1.5)),
            ],
            const SizedBox(height: 24),
            const Text('Book This Service',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.calendar_today, color: cs.primary),
                      title: Text(_selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Select Date'),
                      subtitle: Text(_dateSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickDate,
                    ),
                    const Divider(),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTimeSlot,
                      decoration: InputDecoration(
                        labelText: 'Time Slot',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      items: _timeSlotLabels.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedTimeSlot = value);
                      },
                    ),
                    if (service.isTravel) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      _buildLocationSection(cs),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: _orchardDetailsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Orchard Details',
                        hintText:
                            'Describe your orchard location and requirements...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (service.isTravel) ...[
              const SizedBox(height: 16),
              _buildQuoteCard(cs),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isBooking ? null : _bookNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isBooking
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        'Book & Pay — ${formatCurrency(_totalAmount)}',
                        style:
                            const TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
        ),
      ),
      ),
    );
  }

  Widget _buildLocationSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Farm Location',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Address',
                  hintText: 'Enter your farm address or search a location',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _gettingLocation ? null : _searchAddress,
                icon: _gettingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search, size: 18),
                label: const Text('Search'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _gettingLocation ? null : _useGps,
                icon: _gettingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.my_location, size: 18, color: cs.primary),
                label: const Text('Use My GPS Location'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        if (_latitude != null && _longitude != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on, size: 14, color: Colors.green[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                  style:
                      TextStyle(fontSize: 12, color: Colors.green.shade700),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildQuoteCard(ColorScheme cs) {
    if (_fetchingQuote) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Calculating price for your location...'),
            ],
          ),
        ),
      );
    }

    if (_quote == null) {
      return Card(
        color: cs.primary.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Set your farm location above to see the travel charge and total price.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final base = (_quote!['base_charge'] as num).toDouble();
    final travel = (_quote!['travel_charge'] as num).toDouble();
    final total = (_quote!['total_amount'] as num).toDouble();
    final distance = (_quote!['distance_km'] as num).toDouble();
    final estimated = _quote!['estimated'] == true;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Price Estimate',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _quoteRow('Base charge', formatCurrency(base)),
            _quoteRow(
              'Travel (${distance.toStringAsFixed(1)} km)',
              formatCurrency(travel),
            ),
            const Divider(height: 20),
            _quoteRow('Total', formatCurrency(total),
                bold: true, highlighted: true),
            if (estimated) ...[
              const SizedBox(height: 6),
              const Text(
                'Distance is an estimate and the final charge may vary slightly.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quoteRow(String label, String value,
      {bool bold = false, bool highlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: highlighted
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[800])),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: highlighted
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[800])),
        ],
      ),
    );
  }
}
