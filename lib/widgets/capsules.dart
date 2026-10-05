import 'package:flutter/material.dart';

import '../theme.dart';

/// The two compact facts used together on pro cards.
class RatingCapsule extends StatelessWidget {
  const RatingCapsule({
    super.key,
    required this.rating,
    this.count,
    this.compact = false,
  });

  final num rating;
  final int? count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final value = rating.toStringAsFixed(1);
    final reviews = count ?? 0;
    final noun = reviews == 1 ? 'review' : 'reviews';
    final countText = reviews <= 0
        ? ''
        : compact
            ? ' ($reviews)'
            : ' ($reviews $noun)';
    return Semantics(
      label: reviews <= 0
          ? 'Rated $value out of 5'
          : 'Rated $value out of 5 from $reviews $noun',
      excludeSemantics: true,
      child: _Capsule(
        background: AppTheme.ratingTint,
        icon: const Icon(Icons.star_rounded, size: 14, color: AppTheme.gold),
        text: Text.rich(
          TextSpan(
            text: value,
            children: [
              if (countText.isNotEmpty)
                TextSpan(
                  text: countText,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
            ],
          ),
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(
            color: AppTheme.ratingText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class AvailabilityCapsule extends StatelessWidget {
  const AvailabilityCapsule({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => _Capsule(
        background: AppTheme.greenTint,
        icon: const Icon(
          Icons.calendar_today_outlined,
          size: 14,
          color: AppTheme.green,
        ),
        text: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(
            color: AppTheme.green,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      );
}

class _Capsule extends StatelessWidget {
  const _Capsule({
    required this.background,
    required this.icon,
    required this.text,
  });

  final Color background;
  final Widget icon;
  final Widget text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        heightFactor: 1,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [icon, const SizedBox(width: 5), text],
          ),
        ),
      );
}
