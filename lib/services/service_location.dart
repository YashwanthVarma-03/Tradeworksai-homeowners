import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ServiceLocationNotifier extends ValueNotifier<ServiceLocation?> {
  _ServiceLocationNotifier() : super(null);

  void refresh() => notifyListeners();
}

/// A temporary service area shared by Home and Browse for the current session.
///
/// Saved addresses remain the source of truth for authenticated homeowners.
/// This value only carries a ZIP that the user explicitly entered to the next
/// search surface; it must never become a persisted default.
class ServiceLocation {
  const ServiceLocation({required this.zip, required this.locationName});

  static const _zipKey = 'selected_service_zip';
  static const _locationNameKey = 'selected_service_location_name';
  static final _ServiceLocationNotifier _selected = _ServiceLocationNotifier();
  static ValueNotifier<ServiceLocation?> get selected => _selected;

  final String zip;
  final String locationName;

  static Future<ServiceLocation?> load() async {
    // Intentionally ignore legacy SharedPreferences values. A ZIP selected in
    // an earlier app session must not become a default for a guest or override
    // an authenticated homeowner's primary address.
    return selected.value;
  }

  static Future<void> save({
    required String zip,
    required String locationName,
  }) async {
    final normalizedZip = zip.trim();
    if (!RegExp(r'^\d{5}$').hasMatch(normalizedZip)) return;

    final normalizedName = locationName.trim();
    selected.value = ServiceLocation(
      zip: normalizedZip,
      locationName: normalizedName,
    );
  }

  static Future<void> clear() async {
    final hadTemporaryLocation = selected.value != null;
    selected.value = null;
    if (!hadTemporaryLocation) {
      // A page change must also tell authenticated Browse screens to refetch
      // the primary address when there was no active override to clear.
      _selected.refresh();
    }

    // Clean up values written by older builds so they cannot be restored if a
    // user upgrades or later runs a build that still knows about these keys.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_zipKey);
    await prefs.remove(_locationNameKey);
  }
}
