import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/homeowner_service.dart';
import '../theme.dart';
import 'support_page.dart';
import 'account/manage_addresses.dart';
import 'account/payment_methods.dart';
import 'account/home_profile.dart';
import 'account/notification_settings.dart';

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

class _ProfileTabState extends State<ProfileTab> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  Map<String, dynamic>? _profileData;
  List<dynamic> _addresses = [];
  double _rewardsBalance = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchProfileData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchProfileData(showLoading: false);
    }
  }

  Future<void> _fetchProfileData({bool showLoading = true}) async {
    if (!mounted) return;
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (showLoading || (_profileData == null && _addresses.isEmpty)) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      _errorMessage = null;
    }
    try {
      final profileResp = await HomeownerService.instance.fetchProfile();
      final rewardsResp = await HomeownerService.instance.fetchRewards();
      if (mounted) {
        setState(() {
          _profileData = profileResp['profile'];
          _addresses = profileResp['addresses'] as List? ??
              profileResp['profile']?['addresses'] as List? ??
              [];
          _rewardsBalance = (rewardsResp['balance'] as num?)?.toDouble() ?? 0.0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  String _addressSubtitle() {
    if (_addresses.isEmpty) return 'No saved addresses';
    final defaultAddr = _addresses.firstWhere((a) => a['isDefault'] == true,
        orElse: () => _addresses.first);
    final remaining = _addresses.length - 1;
    final street = defaultAddr['street'] ?? '';
    final label = defaultAddr['label'] ?? 'Home';
    return '$label · $street${remaining > 0 ? ' · +$remaining more' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.orange500),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(_errorMessage!,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchProfileData,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchProfileData,
      color: AppTheme.orange500,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                style: TextStyle(
                    color: AppTheme.gray,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.07),
              ),
            ),

            // 4. Personal Info
            _buildSettingsRow(
              icon: Icons.person_outline,
              title: 'Personal info',
              subtitle:
                  '${_profileData?['givenName'] ?? ''} ${_profileData?['familyName'] ?? ''} · ${_profileData?['email'] ?? ''}',
              onTap: _editPersonalInfo,
            ),

            // 5. Addresses
            _buildSettingsRow(
              icon: Icons.location_on_outlined,
              title: 'Addresses',
              subtitle: _addressSubtitle(),
              onTap: _manageAddresses,
            ),

            // 6. Payment methods
            _buildSettingsRow(
              icon: Icons.credit_card_outlined,
              title: 'Payment methods',
              subtitle: 'Manage how you pay for completed bookings',
              onTap: _managePayments,
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 11.0),
              child: Text(
                'YOUR HOME',
                style: TextStyle(
                    color: AppTheme.gray,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.07),
              ),
            ),

            // 7. Home profile sub-screen trigger
            _buildSettingsRow(
              icon: Icons.home_outlined,
              title: 'Home profile',
              subtitle: 'Manage your home details',
              onTap: _openHomeProfileScreen,
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 11.0),
              child: Text(
                'NOTIFICATIONS',
                style: TextStyle(
                    color: AppTheme.gray,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.07),
              ),
            ),

            // 8. Notification Settings
            _buildSettingsRow(
              icon: Icons.notifications_none_outlined,
              title: 'Notifications',
              subtitle: 'Push and email preferences',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const NotificationSettingsScreen()),
                );
              },
            ),

            const SizedBox(height: 12),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 11.0),
              child: Text(
                'SUPPORT',
                style: TextStyle(
                    color: AppTheme.gray,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.07),
              ),
            ),

            _buildSettingsRow(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'FAQ, contact support',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SupportPage()),
                );
              },
            ),

            const SizedBox(height: 12),

            // 9. Sign out
            _buildSignOutRow(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountHeader() {
    final givenName =
        _profileData?['givenName'] ?? AuthService.instance.givenName ?? '';
    final familyName =
        _profileData?['familyName'] ?? AuthService.instance.familyName ?? '';
    final userName = _profileData?['userName'] ??
        AuthService.instance.userName ??
        (givenName.isNotEmpty ? '$givenName $familyName'.trim() : 'Homeowner');
    final userEmail =
        _profileData?['email'] ?? AuthService.instance.userEmail ?? 'No email';
    final initials = userName
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    final hasPicture = AuthService.instance.pictureUrl != null &&
        AuthService.instance.pictureUrl!.isNotEmpty;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppTheme.navy700,
            backgroundImage: hasPicture
                ? NetworkImage(AuthService.instance.pictureUrl!)
                : null,
            child: hasPicture
                ? null
                : Text(
                    initials.isNotEmpty ? initials : 'U',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: AppTheme.headingStyle
                      .copyWith(fontSize: 16, color: AppTheme.navy700),
                ),
                const SizedBox(height: 2),
                Text(
                  userEmail,
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.gray),
                ),
                const SizedBox(height: 7),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.tealTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _profileData?['emailVerified'] == true
                        ? 'Verified homeowner'
                        : 'Homeowner',
                    style: const TextStyle(
                        color: Color(0xFF1F6F93),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold),
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
                  child: const Icon(Icons.stars,
                      color: AppTheme.orange500, size: 19),
                ),
                const SizedBox(width: 11),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service credits',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: AppTheme.navy700),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Redeem on your next eligible booking',
                      style: TextStyle(color: AppTheme.gray, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  '\$${_rewardsBalance.toStringAsFixed(0)}',
                  style: AppTheme.headingStyle.copyWith(
                      fontSize: 16,
                      color: AppTheme.orange500,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right,
                    color: AppTheme.orange500, size: 18),
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
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.ink),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Text(
            subtitle,
            style: const TextStyle(color: AppTheme.gray, fontSize: 11.5),
          ),
        ),
        trailing:
            const Icon(Icons.chevron_right, color: AppTheme.line, size: 18),
        onTap: onTap,
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
              child: const Icon(Icons.exit_to_app,
                  color: Color(0xFFB23535), size: 19),
            ),
            const SizedBox(width: 12),
            const Text(
              'Sign out',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFFB23535)),
            ),
          ],
        ),
      ),
    );
  }

  void _editPersonalInfo() {
    final usernameCtrl = TextEditingController(
        text: _profileData?['userName'] ?? AuthService.instance.userName ?? '');
    final givenCtrl = TextEditingController(
        text:
            _profileData?['givenName'] ?? AuthService.instance.givenName ?? '');
    final familyCtrl = TextEditingController(
        text: _profileData?['familyName'] ??
            AuthService.instance.familyName ??
            '');
    final phoneCtrl = TextEditingController(
        text: _profileData?['phone'] ??
            AuthService.instance.assignedPhoneNumber ??
            '');
    final emailCtrl = TextEditingController(
        text: _profileData?['email'] ?? AuthService.instance.userEmail ?? '');
    String preferred = _profileData?['preferredContact'] ?? 'email';
    bool marketing = _profileData?['marketingConsent'] == true;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) {
          Widget buildField({
            required TextEditingController controller,
            required String label,
            required IconData icon,
            TextInputType keyboardType = TextInputType.text,
          }) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                style: const TextStyle(
                    color: AppTheme.navy700,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle:
                      const TextStyle(color: AppTheme.gray, fontSize: 13),
                  prefixIcon: Icon(icon,
                      color: AppTheme.navy700.withOpacity(0.6), size: 20),
                  filled: true,
                  fillColor: AppTheme.pageAlt,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppTheme.line.withOpacity(0.8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppTheme.teal500, width: 1.5),
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Personal Info',
                  style: AppTheme.headingStyle.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy700,
                  ),
                ),
                GestureDetector(
                  onTap: isSaving ? null : () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.pageAlt,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, size: 18, color: AppTheme.gray),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildField(
                    controller: usernameCtrl,
                    label: 'User Name',
                    icon: Icons.alternate_email,
                  ),
                  buildField(
                    controller: givenCtrl,
                    label: 'First Name',
                    icon: Icons.person_outline,
                  ),
                  buildField(
                    controller: familyCtrl,
                    label: 'Last Name',
                    icon: Icons.person_outline,
                  ),
                  buildField(
                    controller: phoneCtrl,
                    label: 'Phone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  buildField(
                    controller: emailCtrl,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: DropdownButtonFormField<String>(
                      value: preferred,
                      dropdownColor: Colors.white,
                      style: const TextStyle(
                          color: AppTheme.navy700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        labelText: 'Preferred Contact',
                        labelStyle:
                            const TextStyle(color: AppTheme.gray, fontSize: 13),
                        prefixIcon: Icon(Icons.contact_mail_outlined,
                            color: AppTheme.navy700.withOpacity(0.6), size: 20),
                        filled: true,
                        fillColor: AppTheme.pageAlt,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppTheme.line.withOpacity(0.8)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.teal500, width: 1.5),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'email', child: Text('Email')),
                        DropdownMenuItem(value: 'phone', child: Text('Phone')),
                        DropdownMenuItem(
                            value: 'text', child: Text('Text/SMS')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() => preferred = val);
                        }
                      },
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.pageAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.line.withOpacity(0.8)),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: CheckboxListTile(
                      title: const Text(
                        'Receive marketing notifications',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.navy700),
                      ),
                      activeColor: AppTheme.teal500,
                      checkboxShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      contentPadding: EdgeInsets.zero,
                      value: marketing,
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() => marketing = val);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.gray,
                        side: const BorderSide(color: AppTheme.line),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.navy700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              setDlgState(() => isSaving = true);
                              try {
                                final gName = givenCtrl.text.trim();
                                final fName = familyCtrl.text.trim();
                                final ph = phoneCtrl.text.trim();
                                final em = emailCtrl.text.trim();
                                final un = usernameCtrl.text.trim();

                                await HomeownerService.instance.updateProfile(
                                  givenName: gName,
                                  familyName: fName,
                                  phone: ph,
                                  email: em,
                                  userName: un,
                                  preferredContact: preferred,
                                  marketingConsent: marketing,
                                );

                                // Save locally to AuthService session cache
                                await AuthService.instance.updateCachedProfile(
                                  givenName: gName,
                                  familyName: fName,
                                  phone: ph,
                                  email: em,
                                  userName: un,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Profile updated successfully!'),
                                      backgroundColor: AppTheme.success,
                                    ),
                                  );
                                  _fetchProfileData(showLoading: false);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Failed to update profile: $e'),
                                      backgroundColor: AppTheme.error,
                                    ),
                                  );
                                }
                              } finally {
                                if (context.mounted) {
                                  setDlgState(() => isSaving = false);
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Save',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _manageAddresses() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ManageAddressesScreen(),
      ),
    );
    if (changed == true) {
      _fetchProfileData(showLoading: false);
    }
  }

  void _managePayments() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PaymentMethodsScreen()),
    );
    if (changed == true) {
      _fetchProfileData(showLoading: false);
    }
  }

  void _openHomeProfileScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeProfileScreen(
          addresses: _addresses,
        ),
      ),
    );
  }
}
