import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';

class ProfileTab extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback onRewardsTap;

  const ProfileTab({
    super.key,
    required this.onLogout,
    required this.onRewardsTap,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _pushNotifications = true;

  // Home profile fields that can be edited and saved
  String _sqft = '2,100';
  String _yearBuilt = '2008';
  String _bedrooms = '4';
  String _bathrooms = '2.5';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 2. Account Header Card
          _buildAccountHeader(),
          const Divider(height: 1),

          // 3. Service Credits Link Card
          _buildCreditsLink(),
          const Divider(height: 1),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 11.0),
            child: Text(
              'ACCOUNT',
              style: TextStyle(color: AppTheme.gray, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.07),
            ),
          ),

          // 4. Personal Info
          _buildSettingsRow(
            icon: Icons.person_outline,
            title: 'Personal info',
            subtitle: 'Yashwanth Varma · (813) 555-0148',
            onTap: _editPersonalInfo,
          ),

          // 5. Addresses
          _buildSettingsRow(
            icon: Icons.location_on_outlined,
            title: 'Addresses',
            subtitle: 'Home · 123 Palm Way, Riverview · +1 more',
            onTap: _manageAddresses,
          ),

          // 6. Payment methods
          _buildSettingsRow(
            icon: Icons.credit_card_outlined,
            title: 'Payment methods',
            subtitle: 'Visa ending 4921 · pay the pro at booking',
            onTap: _managePayments,
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 11.0),
            child: Text(
              'YOUR HOME',
              style: TextStyle(color: AppTheme.gray, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.07),
            ),
          ),

          // 7. Home profile sub-screen trigger
          _buildSettingsRow(
            icon: Icons.home_outlined,
            title: 'Home profile',
            subtitle: 'Single-family · 2,100 sq ft · powers maintenance',
            onTap: _openHomeProfileScreen,
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 11.0),
            child: Text(
              'NOTIFICATIONS',
              style: TextStyle(color: AppTheme.gray, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.07),
            ),
          ),

          // 8. Push toggle
          _buildToggleRow(
            icon: Icons.notifications_none_outlined,
            title: 'Push notifications',
            subtitle: 'Status updates, messages, credits · email too',
            value: _pushNotifications,
            onChanged: (val) {
              setState(() {
                _pushNotifications = val;
              });
            },
          ),

          const SizedBox(height: 12),

          // 9. Sign out
          _buildSignOutRow(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAccountHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: AppTheme.navy700,
            child: Text(
              'YV',
              style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yashwanth Varma',
                  style: AppTheme.headingStyle.copyWith(fontSize: 16, color: AppTheme.navy700),
                ),
                const SizedBox(height: 2),
                const Text(
                  'yashwanth.varma@example.com',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.gray),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.tealTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Homeowner · since 2024',
                    style: TextStyle(color: Color(0xFF1F6F93), fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.line),
        ],
      ),
    );
  }

  Widget _buildCreditsLink() {
    return GestureDetector(
      onTap: widget.onRewardsTap,
      child: Container(
        color: AppTheme.orangeTint,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                  child: const Icon(Icons.stars, color: AppTheme.orange500, size: 19),
                ),
                const SizedBox(width: 11),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service credits',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.navy700),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Display-only · redeem on Rewards',
                      style: TextStyle(color: AppTheme.gray, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  '\$420',
                  style: AppTheme.headingStyle.copyWith(fontSize: 16, color: AppTheme.orange500, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: AppTheme.orange500, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.navyTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.navy700, size: 19),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.ink),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Text(
            subtitle,
            style: const TextStyle(color: AppTheme.gray, fontSize: 11.5),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.line, size: 18),
        onTap: onTap,
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.navyTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.navy700, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppTheme.gray, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppTheme.teal500,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutRow() {
    return GestureDetector(
      onTap: widget.onLogout,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF7E4E4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.exit_to_app, color: Color(0xFFB23535), size: 19),
            ),
            const SizedBox(width: 12),
            const Text(
              'Sign out',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFB23535)),
            ),
          ],
        ),
      ),
    );
  }

  void _editPersonalInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Personal Info', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: Yashwanth Varma', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Phone: (813) 555-0148'),
            Text('Email: yashwanth.varma@example.com'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _manageAddresses() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Service Addresses', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Primary: 123 Palm Way, Riverview FL 33578', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('2. Rental: 904 Meridian Blvd, Riverview FL 33578'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _managePayments() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Saved Card: Visa ending 4921.\n\nNote: You pay the contractor directly at the completion of your job. TradeWorks AI charges a \$0 platform fee.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openHomeProfileScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeProfileScreen(
          sqft: _sqft,
          yearBuilt: _yearBuilt,
          bedrooms: _bedrooms,
          bathrooms: _bathrooms,
          onSave: (sqft, year, beds, baths) {
            setState(() {
              _sqft = sqft;
              _yearBuilt = year;
              _bedrooms = beds;
              _bathrooms = baths;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Home profile saved successfully!'),
                backgroundColor: AppTheme.success,
              ),
            );
          },
        ),
      ),
    );
  }
}

class HomeProfileScreen extends StatefulWidget {
  final String sqft;
  final String yearBuilt;
  final String bedrooms;
  final String bathrooms;
  final Function(String, String, String, String) onSave;

  const HomeProfileScreen({
    super.key,
    required this.sqft,
    required this.yearBuilt,
    required this.bedrooms,
    required this.bathrooms,
    required this.onSave,
  });

  @override
  State<HomeProfileScreen> createState() => _HomeProfileScreenState();
}

class _HomeProfileScreenState extends State<HomeProfileScreen> {
  late final TextEditingController _sqftController;
  late final TextEditingController _yearController;
  late final TextEditingController _bedsController;
  late final TextEditingController _bathsController;

  @override
  void initState() {
    super.initState();
    _sqftController = TextEditingController(text: widget.sqft);
    _yearController = TextEditingController(text: widget.yearBuilt);
    _bedsController = TextEditingController(text: widget.bedrooms);
    _bathsController = TextEditingController(text: widget.bathrooms);
  }

  @override
  void dispose() {
    _sqftController.dispose();
    _yearController.dispose();
    _bedsController.dispose();
    _bathsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.navy700),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Home profile',
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 12. Property Card
                  _buildPropertyCard(),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                    child: Text(
                      'PROPERTY DETAILS',
                      style: TextStyle(color: AppTheme.gray, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.05),
                    ),
                  ),

                  // 13. Details Form Inputs Grid
                  _buildDetailsGrid(),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                    child: Text(
                      'HOME SYSTEMS',
                      style: TextStyle(color: AppTheme.gray, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.05),
                    ),
                  ),

                  // 14. Home Systems
                  _buildHomeSystemsList(),


                ],
              ),
            ),
          ),
          // 16. Save bar
          _buildSaveBar(),
        ],
      ),
    );
  }

  Widget _buildPropertyCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '123 Palm Way',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy700),
          ),
          SizedBox(height: 4),
          Text(
            'Single-family home · Riverview, FL 33578',
            style: TextStyle(fontSize: 12, color: AppTheme.gray),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsGrid() {
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
              Expanded(child: _buildGridCell('SQUARE FOOTAGE', _sqftController)),
              Container(width: 1, height: 60, color: AppTheme.line),
              Expanded(child: _buildGridCell('YEAR BUILT', _yearController)),
            ],
          ),
          Container(height: 1, color: AppTheme.line),
          Row(
            children: [
              Expanded(child: _buildGridCell('BEDROOMS', _bedsController)),
              Container(width: 1, height: 60, color: AppTheme.line),
              Expanded(child: _buildGridCell('BATHROOMS', _bathsController)),
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
        'title': 'Central HVAC · heat pump',
        'desc': '~16 yrs · last service Jun 2026 (#TW-4458)',
        'icon': Icons.ac_unit,
      },
      {
        'title': 'Water heater · tank, gas',
        'desc': '~9 yrs · 50 gal',
        'icon': Icons.water_drop,
      },
      {
        'title': 'Roof · asphalt shingle',
        'desc': '~12 yrs',
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
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.tealTint,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Icon(sys['icon'] as IconData, color: AppTheme.teal500, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sys['title'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sys['desc'] as String,
                        style: const TextStyle(fontSize: 11, color: AppTheme.gray),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.line)),
      ),
      child: HoverButton(
        text: 'Save home profile',
        onPressed: () {
          widget.onSave(
            _sqftController.text,
            _yearController.text,
            _bedsController.text,
            _bathsController.text,
          );
          Navigator.pop(context);
        },
      ),
    );
  }
}
