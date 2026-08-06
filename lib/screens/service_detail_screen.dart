import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../models/service_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

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
  bool _isBooking = false;

  static const Map<String, String> _timeSlotLabels = {
    'morning': 'Morning (8 AM - 12 PM)',
    'afternoon': 'Afternoon (12 PM - 4 PM)',
    'evening': 'Evening (4 PM - 7 PM)',
  };

  @override
  void dispose() {
    _orchardDetailsController.dispose();
    super.dispose();
  }

  Future<void> _bookService() async {
    if (_selectedDate == null || _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select date and time slot'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login to book services'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    setState(() => _isBooking = true);

    try {
      final dateStr =
          '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
      await ApiService.post('/services/${widget.service.slug}/book', body: {
        'booking_date': dateStr,
        'booking_time': _selectedTimeSlot,
        'notes': _orchardDetailsController.text.trim().isNotEmpty
            ? _orchardDetailsController.text.trim()
            : null,
      });
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Booking request submitted!'),
            backgroundColor: cs.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${e is ApiException ? e.message : 'We couldn\'t complete your booking. Please try again.'}'),
            backgroundColor: Colors.red,
          ),
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
                        errorBuilder: (_, __, ___) => Icon(
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
                    'Rs. ${service.basePrice.toStringAsFixed(0)}',
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
                      leading: Icon(Icons.calendar_today, color: cs.primary),
                      title: Text(_selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Select Date'),
                      subtitle: const Text('Preferred date'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 90)),
                        );
                        if (date != null) setState(() => _selectedDate = date);
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: Icon(Icons.access_time, color: cs.primary),
                      title: Text(_selectedTimeSlot != null
                          ? _timeSlotLabels[_selectedTimeSlot]!
                          : 'Select Time Slot'),
                      subtitle: const Text('Preferred time slot'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonFormField<String>(
                        value: _selectedTimeSlot,
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
                    ),
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isBooking ? null : _bookService,
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
                    : const Text('Book Now',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
