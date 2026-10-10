import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../ui/tw.dart';
import '../utils/app_error_utils.dart';

enum AppNotificationTone { error, success, info }

/// A single, app-level notification surface for transient feedback.
///
/// Errors are deliberately translated before display so implementation details
/// from APIs never appear in the customer experience.
class AppNotification {
  AppNotification._();

  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  static void showError(
    BuildContext context,
    Object error, {
    String fallback = 'We couldn\'t complete that request. Please try again.',
  }) {
    show(
      context,
      message: AppErrorUtils.friendlyMessage(error, fallback: fallback),
      tone: AppNotificationTone.error,
    );
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message: message, tone: AppNotificationTone.success);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, message: message, tone: AppNotificationTone.info);
  }

  static void show(
    BuildContext context, {
    required String message,
    required AppNotificationTone tone,
    Duration duration = const Duration(seconds: 5),
  }) {
    if (!context.mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _dismissTimer?.cancel();
    _activeEntry?.remove();

    late final OverlayEntry entry;
    void dismiss() {
      if (_activeEntry != entry) return;
      _dismissTimer?.cancel();
      entry.remove();
      _activeEntry = null;
    }

    entry = OverlayEntry(
      builder: (overlayContext) => _TopNotification(
        message: message,
        tone: tone,
        onDismiss: dismiss,
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
    _dismissTimer = Timer(duration, dismiss);
  }
}

/// v3.3: the notification reads like an alert row — white card, hairline,
/// radius 14, `floatShadow`, a 36 tinted circle with an 18 icon and an ink
/// sentence. No white text on a coloured fill. Centred, max 560.
class _TopNotification extends StatelessWidget {
  const _TopNotification({
    required this.message,
    required this.tone,
    required this.onDismiss,
  });

  final String message;
  final AppNotificationTone tone;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final (tint, iconColor, icon, label) = switch (tone) {
      AppNotificationTone.error => (
          AppTheme.redTint,
          AppTheme.red,
          Icons.error_outline_rounded,
          'Error',
        ),
      AppNotificationTone.success => (
          AppTheme.greenTint,
          AppTheme.green,
          Icons.check_circle_outline_rounded,
          'Success',
        ),
      AppNotificationTone.info => (
          AppTheme.blueTint,
          AppTheme.blue,
          Icons.info_outline_rounded,
          'Information',
        ),
    };
    final gutter = TwLayout.gutter(context);

    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: gutter,
      right: gutter,
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: TwLayout.maxContent),
          child: Semantics(
            liveRegion: true,
            label: '$label: $message',
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Transform.translate(
                  offset: Offset(0, -12 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.cardBorder),
                    boxShadow: AppTheme.floatShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: tint,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TwType.bodySm(color: AppTheme.navy)
                              .copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Dismiss notification',
                        onPressed: onDismiss,
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
