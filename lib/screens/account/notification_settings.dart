import 'package:flutter/material.dart';

import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../utils/app_error_utils.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const Color _pageBackground = Color(0xFFF5F7FA);
  static const Color _inkStrong = Color(0xFF1E293B);
  static const Color _mutedText = Color(0xFF64748B);
  static const Color _lineSoft = Color(0xFFE1E7EF);

  bool _isLoading = true;
  bool _pushStatus = false;
  bool _pushMessages = false;
  bool _pushCredits = false;
  bool _pushPromos = false;
  bool _emailReceipts = false;
  bool _emailPromos = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final resp = await HomeownerService.instance.fetchProfile();
      final profile = _asMap(resp['profile']);
      final prefs = _asMap(profile['notificationSettings'] ??
          profile['notification_settings'] ??
          resp['notificationSettings'] ??
          resp['notification_settings']);
      if (!mounted) return;
      setState(() {
        _pushStatus = _boolOf(prefs['pushStatus'] ??
            prefs['push_status'] ??
            prefs['workOrderStatusPush']);
        _pushMessages = _boolOf(prefs['pushMessages'] ??
            prefs['push_messages'] ??
            prefs['messagesPush']);
        _pushCredits = _boolOf(prefs['pushCredits'] ??
            prefs['push_credits'] ??
            prefs['rewardsPush']);
        _pushPromos = _boolOf(prefs['pushPromos'] ??
            prefs['push_promos'] ??
            profile['marketingConsent']);
        _emailReceipts = _boolOf(prefs['emailReceipts'] ??
            prefs['email_receipts'] ??
            prefs['bookingReceiptsEmail']);
        _emailPromos = _boolOf(prefs['emailPromos'] ??
            prefs['email_promos'] ??
            profile['marketingConsent']);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorUtils.friendlyMessage(e)),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: _appBar('Notifications'),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.orange500),
            )
          : RefreshIndicator(
              onRefresh: _loadSettings,
              color: AppTheme.orange500,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  _sectionLabel('PUSH NOTIFICATIONS'),
                  _toggleTile(
                    title: 'Work-order status updates',
                    subtitle: 'Booked, en route, arrived, completed',
                    value: _pushStatus,
                    onChanged: (value) => setState(() => _pushStatus = value),
                  ),
                  _toggleTile(
                    title: 'Messages from your pro',
                    subtitle: 'New messages on a work order',
                    value: _pushMessages,
                    onChanged: (value) => setState(() => _pushMessages = value),
                  ),
                  _toggleTile(
                    title: 'Service credits & rewards',
                    subtitle: 'When credits are earned',
                    value: _pushCredits,
                    onChanged: (value) => setState(() => _pushCredits = value),
                  ),
                  _toggleTile(
                    title: 'Promotions & offers',
                    subtitle: 'Occasional offers',
                    value: _pushPromos,
                    onChanged: (value) => setState(() => _pushPromos = value),
                  ),
                  const SizedBox(height: 18),
                  _sectionLabel('EMAIL'),
                  _toggleTile(
                    title: 'Booking receipts',
                    subtitle: 'A receipt after each completed job',
                    value: _emailReceipts,
                    onChanged: (value) =>
                        setState(() => _emailReceipts = value),
                  ),
                  _toggleTile(
                    title: 'Promotions & offers',
                    subtitle: 'Occasional offers',
                    value: _emailPromos,
                    onChanged: (value) => setState(() => _emailPromos = value),
                  ),
                  const SizedBox(height: 18),
                  _infoCallout(),
                ],
              ),
            ),
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

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: _mutedText,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _toggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(11, 8, 9, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _lineSoft),
      ),
      child: Row(
        children: [
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
                    fontSize: 12.5,
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
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: AppTheme.orange500,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFCBD5E1),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _infoCallout() {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFEAFBFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.teal500),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.trending_up_rounded, color: AppTheme.teal500, size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Push alerts deep-link to the relevant work order. In-app live status uses a 60-second refresh.',
              style: TextStyle(
                color: _inkStrong,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _boolOf(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }
}
