import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/address.dart';
import '../providers/address_provider.dart';

class AddressFormScreen extends StatefulWidget {
  final Address? address;

  const AddressFormScreen({super.key, this.address});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _line1Controller;
  late final TextEditingController _line2Controller;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _countryController;
  bool _isDefault = false;
  bool _isSaving = false;

  bool get isEditing => widget.address != null;

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    _nameController = TextEditingController(text: a?.name ?? '');
    _phoneController = TextEditingController(text: a?.phone ?? '');
    _line1Controller = TextEditingController(text: a?.addressLine1 ?? '');
    _line2Controller = TextEditingController(text: a?.addressLine2 ?? '');
    _cityController = TextEditingController(text: a?.city ?? '');
    _stateController = TextEditingController(text: a?.state ?? '');
    _pincodeController = TextEditingController(text: a?.pincode ?? '');
    _countryController = TextEditingController(text: a?.country ?? 'India');
    _isDefault = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final provider = context.read<AddressProvider>();
    bool success;
    if (isEditing) {
      success = await provider.updateAddress(
        widget.address!.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        addressLine1: _line1Controller.text.trim(),
        addressLine2: _line2Controller.text.trim().isNotEmpty
            ? _line2Controller.text.trim()
            : null,
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        country: _countryController.text.trim(),
        isDefault: _isDefault,
      );
    } else {
      success = await provider.addAddress(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        addressLine1: _line1Controller.text.trim(),
        addressLine2: _line2Controller.text.trim().isNotEmpty
            ? _line2Controller.text.trim()
            : null,
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        country: _countryController.text.trim(),
        isDefault: _isDefault,
      );
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Address updated' : 'Address added'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Could not save address. Please check all fields and try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Address' : 'Add Address'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildField(_nameController, 'Full Name', Icons.person_outlined),
              const SizedBox(height: 12),
              _buildField(_phoneController, 'Phone', Icons.phone_outlined,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _buildField(_line1Controller, 'Address Line 1', Icons.home_outlined),
              const SizedBox(height: 12),
              _buildField(
                  _line2Controller, 'Address Line 2 (Optional)', Icons.home,
                  required: false),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildField(
                          _cityController, 'City', Icons.location_city)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildField(
                          _stateController, 'State', Icons.map_outlined)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildField(
                          _pincodeController, 'Pincode', Icons.pin_drop_outlined,
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildField(_countryController, 'Country', Icons.flag)),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Set as Default'),
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isEditing ? 'Update Address' : 'Add Address',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: required
          ? (v) => v == null || v.isEmpty ? '$label is required' : null
          : null,
    );
  }
}
