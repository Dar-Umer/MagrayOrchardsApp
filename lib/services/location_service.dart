import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class LocationService extends ChangeNotifier {
  static final LocationService instance = LocationService._internal();

  LocationService._internal() {
    loadCachedLocation();
  }

  double? _latitude;
  double? _longitude;
  String? _address;
  String? _districtZoneName;
  double? _travelCharge;
  bool _isLocating = false;
  String? _lastError;
  bool _hasPromptedThisSession = false;
  Future<bool>? _inFlightDetect;

  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get address => _address;
  String? get districtZoneName => _districtZoneName;
  double? get travelCharge => _travelCharge;
  bool get isLocating => _isLocating;
  String? get lastError => _lastError;
  bool get hasLocation => _latitude != null && _longitude != null;
  bool get hasPromptedThisSession => _hasPromptedThisSession;

  static const _prefLat = 'cached_user_lat';
  static const _prefLng = 'cached_user_lng';
  static const _prefAddress = 'cached_user_address';
  static const _prefDistrict = 'cached_user_district';

  Future<void> loadCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_prefLat);
      final lng = prefs.getDouble(_prefLng);
      final addr = prefs.getString(_prefAddress);
      final dist = prefs.getString(_prefDistrict);

      if (lat != null && lng != null) {
        _latitude = lat;
        _longitude = lng;
        _address = addr;
        _districtZoneName = dist;
        notifyListeners();
        // Recalculate district zone in background if available
        checkDistrictTravel();
      }
    } catch (_) {}
  }

  Future<void> _saveCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_latitude != null && _longitude != null) {
        await prefs.setDouble(_prefLat, _latitude!);
        await prefs.setDouble(_prefLng, _longitude!);
        if (_address != null) await prefs.setString(_prefAddress, _address!);
        if (_districtZoneName != null) {
          await prefs.setString(_prefDistrict, _districtZoneName!);
        }
      }
    } catch (_) {}
  }

  void setManualLocation(double lat, double lng, String addr, [String? district]) {
    _latitude = lat;
    _longitude = lng;
    _address = addr;
    if (district != null) _districtZoneName = district;
    _lastError = null;
    _saveCachedLocation();
    checkDistrictTravel();
    notifyListeners();
  }

  /// Automatically check district travel charges with backend Point-In-Polygon detection
  Future<Map<String, dynamic>?> checkDistrictTravel({String serviceSlug = 'orchard-pruning-service'}) async {
    if (_latitude == null || _longitude == null) return null;
    try {
      final res = await ApiService.fetchQuote(
        serviceSlug,
        latitude: _latitude,
        longitude: _longitude,
        quantity: 10,
      );
      if (res['quote'] is Map) {
        final q = Map<String, dynamic>.from(res['quote'] as Map);
        _districtZoneName = q['zone_name'] as String?;
        if (q['travel_charge'] is num) {
          _travelCharge = (q['travel_charge'] as num).toDouble();
        }
        _saveCachedLocation();
        notifyListeners();
        return q;
      }
    } catch (_) {}
    return null;
  }

  /// Prompts GPS turn-on and detects device coordinates, reverse-geocoding the orchard zone.
  Future<bool> promptAndDetectLocation(
    BuildContext context, {
    bool force = false,
    bool showGpsDialog = true,
  }) {
    if (_inFlightDetect != null) return _inFlightDetect!;
    final future = _doPromptAndDetectLocation(
      context,
      force: force,
      showGpsDialog: showGpsDialog,
    );
    _inFlightDetect = future;
    future.whenComplete(() {
      if (_inFlightDetect == future) {
        _inFlightDetect = null;
      }
    });
    return future;
  }

  Future<bool> _doPromptAndDetectLocation(
    BuildContext context, {
    bool force = false,
    bool showGpsDialog = true,
  }) async {
    if (_hasPromptedThisSession && !force && hasLocation) {
      return true;
    }
    _hasPromptedThisSession = true;

    // 1. Check if device location service is enabled
    bool serviceEnabled = true;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      serviceEnabled = true;
    }

    if (!serviceEnabled && !kIsWeb) {
      if (showGpsDialog && context.mounted) {
        final shouldTurnOn = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on_rounded, color: Color(0xFF991B1B), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Turn On GPS Location',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Please turn on your device GPS location so we can automatically detect your orchard\'s district zone and calculate travel charges accurately.',
              style: TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Not Now', style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.gps_fixed, size: 16),
                label: const Text('Turn On GPS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF991B1B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx, true);
                  try {
                    await Geolocator.openLocationSettings();
                  } catch (_) {}
                },
              ),
            ],
          ),
        );

        if (shouldTurnOn != true) {
          _lastError = 'Location service is disabled.';
          notifyListeners();
          return false;
        }

        // Wait for user to turn on GPS in settings (up to 25s polling)
        _isLocating = true;
        notifyListeners();
        bool isNowEnabled = false;
        for (int i = 0; i < 25; i++) {
          await Future.delayed(const Duration(seconds: 1));
          try {
            if (await Geolocator.isLocationServiceEnabled()) {
              isNowEnabled = true;
              break;
            }
          } catch (_) {}
        }

        if (!isNowEnabled) {
          _isLocating = false;
          _lastError = 'GPS is required to detect orchard zone.';
          notifyListeners();
          return false;
        }
      } else {
        _lastError = 'Location service is disabled.';
        notifyListeners();
        return false;
      }
    }

    // 2. Check and request permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted && showGpsDialog && !kIsWeb) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Location Permission Required'),
            content: const Text(
              'Location permissions are permanently denied. Please enable them in app settings to auto-calculate district travel fees.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await Geolocator.openAppSettings();
                  } catch (_) {}
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      _lastError = 'Location permission permanently denied.';
      notifyListeners();
      return false;
    }

    if (permission == LocationPermission.denied) {
      _lastError = 'Location permission denied.';
      notifyListeners();
      return false;
    }

    // 3. Obtain position
    _isLocating = true;
    _lastError = null;
    notifyListeners();

    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 7),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 8),
          ),
        );
      }

      _latitude = position.latitude;
      _longitude = position.longitude;

      // 4. Reverse Geocode in background to get human readable address & district
      try {
        final geo = await ApiService.reverseGeocode(_latitude!, _longitude!);
        if (geo['address'] is String) {
          _address = geo['address'] as String;
        } else {
          _address = '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}';
        }
      } catch (_) {
        _address = '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}';
      }

      await _saveCachedLocation();

      // 5. Query district travel quote in background
      await checkDistrictTravel();

      _isLocating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLocating = false;
      _lastError = 'Could not fetch GPS location: $e';
      notifyListeners();
      return false;
    }
  }
}
