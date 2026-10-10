import 'package:flutter/material.dart';

import '../ui/tw.dart';
import '../utils/app_error_utils.dart';

/// v3.3 empty-state look (§4 Empty states): 56 `subtle` icon well with an
/// ink icon, `h3` title, one `bodySm` meta sentence and one secondary
/// "Retry" button. Centred, max width 320. No card, no shadow, no white
/// label on orange.
class OfflineState extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;
  final String title;
  final IconData icon;

  const OfflineState({
    super.key,
    required this.onRetry,
    this.message,
    this.title = AppErrorUtils.noInternetTitle,
    this.icon = Icons.wifi_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final text = message?.trim().isNotEmpty == true
        ? message!.trim()
        : AppErrorUtils.noInternetMessage;

    return TwEmptyState(
      icon: icon,
      title: title,
      message: text,
      action: TwSecondaryButton(
        label: 'Retry',
        icon: Icons.refresh_rounded,
        expand: false,
        onPressed: onRetry,
      ),
    );
  }
}
