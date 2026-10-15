import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.pushStatus = true,
    this.pushMessages = true,
    this.pushCredits = true,
    this.pushPromos = false,
    this.emailReceipts = true,
    this.emailPromos = false,
  });

  static const String _cacheKey = 'notification_preferences_v2';

  final bool pushStatus;
  final bool pushMessages;
  final bool pushCredits;
  final bool pushPromos;
  final bool emailReceipts;
  final bool emailPromos;

  bool get hasPushEnabled =>
      pushStatus || pushMessages || pushCredits || pushPromos;

  Map<String, dynamic> toApiPayload() => {
        'push': {
          'status': pushStatus,
          'messages': pushMessages,
          'credits': pushCredits,
          'promos': pushPromos,
        },
        'email': {
          'receipts': emailReceipts,
          'promos': emailPromos,
        },
      };

  factory NotificationPreferences.fromAccount(Map<String, dynamic> account) {
    dynamic raw = account['preferences'];
    if (raw == null && account['account'] is Map) {
      raw = (account['account'] as Map)['preferences'];
    }
    if (raw == null && account['data'] is Map) {
      raw = (account['data'] as Map)['preferences'];
    }
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        raw = null;
      }
    }
    return NotificationPreferences.fromJson(
      raw is Map ? Map<String, dynamic>.from(raw) : const {},
    );
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    final push = json['push'] is Map
        ? Map<String, dynamic>.from(json['push'] as Map)
        : const <String, dynamic>{};
    final email = json['email'] is Map
        ? Map<String, dynamic>.from(json['email'] as Map)
        : const <String, dynamic>{};
    return NotificationPreferences(
      pushStatus: _readBool(push['status'] ?? json['pushStatus'], true),
      pushMessages: _readBool(push['messages'] ?? json['pushMessages'], true),
      pushCredits: _readBool(push['credits'] ?? json['pushCredits'], true),
      pushPromos: _readBool(push['promos'] ?? json['pushPromos'], false),
      emailReceipts:
          _readBool(email['receipts'] ?? json['emailReceipts'], true),
      emailPromos: _readBool(email['promos'] ?? json['emailPromos'], false),
    );
  }

  Future<void> cache() async {
    final store = await SharedPreferences.getInstance();
    await store.setString(_cacheKey, jsonEncode(toApiPayload()));
  }

  static Future<void> clearCache() async {
    final store = await SharedPreferences.getInstance();
    await store.remove(_cacheKey);
    for (final key in const [
      'notification_pushStatus',
      'notification_pushMessages',
      'notification_pushCredits',
      'notification_pushPromos',
      'notification_emailReceipts',
      'notification_emailPromos',
    ]) {
      await store.remove(key);
    }
  }

  static Future<NotificationPreferences?> loadCached() async {
    final store = await SharedPreferences.getInstance();
    final raw = store.getString(_cacheKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return NotificationPreferences.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {}
    }

    // One-time migration from the original flat SharedPreferences keys.
    final hasLegacy = store.containsKey('notification_pushStatus') ||
        store.containsKey('notification_pushMessages') ||
        store.containsKey('notification_pushCredits') ||
        store.containsKey('notification_pushPromos') ||
        store.containsKey('notification_emailReceipts') ||
        store.containsKey('notification_emailPromos');
    if (!hasLegacy) return null;
    return NotificationPreferences(
      pushStatus: store.getBool('notification_pushStatus') ?? true,
      pushMessages: store.getBool('notification_pushMessages') ?? true,
      pushCredits: store.getBool('notification_pushCredits') ?? true,
      pushPromos: store.getBool('notification_pushPromos') ?? false,
      emailReceipts: store.getBool('notification_emailReceipts') ?? true,
      emailPromos: store.getBool('notification_emailPromos') ?? false,
    );
  }

  static bool _readBool(dynamic value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return fallback;
  }
}

String pushPlatformName({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb) return 'web';
  return platform == TargetPlatform.iOS ? 'ios' : 'android';
}
