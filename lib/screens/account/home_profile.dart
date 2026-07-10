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
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    
    for (var address in widget.addresses) {
      final String addressId = address['id']?.toString() ?? '';
      if (addressId.isEmpty) continue;

      final storedDataStr = prefs.getString('home_profile_$addressId');
      Map<String, dynamic> data = {
        'sqft': '',
        'yearBuilt': '',
        'bedrooms': '',
        'bathrooms': '',
      };

      if (storedDataStr != null) {
        try {
          data = jsonDecode(storedDataStr);
        } catch (_) {}
      }

      _controllers[addressId] = {
        'sqft': TextEditingController(text: data['sqft']?.toString() ?? ''),
        'yearBuilt': TextEditingController(text: data['yearBuilt']?.toString() ?? ''),
        'bedrooms': TextEditingController(text: data['bedrooms']?.toString() ?? ''),
        'bathrooms': TextEditingController(text: data['bathrooms']?.toString() ?? ''),
      };
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveAllProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    for (var address in widget.addresses) {
      final String addressId = address['id']?.toString() ?? '';
      if (addressId.isEmpty || !_controllers.containsKey(addressId)) continue;

      final ctrls = _controllers[addressId]!;
      final dataToSave = {
        'sqft': ctrls['sqft']!.text,
        'yearBuilt': ctrls['yearBuilt']!.text,
        'bedrooms': ctrls['bedrooms']!.text,
        'bathrooms': ctrls['bathrooms']!.text,
      };

      await prefs.setString('home_profile_$addressId', jsonEncode(dataToSave));
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All Home profiles saved successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    for (var ctrls in _controllers.values) {
      for (var c in ctrls.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.addresses.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppTheme.navy700),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Home profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.navy700)),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        backgroundColor: AppTheme.pageAlt,
        body: const Center(
          child: Text('No addresses added yet.', style: TextStyle(color: AppTheme.gray)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.navy700),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Home profiles',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.navy700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: AppTheme.line, height: 0.5),
        ),
      ),
      backgroundColor: AppTheme.pageAlt,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.navy700))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.addresses.length,
                    itemBuilder: (context, index) {
                      final address = widget.addresses[index];
                      return _buildAddressSection(address);
                    },
                  ),
                ),
                _buildSaveBar(),
              ],
            ),
    );
  }

  Widget _buildAddressSection(dynamic address) {
    final String addressId = address['id']?.toString() ?? '';
    if (!_controllers.containsKey(addressId)) return const SizedBox();

    final ctrls = _controllers[addressId]!;
    final label = address['label'] ?? 'Address';
    final street = address['street'] ?? '';
    final city = address['city'] ?? '';
    final state = address['state'] ?? '';
    final zip = address['zip'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 24, top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Property Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.navy700,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
              ]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '$street, $city, $state $zip',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            child: Text(
              'PROPERTY DETAILS',
              style: TextStyle(color: AppTheme.gray, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.05),
            ),
          ),
          _buildDetailsGrid(ctrls),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            child: Text(
              'HOME SYSTEMS',
              style: TextStyle(color: AppTheme.gray, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.05),
            ),
          ),
          _buildHomeSystemsList(),
        ],
      ),
    );
  }

  Widget _buildDetailsGrid(Map<String, TextEditingController> ctrls) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildGridCell('SQUARE FOOTAGE', ctrls['sqft']!)),
              Container(width: 1, height: 60, color: AppTheme.line),
              Expanded(child: _buildGridCell('YEAR BUILT', ctrls['yearBuilt']!)),
            ],
          ),
          Container(height: 1, color: AppTheme.line),
          Row(
            children: [
              Expanded(child: _buildGridCell('BEDROOMS', ctrls['bedrooms']!)),
              Container(width: 1, height: 60, color: AppTheme.line),
              Expanded(child: _buildGridCell('BATHROOMS', ctrls['bathrooms']!)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridCell(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: AppTheme.gray, fontWeight: FontWeight.bold, letterSpacing: 0.05),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 32,
            child: TextField(
              controller: controller,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.navy700),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '-',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeSystemsList() {
    final systems = [
      {
        'title': 'Central HVAC',
        'desc': 'Update age or type',
        'icon': Icons.ac_unit,
      },
      {
        'title': 'Water heater',
        'desc': 'Update age or type',
        'icon': Icons.water_drop,
      },
      {
        'title': 'Roof',
        'desc': 'Update age or type',
        'icon': Icons.roofing,
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: systems.map((sys) {
          final isLast = systems.indexOf(sys) == systems.length - 1;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: isLast ? null : const Border(bottom: BorderSide(color: AppTheme.line)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.pageAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(sys['icon'] as IconData, size: 20, color: AppTheme.navy700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sys['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.navy700)),
                      const SizedBox(height: 2),
                      Text(sys['desc'] as String, style: const TextStyle(fontSize: 12, color: AppTheme.gray)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.gray, size: 20),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSaveBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _saveAllProfiles,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.orange500,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          'Save all changes',
          style: TextStyle(
            color: AppTheme.navy700,
            fontWeight: FontWeight.bold,
            fontSize: 14.5,
          ),
        ),
      ),
    );
  }
}
