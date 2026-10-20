import 'dart:convert';
import '../../widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/homeowner_service.dart';
import '../../services/notification_preferences.dart';
import '../../services/push_notification_service.dart';
import '../../theme.dart';
import '../../ui/tw.dart';
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
  static const Color _lineSoft = AppTheme.cardBorder;

  bool _isLoading = true;
  Map<String, dynamic> _supported = {};
  bool _loadFailed = false;
  bool _supports(String group, String key) =>
      _supported[group] is Map && (_supported[group] as Map).containsKey(key);
  bool get _showPush =>
      PushNotificationService.instance.isConfigured &&
      _supported['push'] is Map;
  bool _pushStatus = true;
  bool _pushMessages = true;
  bool _pushCredits = true;
  bool _pushPromos = false;
  bool _emailReceipts = true;
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
      final enabledPushCategory = (!previous.pushStatus && next.pushStatus) ||
          (!previous.pushMessages && next.pushMessages) ||
          (!previous.pushCredits && next.pushCredits) ||
          (!previous.pushPromos && next.pushPromos);
      if (enabledPushCategory) {
        final allowed =
            await PushNotificationService.instance.requestPermissionAndRegister(
          userId: userId,
          preferences: next,
        );
        if (!allowed) {
          throw StateError(
            PushNotificationService.instance.isAvailable ||
                    PushNotificationService.instance.supportsOpenAppAlerts
                ? 'permission_denied'
                : 'push_not_configured',
          );
        }
      }
      final payload = next.toApiPayload();
      for (final group in ['push', 'email']) {
        (payload[group] as Map).removeWhere((key, _) => !_supports(group, key));
        if ((payload[group] as Map).isEmpty) payload.remove(group);
      }
      await HomeownerService.instance.updateNotificationPreferences(payload);
      await next.cache();
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
            ? 'Notifications are unavailable right now. Please try again later.'
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
    NotificationPreferences preferences;
    try {
      final account = await HomeownerService.instance.fetchAccount();
      final root = account['account'] ?? account['data'] ?? account;
      dynamic raw = root is Map ? root['preferences'] : null;
      if (raw is String) raw = jsonDecode(raw);
      _supported = raw is Map ? Map<String, dynamic>.from(raw) : {};
      _loadFailed = false;
      preferences = NotificationPreferences.fromAccount(account);
      await preferences.cache();
    } catch (_) {
      _supported = {};
      _loadFailed = true;
      preferences = const NotificationPreferences();
    }
    if (!mounted) return;
    setState(() {
      _pushStatus = preferences.pushStatus;
      _pushMessages = preferences.pushMessages;
      _pushCredits = preferences.pushCredits;
      _pushPromos = preferences.pushPromos;
      _emailReceipts = preferences.emailReceipts;
      _emailPromos = preferences.emailPromos;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TransactionGuard(
      isProcessing: _isSaving,
      blockedMessage:
          'Please wait while your notification settings are being saved.',
      child: Scaffold(
        backgroundColor: _pageBackground,
        appBar: TwAppBar(
          title: 'Notifications',
          onBack: () => Navigator.pop(context),
        ),
        body: _isLoading
            ? const SkeletonPage(layout: SkeletonLayout.form)
            : RefreshIndicator(
                onRefresh: _loadSettings,
                color: AppTheme.navy,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    TwPage(
                      top: TwSpace.s20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_loadFailed)
                            TwEmptyState(
                                icon: Icons.cloud_off_outlined,
                                title: "Couldn't load notification settings",
                                action: TwSecondaryButton(
                                    label: 'Try again',
                                    onPressed: _loadSettings)),
                          if (!_loadFailed && _supported.isEmpty)
                            Text(
                                'No notification preferences are available right now.',
                                style: TwType.bodySm()),
                          if (_showPush) _sectionLabel('Push notifications'),
                          if (_showPush && _supports('push', 'status'))
                            _toggleTile(
                              title: 'Work-order status updates',
                              subtitle:
                                  'Booked, en route, in progress, completed',
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
                          if (_showPush && _supports('push', 'messages'))
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
                          if (_showPush && _supports('push', 'credits'))
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
                          if (_showPush && _supports('push', 'promos'))
                            _toggleTile(
                              title: 'Promotions & offers',
                              subtitle:
                                  'Occasional offers · Off unless you turn it on',
                              last: true,
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
                          const SizedBox(height: TwSpace.s28),
                          if (_supported['email'] is Map)
                            _sectionLabel('Email'),
                          if (_supports('email', 'receipts'))
                            _toggleTile(
                              title: 'Job summaries',
                              subtitle:
                                  'After each completed job: what was done, what you paid, credits earned.',
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
                          if (_supports('email', 'promos'))
                            _toggleTile(
                              title: 'Promotions & offers',
                              subtitle:
                                  'Occasional offers · Off unless you turn it on',
                              last: true,
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
                          const SizedBox(height: TwSpace.s20),
                          _infoCallout(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Section heading: Outfit 20, sentence case (v3.3 rule 2).
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TwSpace.s4),
      child: Text(text, style: TwType.h2()),
    );
  }

  /// A hairline row: title, one meta line, a switch (F08). The last row
  /// in a section has no rule under it.
  Widget _toggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: TwSpace.s12),
      decoration: BoxDecoration(
        border:
            last ? null : const Border(bottom: BorderSide(color: _lineSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TwType.title()),
                const SizedBox(height: 2),
                Text(subtitle, style: TwType.meta()),
              ],
            ),
          ),
          const SizedBox(width: TwSpace.s12),
          Semantics(
            label: title,
            child: Switch(
              value: value,
              activeColor: AppTheme.white,
              activeTrackColor: AppTheme.blue,
              inactiveThumbColor: AppTheme.white,
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
    return TwFactPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppTheme.navy, size: 20),
          const SizedBox(width: TwSpace.s12),
          Expanded(
            child: Text(
              'Alerts that need you open the screen to act on them.',
              style: TwType.bodySm(),
            ),
          ),
        ],
      ),
    );
  }
}
