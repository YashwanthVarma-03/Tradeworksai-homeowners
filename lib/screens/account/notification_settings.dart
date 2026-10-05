import '../../widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';

import '../../services/homeowner_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_preferences.dart';
import '../../services/push_notification_service.dart';
import '../../theme.dart';
import '../../widgets/app_notification.dart';
import '../../widgets/transaction_guard.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const Color _pageBackground = AppTheme.pageBackground;
  static const Color _inkStrong = AppTheme.navy;
  static const Color _mutedText = AppTheme.textSecondary;
  static const Color _lineSoft = AppTheme.cardBorder;

  bool _isLoading = true;
  bool _pushStatus = false;
  bool _pushMessages = false;
  bool _pushCredits = false;
  bool _pushPromos = false;
  bool _emailReceipts = false;
  bool _emailPromos = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  NotificationPreferences get _preferences => NotificationPreferences(
        pushStatus: _pushStatus,
        pushMessages: _pushMessages,
        pushCredits: _pushCredits,
        pushPromos: _pushPromos,
        emailReceipts: _emailReceipts,
        emailPromos: _emailPromos,
      );

  Future<void> _savePreferences(NotificationPreferences next) async {
    if (_isSaving) return;
    final previous = _preferences;
    final userId = AuthService.instance.userId;
    if (userId == null || userId.isEmpty) {
      AppNotification.showInfo(
          context, 'Please sign in to update notifications.');
      return;
    }

    setState(() {
      _isSaving = true;
      _pushStatus = next.pushStatus;
      _pushMessages = next.pushMessages;
      _pushCredits = next.pushCredits;
      _pushPromos = next.pushPromos;
      _emailReceipts = next.emailReceipts;
      _emailPromos = next.emailPromos;
    });

    try {
      if (next.hasPushEnabled) {
        final allowed =
            await PushNotificationService.instance.requestPermissionAndRegister(
          userId: userId,
          preferences: next,
        );
        if (!allowed) {
          throw StateError(
            PushNotificationService.instance.isAvailable
                ? 'permission_denied'
                : 'push_not_configured',
          );
        }
      }
      await HomeownerService.instance.updateNotificationSettings(next.toJson());
      await PushNotificationService.instance.updatePreferences(
        userId: userId,
        preferences: next,
      );
      if (mounted) {
        AppNotification.showSuccess(context, 'Notification preferences saved.');
      }
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _pushStatus = previous.pushStatus;
        _pushMessages = previous.pushMessages;
        _pushCredits = previous.pushCredits;
        _pushPromos = previous.pushPromos;
        _emailReceipts = previous.emailReceipts;
        _emailPromos = previous.emailPromos;
      });
      AppNotification.showInfo(
        context,
        error.message == 'push_not_configured'
            ? 'Phone notifications are not configured for this app build yet.'
            : 'Allow notifications in your device settings to receive alerts.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pushStatus = previous.pushStatus;
        _pushMessages = previous.pushMessages;
        _pushCredits = previous.pushCredits;
        _pushPromos = previous.pushPromos;
        _emailReceipts = previous.emailReceipts;
        _emailPromos = previous.emailPromos;
      });
      AppNotification.showError(
        context,
        error,
        fallback: 'We couldn\'t save your notification preferences.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
      AppNotification.showError(
        context,
        e,
        fallback: 'We couldn\'t load notification settings. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TransactionGuard(
      isProcessing: _isSaving,
      blockedMessage:
          'Please wait while your notification settings are being saved.',
      child: Scaffold(
        backgroundColor: _pageBackground,
        appBar: _appBar('Notifications'),
        body: _isLoading
            ? const SkeletonPage(layout: SkeletonLayout.form)
            : RefreshIndicator(
                onRefresh: _loadSettings,
                color: AppTheme.navy,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    _sectionLabel('Push notifications'),
                    _toggleTile(
                      title: 'Work-order status updates',
                      subtitle: 'Booked, en route, in progress, completed',
                      value: _pushStatus,
                      onChanged: _isSaving
                          ? null
                          : (value) => _savePreferences(
                                NotificationPreferences(
                                  pushStatus: value,
                                  pushMessages: _pushMessages,
                                  pushCredits: _pushCredits,
                                  pushPromos: _pushPromos,
                                  emailReceipts: _emailReceipts,
                                  emailPromos: _emailPromos,
                                ),
                              ),
                    ),
                    _toggleTile(
                      title: 'Messages from your pro',
                      subtitle: 'New messages from your pros',
                      value: _pushMessages,
                      onChanged: _isSaving
                          ? null
                          : (value) => _savePreferences(
                                NotificationPreferences(
                                  pushStatus: _pushStatus,
                                  pushMessages: value,
                                  pushCredits: _pushCredits,
                                  pushPromos: _pushPromos,
                                  emailReceipts: _emailReceipts,
                                  emailPromos: _emailPromos,
                                ),
                              ),
                    ),
                    _toggleTile(
                      title: 'Service credits & rewards',
                      subtitle:
                          'When credits are ready, and before they expire',
                      value: _pushCredits,
                      onChanged: _isSaving
                          ? null
                          : (value) => _savePreferences(
                                NotificationPreferences(
                                  pushStatus: _pushStatus,
                                  pushMessages: _pushMessages,
                                  pushCredits: value,
                                  pushPromos: _pushPromos,
                                  emailReceipts: _emailReceipts,
                                  emailPromos: _emailPromos,
                                ),
                              ),
                    ),
                    _toggleTile(
                      title: 'Promotions & offers',
                      subtitle: 'Occasional offers · Off unless you turn it on',
                      value: _pushPromos,
                      onChanged: _isSaving
                          ? null
                          : (value) => _savePreferences(
                                NotificationPreferences(
                                  pushStatus: _pushStatus,
                                  pushMessages: _pushMessages,
                                  pushCredits: _pushCredits,
                                  pushPromos: value,
                                  emailReceipts: _emailReceipts,
                                  emailPromos: _emailPromos,
                                ),
                              ),
                    ),
                    const SizedBox(height: 18),
                    _sectionLabel('Email'),
                    _toggleTile(
                      title: 'Booking receipts',
                      subtitle: 'A receipt after each completed job',
                      value: _emailReceipts,
                      onChanged: _isSaving
                          ? null
                          : (value) => _savePreferences(
                                NotificationPreferences(
                                  pushStatus: _pushStatus,
                                  pushMessages: _pushMessages,
                                  pushCredits: _pushCredits,
                                  pushPromos: _pushPromos,
                                  emailReceipts: value,
                                  emailPromos: _emailPromos,
                                ),
                              ),
                    ),
                    _toggleTile(
                      title: 'Promotions & offers',
                      subtitle: 'Occasional offers · Off unless you turn it on',
                      value: _emailPromos,
                      onChanged: _isSaving
                          ? null
                          : (value) => _savePreferences(
                                NotificationPreferences(
                                  pushStatus: _pushStatus,
                                  pushMessages: _pushMessages,
                                  pushCredits: _pushCredits,
                                  pushPromos: _pushPromos,
                                  emailReceipts: _emailReceipts,
                                  emailPromos: value,
                                ),
                              ),
                    ),
                    const SizedBox(height: 18),
                    _infoCallout(),
                  ],
                ),
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

  /// Section heading: Outfit 20, sentence case (v3.3 rule 2).
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Text(text, style: Theme.of(context).textTheme.headlineMedium),
    );
  }

  /// A hairline row: title, one meta line, a switch (F08).
  Widget _toggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _lineSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _inkStrong,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 14,
                    height: 20 / 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            label: title,
            child: Switch(
              value: value,
              activeColor: Colors.white,
              activeTrackColor: AppTheme.blue,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: AppTheme.border,
              trackOutlineColor:
                  const WidgetStatePropertyAll(Colors.transparent),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCallout() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.subtle,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.navy, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Push alerts open the work order they’re about.',
              style: TextStyle(
                color: AppTheme.body,
                fontSize: 14,
                height: 21 / 14,
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
