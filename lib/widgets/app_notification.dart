import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
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
    final (background, icon, label) = switch (tone) {
      AppNotificationTone.error => (
          AppTheme.red,
          Icons.error_outline_rounded,
          'Error',
        ),
      AppNotificationTone.success => (
          AppTheme.success,
          Icons.check_circle_outline_rounded,
          'Success',
        ),
      AppNotificationTone.info => (
          AppTheme.navy700,
          Icons.info_outline_rounded,
          'Information',
        ),
    };

    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 16,
      right: 16,
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
              constraints: const BoxConstraints(maxWidth: 640),
              margin: const EdgeInsets.symmetric(horizontal: 0),
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.navy.withOpacity(0.2),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dismiss notification',
                    onPressed: onDismiss,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
