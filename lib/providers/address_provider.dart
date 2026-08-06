import 'package:flutter/material.dart';
import '../models/address.dart';
import '../services/api_service.dart';

class AddressProvider extends ChangeNotifier {
  List<Address> _addresses = [];
  bool _isLoading = false;
  int? _selectedAddressId;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  void clearError() { _errorMessage = null; notifyListeners(); }

  List<Address> get addresses => _addresses;
  bool get isLoading => _isLoading;
  Address? get defaultAddress =>
      _addresses.where((a) => a.isDefault).firstOrNull;
  Address? get selectedAddress {
    if (_selectedAddressId != null) {
      final match = _addresses.where((a) => a.id == _selectedAddressId);
      if (match.isNotEmpty) return match.first;
    }
    return defaultAddress;
  }

  void selectAddress(int id) {
    _selectedAddressId = id;
    notifyListeners();
  }

  Future<void> fetchAddresses() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.get('/addresses');
      final data = response['data'] ?? response;
      _addresses = (data as List).map((a) => Address.fromJson(a)).toList();
      if (_selectedAddressId == null && _addresses.isNotEmpty) {
        final defaultAddr = _addresses.where((a) => a.isDefault).firstOrNull;
        _selectedAddressId = defaultAddr?.id ?? _addresses.first.id;
      }
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not load your addresses.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addAddress({
    required String name,
    required String phone,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String state,
    required String pincode,
    required String country,
    bool isDefault = false,
  }) async {
    try {
      final response = await ApiService.post('/addresses', body: {
        'name': name,
        'phone': phone,
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'city': city,
        'state': state,
        'pincode': pincode,
        'country': country,
        'is_default': isDefault,
      });
      final address = Address.fromJson(response['data']);
      _addresses.add(address);
      if (isDefault) {
        for (var a in _addresses) {
          if (a.id != address.id) {
            // rebuild list to reflect default change
          }
        }
        _addresses = _addresses.map((a) => Address(
          id: a.id, name: a.name, phone: a.phone,
          addressLine1: a.addressLine1, addressLine2: a.addressLine2,
          city: a.city, state: a.state, pincode: a.pincode,
          country: a.country,
          isDefault: a.id == address.id,
        )).toList();
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not save address. Please check all fields and try again.';
      return false;
    }
  }

  Future<bool> updateAddress(int id, {
    required String name,
    required String phone,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String state,
    required String pincode,
    required String country,
    bool isDefault = false,
  }) async {
    try {
      final response = await ApiService.put('/addresses/$id', body: {
        'name': name,
        'phone': phone,
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'city': city,
        'state': state,
        'pincode': pincode,
        'country': country,
        'is_default': isDefault,
      });
      final updated = Address.fromJson(response['data']);
      final index = _addresses.indexWhere((a) => a.id == id);
      if (index >= 0) _addresses[index] = updated;
      if (isDefault) {
        _addresses = _addresses.map((a) => Address(
          id: a.id, name: a.name, phone: a.phone,
          addressLine1: a.addressLine1, addressLine2: a.addressLine2,
          city: a.city, state: a.state, pincode: a.pincode,
          country: a.country,
          isDefault: a.id == id,
        )).toList();
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not update address. Please try again.';
      return false;
    }
  }

  Future<bool> deleteAddress(int id) async {
    try {
      await ApiService.delete('/addresses/$id');
      _addresses.removeWhere((a) => a.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not delete address. Please try again.';
      return false;
    }
  }
}
