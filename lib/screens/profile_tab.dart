import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';
import '../main.dart';

class ProfileTab extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileTab({
    super.key,
    required this.onLogout,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _pushNotifications = true;
  bool _smsUpdates = true;
  
  final List<Map<String, String>> _addresses = [
    {
      'name': 'Primary Residence',
      'address': '124 Skyview Lane, Tampa, FL 33569',
      'instructions': 'Gate code #4233. Park in driveway.',
    },
    {
      'name': 'Rental Property',
      'address': '904 Meridian Blvd, Riverview, FL 33578',
      'instructions': 'No gate. Tenant must be notified before entry.',
    }
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserInfoHeader(),
          const SizedBox(height: 24),
          _buildAddressBookSection(),
          const SizedBox(height: 24),
          _buildPaymentPreferencesCard(),
          const SizedBox(height: 24),
          _buildNotificationSettingsCard(),
          const SizedBox(height: 24),
          _buildThemeSelectorCard(),
          const SizedBox(height: 32),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildUserInfoHeader() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 36,
          backgroundColor: AppTheme.navy700,
          child: Text(
            'YV',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yashwanth Varma',
                style: AppTheme.textTheme.headlineMedium?.copyWith(fontSize: 18, color: AppTheme.navy700),
              ),
              const SizedBox(height: 2),
              Text(
                'yashwanth.varma@example.com',
                style: AppTheme.textTheme.bodySmall?.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, color: AppTheme.success, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Verified Homeowner',
                          style: TextStyle(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressBookSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Address Book',
              style: AppTheme.textTheme.headlineMedium?.copyWith(fontSize: 15),
            ),
            TextButton(
              onPressed: () {
                _showAddAddressDialog();
              },
              child: const Text('+ Add New', style: TextStyle(color: AppTheme.teal700, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._addresses.map((addr) => _buildAddressCard(addr)),
      ],
    );
  }

  Widget _buildAddressCard(Map<String, String> addr) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                addr['name']!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navy700),
              ),
              const Icon(Icons.home, color: AppTheme.teal500, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            addr['address']!,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.ink),
          ),
          if (addr['instructions']!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.pageAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key, color: AppTheme.gray, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      addr['instructions']!,
                      style: const TextStyle(color: AppTheme.gray, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentPreferencesCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payment, color: AppTheme.teal500),
              SizedBox(width: 12),
              Text(
                'Payment Configuration',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navy700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'TradeWorks AI is a \$0-commission platform. You pay the contractor directly at the completion of your job.',
            style: TextStyle(color: AppTheme.gray, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          _buildPaymentMethodRow('Primary Credit Card', 'Visa ending in 4921', Icons.credit_card),
          _buildPaymentMethodRow('Alternate Option', 'Direct Bank Transfer (ACH)', Icons.account_balance),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.gray, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.gray, fontSize: 10)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.line),
        ],
      ),
    );
  }

  Widget _buildNotificationSettingsCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notification Configurations',
            style: AppTheme.headingStyle.copyWith(fontSize: 14, color: AppTheme.navy700),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Push Notifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('Status updates, AI matches, and dispatcher logs.', style: TextStyle(fontSize: 11)),
            value: _pushNotifications,
            activeColor: AppTheme.teal500,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              setState(() {
                _pushNotifications = val;
              });
            },
          ),
          SwitchListTile(
            title: const Text('SMS / Text Updates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('Direct messaging from pros and dispatchers.', style: TextStyle(fontSize: 11)),
            value: _smsUpdates,
            activeColor: AppTheme.teal500,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              setState(() {
                _smsUpdates = val;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelectorCard() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'App Design System Theme',
                style: AppTheme.headingStyle.copyWith(fontSize: 14, color: AppTheme.navy700),
              ),
              const SizedBox(height: 12),
              const Text('Toggle system modes (WCAG 2.1 AA contrast matching)', style: TextStyle(color: AppTheme.gray, fontSize: 11)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildThemeChip('Light', currentMode == ThemeMode.light, () {
                    themeNotifier.value = ThemeMode.light;
                  }),
                  _buildThemeChip('Dark Mode', currentMode == ThemeMode.dark, () {
                    themeNotifier.value = ThemeMode.dark;
                  }),
                  _buildThemeChip('OS Default', currentMode == ThemeMode.system, () {
                    themeNotifier.value = ThemeMode.system;
                  }),
                ],
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildThemeChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.navy700 : AppTheme.pageAlt,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: AppTheme.line.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.ink,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Center(
      child: HoverButton(
        text: 'Sign Out / Disconnect Profile',
        isSecondary: true,
        onPressed: widget.onLogout,
      ),
    );
  }

  void _showAddAddressDialog() {
    final nameCont = TextEditingController();
    final addrCont = TextEditingController();
    final instCont = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Service Address', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCont,
                  decoration: const InputDecoration(labelText: 'Address Label (e.g. Home, Office)'),
                ),
                TextField(
                  controller: addrCont,
                  decoration: const InputDecoration(labelText: 'Full Address'),
                ),
                TextField(
                  controller: instCont,
                  decoration: const InputDecoration(labelText: 'Access Instructions (Gate Code, parking)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCont.text.isNotEmpty && addrCont.text.isNotEmpty) {
                  setState(() {
                    _addresses.add({
                      'name': nameCont.text,
                      'address': addrCont.text,
                      'instructions': instCont.text,
                    });
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            )
          ],
        );
      },
    );
  }
}
