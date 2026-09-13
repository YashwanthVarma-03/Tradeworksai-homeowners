import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The device-level service area used by both Home and Browse.
class ServiceLocation {
  const ServiceLocation({required this.zip, required this.locationName});

  static const _zipKey = 'selected_service_zip';
  static const _locationNameKey = 'selected_service_location_name';
  static final ValueNotifier<ServiceLocation?> selected =
      ValueNotifier<ServiceLocation?>(null);

  final String zip;
  final String locationName;

  static Future<ServiceLocation?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final zip = prefs.getString(_zipKey)?.trim() ?? '';
    if (!RegExp(r'^\d{5}$').hasMatch(zip)) return null;

    final location = ServiceLocation(
      zip: zip,
      locationName: prefs.getString(_locationNameKey)?.trim() ?? '',
    );
    selected.value = location;
    return location;
  }

  static Future<void> save({
    required String zip,
    required String locationName,
  }) async {
    final normalizedZip = zip.trim();
    if (!RegExp(r'^\d{5}$').hasMatch(normalizedZip)) return;

    final normalizedName = locationName.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_zipKey, normalizedZip);
    await prefs.setString(_locationNameKey, normalizedName);
    selected.value = ServiceLocation(
      zip: normalizedZip,
      locationName: normalizedName,
    );
  }
}
