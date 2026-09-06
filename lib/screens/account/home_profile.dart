import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme.dart';

class HomeProfileScreen extends StatefulWidget {
  final List<dynamic> addresses;

  const HomeProfileScreen({
    super.key,
    required this.addresses,
  });

  @override
  State<HomeProfileScreen> createState() => _HomeProfileScreenState();
}

class _HomeProfileScreenState extends State<HomeProfileScreen> {
  static const Color _pageBackground = Color(0xFFF5F7FA);
  static const Color _inkStrong = Color(0xFF1E293B);
  static const Color _mutedText = Color(0xFF64748B);
  static const Color _lineSoft = Color(0xFFE1E7EF);

  final Map<String, Map<String, TextEditingController>> _controllers = {};
  final Map<String, List<Map<String, dynamic>>> _systemsByAddress = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    for (final ctrls in _controllers.values) {
      for (final ctrl in ctrls.values) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();

    for (final dynamic item in widget.addresses) {
      final address = _asMap(item);
      final addressId = _string(address['id']) ?? '';
      if (addressId.isEmpty) continue;

      final storedDataStr = prefs.getString('home_profile_$addressId');
      Map<String, dynamic> storedData = const {};
      if (storedDataStr != null && storedDataStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(storedDataStr);
          storedData = _asMap(decoded);
        } catch (_) {}
      }

      _controllers[addressId] = {
        'sqft': TextEditingController(
          text: _valueFor(address, storedData, const [
            'sqft',
            'squareFootage',
            'square_footage',
            'squareFeet',
          ]),
        ),
        'yearBuilt': TextEditingController(
          text: _valueFor(address, storedData, const [
            'yearBuilt',
            'year_built',
          ]),
        ),
        'bedrooms': TextEditingController(
          text: _valueFor(address, storedData, const ['bedrooms']),
        ),
        'bathrooms': TextEditingController(
          text: _valueFor(address, storedData, const ['bathrooms']),
        ),
      };
      _systemsByAddress[addressId] = _extractSystems(address);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveAllProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    for (final dynamic item in widget.addresses) {
      final address = _asMap(item);
      final addressId = _string(address['id']) ?? '';
      if (addressId.isEmpty || !_controllers.containsKey(addressId)) continue;
      final ctrls = _controllers[addressId]!;
      await prefs.setString(
        'home_profile_$addressId',
        jsonEncode({
          'sqft': ctrls['sqft']!.text.trim(),
          'yearBuilt': ctrls['yearBuilt']!.text.trim(),
          'bedrooms': ctrls['bedrooms']!.text.trim(),
          'bathrooms': ctrls['bathrooms']!.text.trim(),
        }),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Home profile saved'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: _appBar('Home profile'),
      body: widget.addresses.isEmpty
          ? _emptyState()
          : _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.orange500),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 124),
                  children: widget.addresses
                      .map((dynamic item) => _addressSection(_asMap(item)))
                      .toList(),
                ),
      bottomNavigationBar: widget.addresses.isEmpty ? null : _saveBar(),
    );
  }

  PreferredSizeWidget _appBar(String title) {
    return AppBar(
      toolbarHeight: 56,
      backgroundColor: Colors.white,
      elevation: 0,
      leadingWidth: 54,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, size: 25),
        color: AppTheme.navy700,
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.navy700,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _lineSoft),
      ),
    );
  }

  Widget _addressSection(Map<String, dynamic> address) {
    final addressId = _string(address['id']) ?? '';
    final ctrls = _controllers[addressId];
    if (ctrls == null) return const SizedBox.shrink();
    final systems = _systemsByAddress[addressId] ?? const [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _propertyHero(address),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _sectionLabel('PROPERTY DETAILS')),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.teal500,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: const Text('Edit'),
              ),
            ],
          ),
          _detailsGrid(ctrls),
          const SizedBox(height: 14),
          _sectionLabel('HOME SYSTEMS'),
          const SizedBox(height: 8),
          if (systems.isEmpty)
            _noSystemsCard()
          else
            ...systems.map(
              (system) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _systemCard(system),
              ),
            ),
          _addSystemButton(),
          const SizedBox(height: 12),
          _infoCallout(),
        ],
      ),
    );
  }

  Widget _propertyHero(Map<String, dynamic> address) {
    final label = _string(address['label']) ?? 'Home';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
      decoration: BoxDecoration(
        color: AppTheme.navy700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _string(address['street']) ?? label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _subtitleForAddress(address),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsGrid(Map<String, TextEditingController> ctrls) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.7,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: [
        _detailCell('Square footage', ctrls['sqft']!),
        _detailCell('Year built', ctrls['yearBuilt']!),
        _detailCell('Bedrooms', ctrls['bedrooms']!),
        _detailCell('Bathrooms', ctrls['bathrooms']!),
      ],
    );
  }

  Widget _detailCell(String label, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLines: 1,
            style: const TextStyle(
              color: _inkStrong,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
            decoration: const InputDecoration(
              isDense: true,
              hintText: '-',
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _systemCard(Map<String, dynamic> system) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _lineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFE7F7F8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _systemIcon(_string(system['type']) ?? _string(system['name'])),
              color: AppTheme.teal500,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _string(system['name']) ??
                      _string(system['title']) ??
                      _string(system['type']) ??
                      'Home system',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _inkStrong,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                    const SizedBox(height: 3),
                Text(
                  _systemSubtitle(system),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.teal500,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _noSystemsCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _lineSoft),
      ),
      child: const Text(
        'No home systems saved yet.',
        style: TextStyle(
          color: _mutedText,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _addSystemButton() {
    return TextButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add system is not available yet.'),
            backgroundColor: AppTheme.gray,
          ),
        );
      },
      style: TextButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: AppTheme.teal500,
        padding: EdgeInsets.zero,
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
      ),
      child: const Text('+ Add system'),
    );
  }

  Widget _infoCallout() {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAFBFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.teal500),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.trending_up_rounded, color: AppTheme.teal500, size: 25),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'We use your home profile to suggest timely maintenance and pre-fill your bookings.',
              style: TextStyle(
                color: _inkStrong,
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _mutedText,
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.6,
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home_outlined, color: AppTheme.navy700, size: 42),
            SizedBox(height: 12),
            Text(
              'No addresses added yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _inkStrong,
              fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _lineSoft)),
      ),
      child: ElevatedButton(
        onPressed: _saveAllProfiles,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.orange500,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Save home profile',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  String _subtitleForAddress(Map<String, dynamic> address) {
    final type =
        _string(address['propertyType']) ?? _string(address['homeType']);
    final city = _string(address['city']);
    final state = _string(address['state']);
    final zip = _string(address['zip']);
    final location = [city, state, zip].whereType<String>().join(', ');
    return [type, location].whereType<String>().join(' · ');
  }

  String _systemSubtitle(Map<String, dynamic> system) {
    final parts = <String>[
      if (_string(system['age']) != null) '~${_string(system['age'])}',
      if (_string(system['lastService']) != null)
        'last service ${_string(system['lastService'])}',
      if (_string(system['capacity']) != null) _string(system['capacity'])!,
      if (_string(system['fuel']) != null) _string(system['fuel'])!,
    ];
    return parts.isEmpty ? 'Saved system' : parts.join(' · ');
  }

  IconData _systemIcon(String? value) {
    final lower = value?.toLowerCase() ?? '';
    if (lower.contains('water')) return Icons.water_drop_outlined;
    if (lower.contains('roof')) return Icons.home_outlined;
    if (lower.contains('heat') || lower.contains('hvac')) {
      return Icons.air_outlined;
    }
    return Icons.home_repair_service_outlined;
  }

  List<Map<String, dynamic>> _extractSystems(Map<String, dynamic> address) {
    final raw = address['systems'] ??
        address['homeSystems'] ??
        address['home_systems'] ??
        _asMap(address['propertyProfile'])['systems'] ??
        _asMap(address['property_profile'])['systems'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _valueFor(
    Map<String, dynamic> address,
    Map<String, dynamic> stored,
    List<String> keys,
  ) {
    for (final key in keys) {
      final storedValue = _string(stored[key]);
      if (storedValue != null) return storedValue;
    }
    for (final key in keys) {
      final addressValue = _string(address[key]);
      if (addressValue != null) return addressValue;
    }
    return '';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String? _string(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }
}
