import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
import '../services/homeowner_service.dart';
import '../services/stream_service.dart';
import '../widgets/app_notification.dart';

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty || text.toLowerCase() == 'null'
      ? null
      : text;
}

/// Opens the one thread between the homeowner and a pro (decisions §8).
/// [source] is a work order (with `pro` / `contractor`) or a pro map.
/// Messaging only — there is no call fallback (Oct 1).
Future<void> openProThread(
  BuildContext context,
  Map<String, dynamic> source, {
  String? proName,
}) async {
  final nested = source['pro'] ?? source['contractor'];
  final pro = nested is Map
      ? Map<String, dynamic>.from(nested)
      : Map<String, dynamic>.from(source);
  var userId = StreamService.instance.resolveMessagingUserId(pro) ??
      StreamService.instance.resolveMessagingUserId(source) ??
      _text(source['contractorUserId']) ??
      _text(source['contractor_user_id']);

  if (userId == null) {
    final slug = _text(pro['slug']) ??
        _text(pro['profileSlug']) ??
        _text(pro['profile_slug']) ??
        _text(pro['businessSlug']) ??
        _text(pro['business_slug']) ??
        _text(source['proSlug']) ??
        _text(source['pro_slug']) ??
        _text(source['contractorSlug']) ??
        _text(source['contractor_slug']);
    if (slug != null) {
      try {
        final profile =
            await HomeownerService.instance.getContractorProfile(slug);
        userId = StreamService.instance.resolveMessagingUserId(profile);
      } catch (_) {
        // Fall through to the message below.
      }
    }
  }

  if (!context.mounted) return;
  if (userId == null || userId.isEmpty) {
    AppNotification.showInfo(
        context, 'Messaging is not available for this pro yet.');
    return;
  }
  final name = proName ??
      _text(pro['businessName']) ??
      _text(pro['business_name']) ??
      _text(pro['name']) ??
      'Your pro';
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatScreen(contractorId: userId!, contractorName: name),
    ),
  );
}
