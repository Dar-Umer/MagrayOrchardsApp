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
  final _quantityController = TextEditingController(text: '1');
  int _quantity = 1;

  Map<String, Map<String, dynamic>> _availability = {};
  bool _loadingAvailability = true;

  double? _latitude;
  double? _longitude;
  bool _gettingLocation = false;
  bool _fetchingQuote = false;
  Map<String, dynamic>? _quote;

  bool _isBooking = false;
  String _paymentMethod = 'visit'; // 'visit' = Pay on Visit, 'online' = Pay Online Now

  static double _asDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static const Map<String, String> _timeSlotLabels = {
    'morning': 'Morning (8 AM - 12 PM)',
    'afternoon': 'Afternoon (12 PM - 4 PM)',
    'evening': 'Evening (4 PM - 7 PM)',
  };

  @override
  void initState() {
    super.initState();
    _quantity = widget.service.minQty;
    _quantityController.text = _quantity.toString();
    _loadAvailability();
    if (widget.service.isZeroTravel || widget.service.isFlatTravel) {
      _fetchQuote();
    }
  }

  @override
  void dispose() {
    _orchardDetailsController.dispose();
    _addressController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _updateQuantity(int newQty) {
    final min = widget.service.minQty;
    final max = widget.service.maxQty ?? 999999;
    final sanitized = newQty.clamp(min, max);
    if (_quantity != sanitized) {
      setState(() {
        _quantity = sanitized;
        _quantityController.text = sanitized.toString();
      });
      _fetchQuote();
    }
  }

  void _onQuantityTextChanged(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null && parsed > 0 && parsed != _quantity) {
      setState(() {
        _quantity = parsed;
      });
      _fetchQuote();
    }
  }

  Future<void> _loadAvailability() async {
    try {
      final map = await ApiService.fetchAvailabilityRange(
        serviceId: widget.service.id,
        serviceSlug: widget.service.slug,
      );
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
    final isPerKm = widget.service.isPerKmTravel;
    if (isPerKm && (_latitude == null || _longitude == null)) {
      return;
    }
    setState(() => _fetchingQuote = true);
    try {
      final data = await ApiService.fetchQuote(
        widget.service.slug,
        latitude: _latitude,
        longitude: _longitude,
        quantity: _quantity,
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
    if (_quote != null) {
      return _asDouble(_quote!['total_amount']);
    }
    final base = widget.service.basePrice * _quantity;
    if (widget.service.isFlatTravel) {
      final flat = widget.service.flatTravelCharge ?? 100.0;
      return base + flat;
    }
    return base;
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
          'Booking #$bookingId reserved! Online payment is pending (${formatCurrency(amount)}). You can pay on visit or retry from My Bookings.'),
      backgroundColor: Colors.orange.shade800,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'VIEW',
        textColor: Colors.white,
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

    final service = widget.service;
    if (service.isQuantityOrAreaBased) {
      if (_quantity < service.minQty) {
        _toast(
          'Minimum ${service.quantityFieldLabel.toLowerCase()} is ${service.minQty} ${service.quantityUnitNoun}.',
          color: Colors.orange,
        );
        return;
      }
      if (service.maxQty != null && _quantity > service.maxQty!) {
        _toast(
          'Maximum ${service.quantityFieldLabel.toLowerCase()} is ${service.maxQty} ${service.quantityUnitNoun}.',
          color: Colors.orange,
        );
        return;
      }
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
        quantity: _quantity,
        paymentMethod: _paymentMethod,
      );

      final bookingId = int.tryParse(booking['id']?.toString() ?? '') ?? 0;
      final amount = _asDouble(booking['total_amount'], _totalAmount);

      if (!mounted) return;

      if (_paymentMethod == 'visit') {
        setState(() => _isBooking = false);
        _toast(
          'Booking confirmed (#$bookingId)! Pay ${formatCurrency(amount)} upon orchard visit.',
          color: Colors.green,
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
        );
        return;
      }

      // Online payment via Razorpay
      try {
        final result = await BookingPayment.start(
          bookingId: bookingId,
          description: '${widget.service.name} booking',
          customerName: auth.user?.name,
          customerEmail: auth.user?.email,
          customerPhone: auth.user?.phone,
        );

        if (!mounted) return;
        setState(() => _isBooking = false);

        switch (result) {
          case BookingPaymentResult.success:
            _toast(
              'Booking confirmed! Payment of ${formatCurrency(amount)} received.',
              color: Colors.green,
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
            );
          case BookingPaymentResult.cancelled:
          case BookingPaymentResult.failed:
            _showPaymentPending(bookingId, amount);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
            );
        }
      } catch (payError) {
        if (!mounted) return;
        setState(() => _isBooking = false);
        // Booking record was already preserved in DB
        _showPaymentPending(bookingId, amount);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        _toast(
          e is ApiException
              ? e.message
              : 'Could not create booking. Please check your network and try again.',
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
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: cs.primary)),
                if (service.unitSuffix.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(service.unitSuffix,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700)),
                ],
                if (service.unitDisplay.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      service.unitDisplay,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ),
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
                  Icon(
                    service.isZeroTravel
                        ? Icons.check_circle_outline
                        : Icons.local_shipping,
                    size: 16,
                    color: service.isZeroTravel ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      service.travelChargeDescription,
                      style: TextStyle(
                        color: service.isZeroTravel ? Colors.green.shade800 : Colors.grey[700],
                        fontSize: 13,
                        fontWeight: service.isZeroTravel ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
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
                    if (service.isQuantityOrAreaBased) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildQuantitySection(cs),
                    ],
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
                        labelText: 'Orchard Details & Notes',
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
            const SizedBox(height: 16),
            _buildQuoteCard(cs),
            const SizedBox(height: 16),
            _buildPaymentMethodSection(cs),
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
                        _paymentMethod == 'visit'
                            ? 'Confirm Booking — ${formatCurrency(_totalAmount)}'
                            : 'Pay Online — ${formatCurrency(_totalAmount)}',
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

  Widget _buildQuantitySection(ColorScheme cs) {
    final service = widget.service;
    final basePresets = service.isPerTree
        ? [10, 25, 50, 100, 200, 500]
        : service.isPerKanal
            ? [2, 4, 8, 12, 16, 24, 40]
            : service.isPerAcre
                ? [1, 2, 5, 10]
                : [1, 2, 3, 5];

    final validPresets = <int>{service.minQty};
    for (final p in basePresets) {
      if (p >= service.minQty &&
          (service.maxQty == null || p <= service.maxQty!)) {
        validPresets.add(p);
      }
    }
    if (service.maxQty != null && service.maxQty! <= 500) {
      validPresets.add(service.maxQty!);
    }
    final presets = validPresets.toList()..sort();

    final canDecrease = _quantity > service.minQty;
    final canIncrease =
        service.maxQty == null || _quantity < service.maxQty!;
    final step = service.isPerTree ? 5 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              service.quantityFieldLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            if (service.isPerKanal)
              Text(
                '1 Acre = 8 Kanals',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        if (service.hasLimit) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 13, color: cs.primary),
              const SizedBox(width: 4),
              Text(
                'Booking Limit: ${service.limitsDisplay}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: canDecrease ? cs.primary : Colors.grey.shade400,
              onPressed: canDecrease
                  ? () => _updateQuantity(
                      (_quantity - step) < service.minQty
                          ? service.minQty
                          : _quantity - step)
                  : null,
            ),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: _onQuantityTextChanged,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: canIncrease ? cs.primary : Colors.grey.shade400,
              onPressed: canIncrease
                  ? () => _updateQuantity(
                      service.maxQty != null && (_quantity + step) > service.maxQty!
                          ? service.maxQty!
                          : _quantity + step)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$_quantity ${service.quantityUnitNoun} × ${formatCurrency(service.basePrice)} = ${formatCurrency(_quantity * service.basePrice)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: presets.map((preset) {
            final isSelected = _quantity == preset;
            return ChoiceChip(
              label: Text(
                service.isPerKanal
                    ? (preset == 8 ? '8 Kanals (1 Acre)' : '$preset Kanals')
                    : service.isPerTree
                        ? '$preset Trees'
                        : service.isPerAcre
                            ? '$preset Acres'
                            : '$preset',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              selected: isSelected,
              selectedColor: cs.primary,
              backgroundColor: cs.primary.withValues(alpha: 0.08),
              onSelected: (_) => _updateQuantity(preset),
            );
          }).toList(),
        ),
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

    final hasTravel = widget.service.isTravel;
    final hasQuote = _quote != null;

    final base = hasTravel && hasQuote
        ? _asDouble(_quote!['base_charge'], widget.service.basePrice * _quantity)
        : widget.service.basePrice * _quantity;
    final travel = hasTravel && hasQuote
        ? _asDouble(_quote!['travel_charge'], 0.0)
        : 0.0;
    final total = hasTravel && hasQuote
        ? _asDouble(_quote!['total_amount'], base)
        : base;
    final distance = hasTravel && hasQuote
        ? _asDouble(_quote!['distance_km'], 0.0)
        : 0.0;
    final estimated = hasTravel && hasQuote && _quote!['estimated'] == true;

    final serviceLabel = widget.service.isQuantityOrAreaBased
        ? 'Service fee ($_quantity ${widget.service.quantityUnitNoun} @ ${formatCurrency(widget.service.basePrice)})'
        : 'Service fee';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Price Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            _quoteRow(serviceLabel, formatCurrency(base)),
            if (widget.service.isZeroTravel)
              _quoteRow('Travel Charge', 'Free (Included)'),
            if (widget.service.isFlatTravel)
              _quoteRow('Travel Charge (Flat)', formatCurrency(travel > 0 ? travel : (widget.service.flatTravelCharge ?? 100.0))),
            if (widget.service.isPerKmTravel && hasQuote && travel > 0)
              _quoteRow(
                'Travel (${distance.toStringAsFixed(1)} km)',
                formatCurrency(travel),
              ),
            if (widget.service.isPerKmTravel && !hasQuote) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Distance-based travel charges will be calculated after setting your farm location above.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 20),
            _quoteRow(widget.service.isPerKmTravel && !hasQuote ? 'Subtotal (excl. travel)' : 'Total Amount',
                formatCurrency(total),
                bold: true, highlighted: true),
            if (estimated) ...[
              const SizedBox(height: 6),
              const Text(
                'Distance is an estimate and the final travel charge may vary slightly.',
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

  Widget _buildPaymentMethodSection(ColorScheme cs) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Method',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => _paymentMethod = 'visit'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _paymentMethod == 'visit'
                        ? cs.primary
                        : Colors.grey.shade300,
                    width: _paymentMethod == 'visit' ? 2 : 1,
                  ),
                  color: _paymentMethod == 'visit'
                      ? cs.primary.withValues(alpha: 0.05)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Icon(
                      _paymentMethod == 'visit'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color:
                          _paymentMethod == 'visit' ? cs.primary : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Pay on Visit (Cash / UPI)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border:
                                      Border.all(color: Colors.green.shade200),
                                ),
                                child: Text(
                                  'Recommended',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Inspect the work at your orchard first, then pay in cash or UPI.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => _paymentMethod = 'online'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _paymentMethod == 'online'
                        ? cs.primary
                        : Colors.grey.shade300,
                    width: _paymentMethod == 'online' ? 2 : 1,
                  ),
                  color: _paymentMethod == 'online'
                      ? cs.primary.withValues(alpha: 0.05)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Icon(
                      _paymentMethod == 'online'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color:
                          _paymentMethod == 'online' ? cs.primary : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pay Online Now',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Instant confirmation via UPI, Credit/Debit Card or NetBanking.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
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
