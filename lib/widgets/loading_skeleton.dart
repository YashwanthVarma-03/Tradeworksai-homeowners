import 'package:flutter/material.dart';
import '../theme.dart';

enum SkeletonLayout { cards, form, profile, chat }

/// Static placeholders avoid distracting motion and respect reduced motion.
/// One accessible loading announcement replaces meaningless placeholder text.
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({
    super.key,
    this.layout = SkeletonLayout.cards,
    this.itemCount = 3,
    this.label = 'Loading content',
  });

  final SkeletonLayout layout;
  final int itemCount;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        liveRegion: true,
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (layout == SkeletonLayout.profile) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: SkeletonBlock(width: 72, height: 72),
                    ),
                    const SizedBox(height: 20),
                  ],
                  for (var i = 0; i < itemCount; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Align(
                        alignment: layout == SkeletonLayout.chat && i.isOdd
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: layout == SkeletonLayout.chat ? .78 : 1,
                          child: _placeholder(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _placeholder() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.cardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FractionallySizedBox(
                widthFactor: .55, child: SkeletonBlock(height: 16)),
            const SizedBox(height: 12),
            const SkeletonBlock(height: 12),
            if (layout != SkeletonLayout.form) ...[
              const SizedBox(height: 8),
              const FractionallySizedBox(
                  widthFactor: .75, child: SkeletonBlock(height: 12)),
              const SizedBox(height: 16),
              const SkeletonBlock(width: 96, height: 28),
            ],
          ],
        ),
      );
}

/// Use for a full page; [LoadingSkeleton] itself also fits inside scrollables.
class SkeletonPage extends StatelessWidget {
  const SkeletonPage(
      {super.key,
      this.layout = SkeletonLayout.cards,
      this.label = 'Loading content'});
  final SkeletonLayout layout;
  final String label;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: LoadingSkeleton(layout: layout, label: label),
      );
}

class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, this.width, required this.height});
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.cardBorder.withOpacity(.55),
          borderRadius: BorderRadius.circular(6),
        ),
      );
}
