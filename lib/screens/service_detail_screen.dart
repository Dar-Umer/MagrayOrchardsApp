import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../models/service_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/booking_payment.dart';
import '../services/location_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_network_image.dart';
import '../widgets/app_quantity_input.dart';
import 'login_screen.dart';
import 'my_bookings_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  final ServiceModel service;

  const ServiceDetailScreen({super.key, required this.service});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  late ServiceModel _service;
  bool _loadingFullService = false;

  DateTime? _selectedDate;
  final _orchardDetailsController = TextEditingController();
  final _addressController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  int _quantity = 1;

  // Multi-tier plant variety and age group batches
  final List<TreeInventoryItem> _treeInventory = [];
  final List<TextEditingController> _inventoryControllers = [];

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

  @override
  void initState() {
    super.initState();
    _service = widget.service;
    _quantity = _service.minQty;
    _quantityController.text = _quantity.toString();

    // Default select tomorrow or today
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day + (now.hour >= 18 ? 1 : 0));

    // Populate from pre-detected GPS location if available
    final loc = LocationService.instance;
    if (loc.hasLocation) {
      _latitude = loc.latitude;
      _longitude = loc.longitude;
      _addressController.text = loc.address ?? '';
    }

    _loadFullService();
    _loadAvailability();
    _fetchQuote();

    // Auto-detect GPS location in background if not yet set for travel services
    if (_service.isTravel && (_latitude == null || _longitude == null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoDetectLocation();
      });
    }
  }

  @override
  void dispose() {
    _orchardDetailsController.dispose();
    _addressController.dispose();
    _quantityController.dispose();
    for (final c in _inventoryControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFullService() async {
    setState(() => _loadingFullService = true);
    try {
      final full = await ApiService.fetchServiceDetail(_service.slug);
      if (mounted) {
        setState(() {
          _service = full;
          if (_service.hasTierRates && _treeInventory.isEmpty) {
            _initDefaultTreeInventory();
          }
        });
        _fetchQuote();
      }
    } catch (_) {
      if (_service.hasTierRates && _treeInventory.isEmpty) {
        _initDefaultTreeInventory();
      }
    } finally {
      if (mounted) setState(() => _loadingFullService = false);
    }
  }

  void _ensureInventoryControllers() {
    while (_inventoryControllers.length < _treeInventory.length) {
      final item = _treeInventory[_inventoryControllers.length];
      _inventoryControllers.add(TextEditingController(text: item.quantity.toString()));
    }
    while (_inventoryControllers.length > _treeInventory.length) {
      _inventoryControllers.removeLast().dispose();
    }
  }

  void _initDefaultTreeInventory() {
    for (final c in _inventoryControllers) {
      c.dispose();
    }
    _inventoryControllers.clear();
    _treeInventory.clear();

    final plantType = _service.plantTypes.isNotEmpty ? _service.plantTypes.first : null;
    final ageGroup = _service.plantAgeGroups.isNotEmpty ? _service.plantAgeGroups.first : null;

    final initialQty = _service.minQty > 1 ? _service.minQty : 25;
    _treeInventory.add(TreeInventoryItem(
      plantTypeId: plantType?.id,
      plantTypeName: plantType?.name ?? 'High-Density Apple',
      plantAgeGroupId: ageGroup?.id,
      plantAgeGroupName: ageGroup?.name ?? '1st Year',
      quantity: initialQty,
      ratePerUnit: _lookupTierRate(plantType?.id, ageGroup?.id),
    ));
    _inventoryControllers.add(TextEditingController(text: initialQty.toString()));
    _syncInventoryQuantity();
  }

  double _lookupTierRate(int? plantTypeId, int? ageGroupId) {
    if (plantTypeId != null && ageGroupId != null) {
      for (final tier in _service.tierRates) {
        if (tier.plantTypeId == plantTypeId && tier.plantAgeGroupId == ageGroupId) {
          return tier.pricePerUnit;
        }
      }
    }
    return _service.basePrice;
  }

  void _syncInventoryQuantity() {
    if (_treeInventory.isEmpty) return;
    int total = 0;
    for (final item in _treeInventory) {
      total += item.quantity;
      item.ratePerUnit = _lookupTierRate(item.plantTypeId, item.plantAgeGroupId);
    }
    setState(() {
      _quantity = total;
      _quantityController.text = total.toString();
    });
  }

  void _addTreeInventoryBatch() {
    final plantType = _service.plantTypes.isNotEmpty ? _service.plantTypes.first : null;
    final ageGroup = _service.plantAgeGroups.length > 1
        ? _service.plantAgeGroups[1]
        : (_service.plantAgeGroups.isNotEmpty ? _service.plantAgeGroups.first : null);

    const initialQty = 25;
    setState(() {
      _treeInventory.add(TreeInventoryItem(
        plantTypeId: plantType?.id,
        plantTypeName: plantType?.name ?? 'Traditional Apple Trees',
        plantAgeGroupId: ageGroup?.id,
        plantAgeGroupName: ageGroup?.name ?? '2nd Year',
        quantity: initialQty,
        ratePerUnit: _lookupTierRate(plantType?.id, ageGroup?.id),
      ));
      _inventoryControllers.add(TextEditingController(text: initialQty.toString()));
    });
    _syncInventoryQuantity();
    _fetchQuote();
  }

  void _removeTreeInventoryBatch(int index) {
    if (_treeInventory.length <= 1) return;
    setState(() {
      _treeInventory.removeAt(index);
      if (index < _inventoryControllers.length) {
        _inventoryControllers.removeAt(index).dispose();
      }
    });
    _syncInventoryQuantity();
    _fetchQuote();
  }

  Future<void> _loadAvailability() async {
    try {
      final map = await ApiService.fetchAvailabilityRange(
        serviceId: _service.id,
        serviceSlug: _service.slug,
        latitude: _latitude,
        longitude: _longitude,
      );
      if (mounted) {
        setState(() => _availability = map);
      }
    } catch (_) {
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
      lastDate: DateTime.now().add(const Duration(days: 30)),
      selectableDayPredicate: _isDateOpen,
    );
    if (date != null && mounted) {
      setState(() => _selectedDate = date);
      _fetchQuote();
    }
  }

  Future<void> _autoDetectLocation() async {
    setState(() => _gettingLocation = true);
    try {
      final loc = LocationService.instance;
      final ok = await loc.promptAndDetectLocation(context, showGpsDialog: true);
      if (ok && loc.hasLocation && mounted) {
        setState(() {
          _latitude = loc.latitude;
          _longitude = loc.longitude;
          _addressController.text = loc.address ?? '';
        });
        await _fetchQuote();
        await _loadAvailability();
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _useGps() async {
    setState(() => _gettingLocation = true);
    try {
      final loc = LocationService.instance;
      final ok = await loc.promptAndDetectLocation(context, force: true, showGpsDialog: true);
      if (ok && loc.hasLocation && mounted) {
        setState(() {
          _latitude = loc.latitude;
          _longitude = loc.longitude;
          _addressController.text = loc.address ?? '';
        });
        await _fetchQuote();
        await _loadAvailability();
      } else if (loc.lastError != null && mounted) {
        _toast(loc.lastError!, color: Colors.orange);
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _searchAddress() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) {
      _toast('Please enter a village, town or address to search.');
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
      LocationService.instance.setManualLocation(_latitude!, _longitude!, _addressController.text);
      await _fetchQuote();
      await _loadAvailability();
    } catch (e) {
      if (mounted) {
        _toast(e is ApiException
            ? e.message
            : 'Could not find that location. Please try a more specific town or village.');
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _fetchQuote() async {
    if (_service.isTravel && !_service.hasTierRates && (_latitude == null || _longitude == null)) {
      return;
    }
    setState(() => _fetchingQuote = true);
    try {
      final treePayload = _service.hasTierRates && _treeInventory.isNotEmpty
          ? _treeInventory.map((i) => i.toJson()).toList()
          : null;

      final data = await ApiService.fetchQuote(
        _service.slug,
        latitude: _latitude,
        longitude: _longitude,
        quantity: _quantity,
        treeItems: treePayload,
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
            : 'Could not fetch the price quote for your selection.');
      }
    } finally {
      if (mounted) setState(() => _fetchingQuote = false);
    }
  }

  double get _totalAmount {
    if (_quote != null) {
      return _asDouble(_quote!['total_amount']);
    }
    return _service.basePrice * _quantity;
  }

  void _toast(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color ?? Theme.of(context).colorScheme.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  void _showPaymentPending(int bookingId, double amount) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Booking #$bookingId reserved! Online payment is pending (${formatCurrency(amount)}). You can complete payment from My Bookings.'),
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
    if (_selectedDate == null) {
      _toast('Please pick your preferred service date above.', color: Colors.orange);
      return;
    }
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      _toast('Please login to confirm your service booking', color: Colors.orange);
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    if (_service.isTravel &&
        (_latitude == null ||
            _longitude == null ||
            _addressController.text.trim().isEmpty)) {
      _toast(
        'Please set your farm location so we can dispatch the team.',
        color: Colors.orange,
      );
      return;
    }

    if (_service.isQuantityOrAreaBased) {
      if (_quantity < _service.minQty) {
        _toast(
          'Minimum selection for ${_service.name} is ${_service.minQty} ${_service.quantityUnitNoun}.',
          color: Colors.orange,
        );
        return;
      }
      if (_service.maxQty != null && _quantity > _service.maxQty!) {
        _toast(
          'Maximum selection for ${_service.name} is ${_service.maxQty} ${_service.quantityUnitNoun}.',
          color: Colors.orange,
        );
        return;
      }
    }

    setState(() => _isBooking = true);

    try {
      final details = _orchardDetailsController.text.trim();
      final treePayload = _service.hasTierRates && _treeInventory.isNotEmpty
          ? _treeInventory.map((i) => i.toJson()).toList()
          : null;

      final booking = await ApiService.createServiceBooking(
        slug: _service.slug,
        bookingDate: _selectedDate!,
        timeSlot: 'full_day',
        latitude: _latitude,
        longitude: _longitude,
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        notes: details.isEmpty ? null : details,
        quantity: _quantity,
        treeItems: treePayload,
        paymentMethod: _paymentMethod,
      );

      final bookingId = int.tryParse(booking['id']?.toString() ?? '') ?? 0;
      final amount = _asDouble(booking['total_amount'], _totalAmount);

      if (!mounted) return;

      if (_paymentMethod == 'visit') {
        setState(() => _isBooking = false);
        _toast(
          'Booking #$bookingId confirmed! Pay ${formatCurrency(amount)} upon visit.',
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
          description: '${_service.name} booking',
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

  void _updateQuantity(int q) {
    int clamped = q;
    if (clamped < _service.minQty) clamped = _service.minQty;
    if (_service.maxQty != null && clamped > _service.maxQty!) clamped = _service.maxQty!;
    setState(() {
      _quantity = clamped;
      _quantityController.text = clamped.toString();
    });
    _fetchQuote();
  }

  // ─── UI BUILD ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final service = _service;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          service.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        actions: [
          if (_loadingFullService || _fetchingQuote)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Compact Hero Header
                _buildHeroHeader(cs),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. Step 1: Select Service Date
                      _buildDateSelectionCard(cs),
                      const SizedBox(height: 14),

                      // 3. Step 2: Plant Varieties & Scope
                      if (service.hasTierRates) ...[
                        _buildMultiTierInventorySection(cs),
                        const SizedBox(height: 14),
                      ] else if (service.isQuantityOrAreaBased) ...[
                        _buildSingleQuantityCard(cs),
                        const SizedBox(height: 14),
                      ],

                      // 4. Step 3: Farm Location & District
                      if (service.isTravel) ...[
                        _buildLocationCard(cs),
                        const SizedBox(height: 14),
                      ],

                      // 5. Step 4: Special Notes & Payment Method
                      _buildDetailsAndPaymentCard(cs),
                      const SizedBox(height: 14),

                      // 6. Step 5: Itemized Price Summary
                      _buildPriceSummary(cs),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Sticky Bottom Bar — Never hunt for the price or CTA button!
      bottomNavigationBar: _buildStickyBottomBar(cs),
    );
  }

  // ─── 1. COMPACT HERO HEADER ───────────────────────────────────────────────

  Widget _buildHeroHeader(ColorScheme cs) {
    final service = _service;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image (Compact & Rounded)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 180,
              color: const Color(0xFFF1F5F9),
              child: service.image != null
                  ? AppNetworkImage(
                      imageUrl: '${ApiConfig.imageBaseUrl}${service.image}',
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Icon(
                        Icons.eco_rounded,
                        size: 64,
                        color: cs.primary.withValues(alpha: 0.3),
                      ),
                    )
                  : Icon(
                      Icons.eco_rounded,
                      size: 64,
                      color: cs.primary.withValues(alpha: 0.3),
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // Service Title (Spacious & Clean)
          Text(
            service.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),

          // Price Line (Naturally placed under title with proper breathing room)
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatCurrency(service.basePrice),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                service.unitSuffix.isNotEmpty ? service.unitSuffix : '/ tree',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              if (service.hasTierRates) ...[
                const SizedBox(width: 8),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFF94A3B8),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Rates vary by tree variety & age',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),

          // Clean Description Paragraph
          if (service.description != null && service.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              service.description!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 2. STEP 1: SELECT SERVICE DATE ────────────────────────────────────────

  Widget _buildDateSelectionCard(ColorScheme cs) {
    final now = DateTime.now();
    // 14 upcoming days
    final upcomingDays = List.generate(14, (i) {
      return DateTime(now.year, now.month, now.day + (now.hour >= 18 ? i + 1 : i));
    });

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Service Date',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
                TextButton(
                  onPressed: _pickDate,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Other Dates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Horizontal Date Carousel
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: upcomingDays.length,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final d = upcomingDays[index];
                  final isOpen = _isDateOpen(d);
                  final isSelected = _selectedDate != null &&
                      _selectedDate!.year == d.year &&
                      _selectedDate!.month == d.month &&
                      _selectedDate!.day == d.day;

                  final dayOfWeek = _weekdayShort(d.weekday);
                  final monthName = _monthShort(d.month);

                  return InkWell(
                    onTap: isOpen
                        ? () {
                            setState(() => _selectedDate = d);
                            _fetchQuote();
                          }
                        : null,
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 58,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primary
                            : (isOpen ? Colors.grey.shade50 : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? cs.primary
                              : (isOpen ? Colors.grey.shade300 : Colors.grey.shade200),
                          width: isSelected ? 1.8 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayOfWeek,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white70
                                  : (isOpen ? Colors.grey.shade600 : Colors.grey.shade400),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isOpen ? const Color(0xFF1E293B) : Colors.grey.shade400),
                            ),
                          ),
                          Text(
                            monthName,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? Colors.white70
                                  : (isOpen ? Colors.grey.shade500 : Colors.grey.shade400),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Dispatch notice (clean text, no loud emoji or icons)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                _selectedDate != null
                    ? 'Scheduled for ${_formatFullDate(_selectedDate!)} • Full-day orchard dispatch'
                    : 'Select a date above for orchard specialist dispatch',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3. STEP 2: MULTI-TIER TREE BATCHES (ZERO OVERFLOWS) ───────────────────

  Widget _buildMultiTierInventorySection(ColorScheme cs) {
    _ensureInventoryControllers();
    final plantTypes = _service.plantTypes;
    final ageGroups = _service.plantAgeGroups;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tree Varieties & Quantities',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '$_quantity Trees Total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Enter tree count for each variety and age stage in your orchard',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),

            // Itemized Tree Batch Cards
            ..._treeInventory.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Variety ${idx + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const Spacer(),
                        if (_treeInventory.length > 1)
                          InkWell(
                            onTap: () => _removeTreeInventoryBatch(idx),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                'Remove',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Plant Kind Dropdown
                    DropdownButtonFormField<int>(
                      initialValue: item.plantTypeId ?? (plantTypes.isNotEmpty ? plantTypes.first.id : null),
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Tree Variety',
                        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: plantTypes.map((pt) {
                        return DropdownMenuItem<int>(
                          value: pt.id,
                          child: Text(
                            pt.name,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final pt = plantTypes.firstWhere((p) => p.id == val);
                          setState(() {
                            item.plantTypeId = pt.id;
                            item.plantTypeName = pt.name;
                            _syncInventoryQuantity();
                          });
                          _fetchQuote();
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // Age Group Dropdown
                    DropdownButtonFormField<int>(
                      initialValue: item.plantAgeGroupId ?? (ageGroups.isNotEmpty ? ageGroups.first.id : null),
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Age Stage / Growth Phase',
                        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: ageGroups.map((ag) {
                        return DropdownMenuItem<int>(
                          value: ag.id,
                          child: Text(
                            ag.name,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final ag = ageGroups.firstWhere((a) => a.id == val);
                          setState(() {
                            item.plantAgeGroupId = ag.id;
                            item.plantAgeGroupName = ag.name;
                            _syncInventoryQuantity();
                          });
                          _fetchQuote();
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Stepper & Live Subtotal Row using unified AppQuantityInput
                    Row(
                      children: [
                        AppQuantityInput(
                          value: item.quantity,
                          quickIncrements: const [25],
                          onChanged: (newQty) {
                            setState(() {
                              item.quantity = newQty;
                              if (idx < _inventoryControllers.length) {
                                _inventoryControllers[idx].text = newQty.toString();
                              }
                              _syncInventoryQuantity();
                            });
                            _fetchQuote();
                          },
                        ),
                        const Spacer(),

                        // Subtotal (Flexible to prevent any right overflow)
                        Flexible(
                          child: Text(
                            '@ ${formatCurrency(item.ratePerUnit)} = ${formatCurrency(item.quantity * item.ratePerUnit)}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            // Add Variety Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _addTreeInventoryBatch,
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.primary,
                  side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: const Text(
                  '+ Add Another Tree Variety',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SINGLE QUANTITY STEPPER (NON-TIER SERVICES) ──────────────────────────

  Widget _buildSingleQuantityCard(ColorScheme cs) {
    final service = _service;
    final presets = service.isPerTree
        ? [10, 25, 50, 100, 200, 500]
        : [1, 2, 5, 10];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              service.quantityFieldLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                AppQuantityInput(
                  value: _quantity,
                  min: service.minQty,
                  max: service.maxQty ?? 100000,
                  step: service.isPerTree ? 5 : 1,
                  unitSuffix: service.quantityUnitNoun,
                  onChanged: (newQty) {
                    _updateQuantity(newQty);
                  },
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '$_quantity × ${formatCurrency(service.basePrice)} = ${formatCurrency(_quantity * service.basePrice)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: presets.map((p) {
                final isSelected = _quantity == p;
                return ChoiceChip(
                  label: Text('$p ${service.quantityUnitNoun}'),
                  selected: isSelected,
                  onSelected: (_) => _updateQuantity(p),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 4. STEP 3: FARM LOCATION & DISTRICT ZONE ──────────────────────────────

  Widget _buildLocationCard(ColorScheme cs) {
    final zoneName = _quote?['zone_name']?.toString();
    final districtCode = _quote?['district_code']?.toString();
    final isFreeTravel = _quote?['is_free_travel'] == true;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Orchard Location',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Technicians are dispatched based on your district zone',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),

            // One-Tap GPS Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _gettingLocation ? null : _useGps,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: _gettingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _latitude != null ? 'Update GPS Location' : 'Detect GPS Location',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
              ),
            ),
            const SizedBox(height: 10),

            // Or Manual Address Search
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Or search village, town or landmark',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _gettingLocation ? null : _searchAddress,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  ),
                  child: const Text('Search', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            // Location Verified Banner
            if (_latitude != null && _longitude != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          zoneName != null
                              ? (districtCode != null ? '$districtCode • $zoneName' : zoneName)
                              : 'Location Verified',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF166534),
                          ),
                        ),
                        const Spacer(),
                        if (isFreeTravel)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF166534),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'FREE TRAVEL',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _addressController.text.isNotEmpty
                          ? _addressController.text
                          : '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
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

  // ─── 5. STEP 4: NOTES & PAYMENT CHOICE ────────────────────────────────────

  Widget _buildDetailsAndPaymentCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment & Instructions',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),

            // Instructions textfield
            TextField(
              controller: _orchardDetailsController,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Orchard Notes / Landmark (Optional)',
                labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                hintText: 'e.g. Near high school gate, tree row markers...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),

            // Payment method selector
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                // Option A: Pay on Visit
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _paymentMethod = 'visit'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _paymentMethod == 'visit'
                            ? cs.primary.withValues(alpha: 0.05)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _paymentMethod == 'visit' ? cs.primary : const Color(0xFFE2E8F0),
                          width: _paymentMethod == 'visit' ? 1.8 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pay on Visit',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _paymentMethod == 'visit' ? cs.primary : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cash or UPI upon visit',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Option B: Pay Online
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _paymentMethod = 'online'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _paymentMethod == 'online'
                            ? cs.primary.withValues(alpha: 0.05)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _paymentMethod == 'online' ? cs.primary : const Color(0xFFE2E8F0),
                          width: _paymentMethod == 'online' ? 1.8 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pay Online',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _paymentMethod == 'online' ? cs.primary : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Instant via UPI / Card',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── 6. STEP 5: ITEMIZED PRICE SUMMARY ────────────────────────────────────

  Widget _buildPriceSummary(ColorScheme cs) {
    final hasQuote = _quote != null;

    final base = hasQuote
        ? _asDouble(_quote!['base_charge'], _service.basePrice * _quantity)
        : _service.basePrice * _quantity;
    final travel = hasQuote
        ? _asDouble(_quote!['travel_charge'], 0.0)
        : 0.0;
    final total = hasQuote
        ? _asDouble(_quote!['total_amount'], base + travel)
        : base;
    final distance = hasQuote
        ? _asDouble(_quote!['distance_km'], 0.0)
        : 0.0;
    final estimated = hasQuote && _quote!['estimated'] == true;
    final zoneName = _quote?['zone_name']?.toString();
    final travelDesc = _quote?['travel_description']?.toString();
    final isFreeTravel = _quote?['is_free_travel'] == true || _service.isZeroTravel;
    final treeBreakdown = _quote?['tree_breakdown'] is List
        ? (_quote!['tree_breakdown'] as List)
        : null;

    final bool isPhysical = _service.isPhysical;
    final bool showSubtotalOnly = !hasQuote && isPhysical && !_service.isZeroTravel;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Price Summary',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (zoneName != null && zoneName.isNotEmpty)
                  Text(
                    '📍 $zoneName',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Itemized breakdown if multi-tier
            if (treeBreakdown != null && treeBreakdown.isNotEmpty) ...[
              ...treeBreakdown.map((item) {
                final pt = item['plant_type_name'] ?? 'Kind';
                final ag = item['plant_age_group_name'] ?? 'Age';
                final qty = item['quantity'] ?? 0;
                final rate = _asDouble(item['rate_per_unit']);
                final sub = _asDouble(item['subtotal']);
                return _quoteRow(
                  '$pt ($ag) × $qty @ ${formatCurrency(rate)}',
                  formatCurrency(sub),
                );
              }),
              const Divider(height: 12),
              _quoteRow('Total Tree Services', formatCurrency(base)),
            ] else ...[
              _quoteRow('Service fee ($_quantity ${_service.quantityUnitNoun})', formatCurrency(base)),
            ],

            // Travel Charge Row
            if (!isPhysical) ...[
              _quoteRow('Travel Charge', 'Free', subtext: 'Virtual Consultation (no visit required)'),
            ] else if (_latitude == null || _longitude == null) ...[
              if (_service.isZeroTravel)
                _quoteRow('Travel Charge', 'Free', subtext: 'Promotional waiver applied')
              else if (_gettingLocation || LocationService.instance.isLocating)
                _quoteRow(
                  'Travel Charge',
                  'Calculating...',
                  subtext: 'Detecting your orchard GPS location in background',
                )
              else
                _quoteRow(
                  'Travel Charge',
                  'Pending Location',
                  subtext: 'Set farm location above to calculate district fee',
                ),
            ] else if (hasQuote) ...[
              if (isFreeTravel || travel == 0) ...[
                _quoteRow(
                  'Travel Charge',
                  'Free',
                  subtext: travelDesc,
                ),
              ] else ...[
                _quoteRow(
                  zoneName != null ? 'Travel ($zoneName)' : 'Travel (${distance.toStringAsFixed(1)} km)',
                  formatCurrency(travel),
                  subtext: travelDesc,
                ),
              ],
            ] else ...[
              if (_service.isZeroTravel)
                _quoteRow('Travel Charge', 'Free', subtext: 'Promotional waiver applied')
              else
                _quoteRow(
                  'Travel Charge',
                  'Pending Location',
                  subtext: 'Set farm location above to calculate district fee',
                ),
            ],

            const Divider(height: 18),
            _quoteRow(
              showSubtotalOnly ? 'Subtotal (excl. travel)' : 'Total Amount',
              formatCurrency(total),
              bold: true,
              highlighted: true,
            ),
            if (estimated) ...[
              const SizedBox(height: 4),
              const Text(
                'Distance is an estimate and final travel charge may vary slightly.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── 7. STICKY BOTTOM BAR (NO HUNTING!) ───────────────────────────────────

  Widget _buildStickyBottomBar(ColorScheme cs) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Amount',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
                Text(
                  formatCurrency(_totalAmount),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
                Text(
                  _service.hasTierRates
                      ? '$_quantity trees • Incl. Travel'
                      : 'Tax & Travel inclusive',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _isBooking ? null : _bookNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: _isBooking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Book Service',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  Widget _quoteRow(String label, String value,
      {bool bold = false, bool highlighted = false, String? subtext}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                    color: highlighted ? Theme.of(context).colorScheme.primary : const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w700,
                  color: highlighted ? Theme.of(context).colorScheme.primary : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          if (subtext != null && subtext.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                subtext,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  fontStyle: FontStyle.italic,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _weekdayShort(int weekday) {
    return switch (weekday) {
      DateTime.monday => 'Mon',
      DateTime.tuesday => 'Tue',
      DateTime.wednesday => 'Wed',
      DateTime.thursday => 'Thu',
      DateTime.friday => 'Fri',
      DateTime.saturday => 'Sat',
      DateTime.sunday => 'Sun',
      _ => '',
    };
  }

  static String _monthShort(int month) {
    return switch (month) {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
      4 => 'Apr',
      5 => 'May',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Aug',
      9 => 'Sep',
      10 => 'Oct',
      11 => 'Nov',
      12 => 'Dec',
      _ => '',
    };
  }

  static String _formatFullDate(DateTime d) {
    return '${_weekdayShort(d.weekday)}, ${d.day} ${_monthShort(d.month)} ${d.year}';
  }
}
