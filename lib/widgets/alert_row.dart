import 'package:flutter/material.dart';

import '../theme.dart';

/// Design standard v3.3, rule 7: alerts are rows, not banners — a 36px tinted
/// circle with an icon, a bold line, one sentence and a blue text action,
/// inside a hairline card.
class AlertRow extends StatelessWidget {
  const AlertRow({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.eyebrow,
    this.footer,
    this.tint = AppTheme.amberTint,
    this.iconColor = AppTheme.amber,
  });

  final IconData icon;
  final String title;
  final String? body;

  /// Optional line above the title — the amber "Waiting on you" dot + word.
  final Widget? eyebrow;

  /// Actions under the sentence: a blue text link, or Accept / Decline.
  final Widget? footer;
  final Color tint;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[eyebrow!, const SizedBox(height: 4)],
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 15,
                    height: 21 / 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (body != null && body!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body!,
                    style: const TextStyle(
                      color: AppTheme.body,
                      fontSize: 14,
                      height: 20 / 14,
                    ),
                  ),
                ],
                if (footer != null) ...[const SizedBox(height: 2), footer!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The amber "Waiting on you" mark: a dot and the words (v3.3 status rule).
class WaitingOnYouMark extends StatelessWidget {
  const WaitingOnYouMark({super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.amber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Waiting on you',
            style: TextStyle(
              color: AppTheme.amber,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}
