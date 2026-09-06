import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/homeowner_service.dart';
import '../theme.dart';
import '../utils/app_error_utils.dart';
import '../widgets/offline_state.dart';
import 'account/home_profile.dart';
import 'account/manage_addresses.dart';
import 'account/notification_settings.dart';
import 'account/payment_methods.dart';
import 'account/personal_info.dart';
import 'support_page.dart';

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
  static const Color _pageBackground = Color(0xFFF5F7FA);
  static const Color _inkStrong = Color(0xFF1E293B);
  static const Color _mutedText = Color(0xFF64748B);
  static const Color _lineSoft = Color(0xFFE1E7EF);

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  Map<String, dynamic>? _profileData;
  List<dynamic> _addresses = [];
  List<dynamic> _paymentMethods = [];
  double? _rewardsBalance;

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
    if (!mounted || _isRefreshing) return;
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
      if (!mounted) return;
      setState(() {
        _profileData = _asMap(profileResp['profile']);
        _addresses = profileResp['addresses'] as List? ??
            profileResp['profile']?['addresses'] as List? ??
            const [];
        _paymentMethods = profileResp['paymentMethods'] as List? ??
            profileResp['profile']?['paymentMethods'] as List? ??
            const [];
        _rewardsBalance = _amountFrom(
          rewardsResp['balance'] ??
              rewardsResp['rewardsBalance'] ??
              rewardsResp['availableCredits'] ??
              rewardsResp['availableServiceCredits'],
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppErrorUtils.friendlyMessage(e);
        _isLoading = false;
      });
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ColoredBox(
        color: _pageBackground,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.orange500),
        ),
      );
    }
    if (_errorMessage != null) {
      return ColoredBox(
        color: _pageBackground,
        child: OfflineState(
          onRetry: _fetchProfileData,
          message: _errorMessage,
        ),
      );
    }

    return ColoredBox(
      color: _pageBackground,
      child: RefreshIndicator(
        onRefresh: _fetchProfileData,
        color: AppTheme.orange500,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
          children: [
            const Text(
              'Profile',
              style: TextStyle(
                color: AppTheme.navy700,
                fontSize: 23,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            _accountHeader(),
            const SizedBox(height: 12),
            _creditsCard(),
            const SizedBox(height: 18),
            _sectionLabel('ACCOUNT'),
            _settingsCard(
              icon: Icons.person_outline_rounded,
              title: 'Personal info',
              subtitle: _personalSubtitle(),
              onTap: _editPersonalInfo,
            ),
            const SizedBox(height: 8),
            _settingsCard(
              icon: Icons.location_on_outlined,
              title: 'Addresses',
              subtitle: _addressSubtitle(),
              onTap: _manageAddresses,
            ),
            const SizedBox(height: 8),
            _settingsCard(
              icon: Icons.mail_outline_rounded,
              title: 'Payment methods',
              subtitle: _paymentSubtitle(),
              onTap: _managePayments,
            ),
            const SizedBox(height: 18),
            _sectionLabel('YOUR HOME'),
            _settingsCard(
              icon: Icons.home_outlined,
              title: 'Home profile',
              subtitle: _homeProfileSubtitle(),
              onTap: _openHomeProfileScreen,
            ),
            const SizedBox(height: 18),
            _sectionLabel('PREFERENCES'),
            _settingsCard(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: 'Push & email preferences',
              onTap: _openNotifications,
            ),
            const SizedBox(height: 18),
            _sectionLabel('SUPPORT'),
            _settingsCard(
              icon: Icons.help_outline_rounded,
              title: 'Help & support',
              subtitle: 'FAQs, contact us, report an issue',
              onTap: _openSupport,
            ),
            const SizedBox(height: 10),
            _signOutButton(),
          ],
        ),
      ),
    );
  }

  Widget _accountHeader() {
    final userName = _profileName();
    final userEmail = _profileEmail();
    final initials = _initials(userName);
    final hasPicture = _string(AuthService.instance.pictureUrl) != null;

    return _card(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 29,
            backgroundColor: AppTheme.navy700,
            backgroundImage: hasPicture
                ? NetworkImage(AuthService.instance.pictureUrl!)
                : null,
            child: hasPicture
                ? null
                : Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _inkStrong,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F7F8),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      _memberBadge(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.teal500,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: _mutedText,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _creditsCard() {
    final balance = _rewardsBalance ?? 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onRewardsTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            color: AppTheme.orangeTint,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.orange500, width: 1),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.card_giftcard_rounded,
                color: AppTheme.orange500,
                size: 25,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service credits',
                      style: TextStyle(
                        color: AppTheme.navy700,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Redeem on your next eligible booking',
                      style: TextStyle(
                        color: _mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _money(balance),
                  style: const TextStyle(
                    color: AppTheme.orange500,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: _mutedText,
                size: 23,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: _card(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Icon(icon, color: AppTheme.navy700, size: 23),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _inkStrong,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
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
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: _mutedText,
                size: 23,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: _mutedText,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
        ),
      ),
    );
  }

  Widget _card({required Widget child, required EdgeInsetsGeometry padding}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _lineSoft),
      ),
      child: child,
    );
  }

  Widget _signOutButton() {
    return TextButton.icon(
      onPressed: widget.onLogout,
      icon: const Icon(Icons.logout_rounded, size: 18),
      label: const Text('Sign out'),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.error,
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _profileName() {
    final given = _string(_profileData?['givenName']) ??
        _string(AuthService.instance.givenName);
    final family = _string(_profileData?['familyName']) ??
        _string(AuthService.instance.familyName);
    final joined = [given, family]
        .where((part) => part != null && part.isNotEmpty)
        .join(' ');
    return _string(_profileData?['name']) ??
        _string(_profileData?['userName']) ??
        _string(AuthService.instance.userName) ??
        (joined.isEmpty ? 'Homeowner' : joined);
  }

  String _profileEmail() {
    return _string(_profileData?['email']) ??
        _string(AuthService.instance.userEmail) ??
        'No email on file';
  }

  String _profilePhone() {
    return _string(_profileData?['phone']) ??
        _string(AuthService.instance.assignedPhoneNumber) ??
        '';
  }

  String _personalSubtitle() {
    final phone = _profilePhone();
    return phone.isEmpty ? _profileName() : '${_profileName()} · $phone';
  }

  String _addressSubtitle() {
    if (_addresses.isEmpty) return 'No saved addresses';
    final defaultAddr = _addresses.firstWhere(
      (dynamic item) =>
          item is Map &&
          (item['isDefault'] == true || item['isDefault'] == 'true'),
      orElse: () => _addresses.first,
    );
    final address = _asMap(defaultAddr);
    final label = _string(address['label']) ?? 'Address';
    final street = _string(address['street']);
    final city = _string(address['city']);
    final remaining = _addresses.length - 1;
    final location = [street, city].whereType<String>().join(', ');
    final suffix = remaining > 0 ? ' · +$remaining more' : '';
    return location.isEmpty ? '$label$suffix' : '$label · $location$suffix';
  }

  String _paymentSubtitle() {
    if (_paymentMethods.isEmpty) return 'No saved payment methods';
    final defaultMethod = _paymentMethods.firstWhere(
      (dynamic item) =>
          item is Map &&
          (item['isDefault'] == true || item['isDefault'] == 'true'),
      orElse: () => _paymentMethods.first,
    );
    final method = _asMap(defaultMethod);
    final brand = _string(method['brand']) ?? 'Card';
    final last4 = _string(method['last4']);
    if (last4 == null) return brand;
    return '$brand ending $last4 · pay pro at booking';
  }

  String _homeProfileSubtitle() {
    if (_addresses.isEmpty) return 'Add an address to build your profile';
    final defaultAddr = _asMap(_addresses.firstWhere(
      (dynamic item) =>
          item is Map &&
          (item['isDefault'] == true || item['isDefault'] == 'true'),
      orElse: () => _addresses.first,
    ));
    final type = _string(defaultAddr['propertyType']) ??
        _string(defaultAddr['homeType']) ??
        _string(_profileData?['propertyType']) ??
        'Home details';
    final sqft = _string(defaultAddr['sqft']) ??
        _string(defaultAddr['squareFootage']) ??
        _string(_profileData?['sqft']) ??
        _string(_profileData?['squareFootage']);
    return sqft == null ? type : '$type · $sqft sq ft';
  }

  String _memberBadge() {
    final raw = _string(_profileData?['memberSince']) ??
        _string(_profileData?['createdAt']) ??
        _string(_profileData?['created_at']);
    if (raw == null) return 'Homeowner';
    final year = DateTime.tryParse(raw)?.year;
    return year == null ? 'Homeowner' : 'Homeowner · since $year';
  }

  String _initials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    final value = parts
        .map((part) => part.trim()[0])
        .take(2)
        .join()
        .toUpperCase();
    return value.isEmpty ? 'H' : value;
  }

  String _money(num amount) => '\$${amount.toStringAsFixed(2)}';

  double? _amountFrom(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^0-9.-]'), ''));
    }
    return null;
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

  Future<void> _editPersonalInfo() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PersonalInfoScreen()),
    );
    if (changed == true) {
      _fetchProfileData(showLoading: false);
    }
  }

  Future<void> _manageAddresses() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageAddressesScreen()),
    );
    if (changed == true) {
      _fetchProfileData(showLoading: false);
    }
  }

  Future<void> _managePayments() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PaymentMethodsScreen()),
    );
    if (changed == true) {
      _fetchProfileData(showLoading: false);
    }
  }

  Future<void> _openHomeProfileScreen() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeProfileScreen(addresses: _addresses),
      ),
    );
    if (changed == true) {
      _fetchProfileData(showLoading: false);
    }
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationSettingsScreen(),
      ),
    );
  }

  void _openSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SupportPage()),
    );
  }
}
