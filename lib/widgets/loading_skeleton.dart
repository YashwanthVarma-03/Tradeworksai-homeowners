import 'package:flutter/material.dart';
import '../theme.dart';

enum SkeletonLayout {
  cards,
  form,
  profile,
  chat,
  home,
  browse,
  results,
  bookings,
  rewards,
  inbox,
}

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
                children: _layoutChildren(),
              ),
            ),
          ),
        ),
      );

  List<Widget> _layoutChildren() => switch (layout) {
        SkeletonLayout.form => _formLayout(),
        SkeletonLayout.profile => _profileLayout(),
        SkeletonLayout.chat => _chatLayout(),
        SkeletonLayout.home => _homeLayout(),
        SkeletonLayout.browse => _browseLayout(),
        SkeletonLayout.results => _resultCards(itemCount),
        SkeletonLayout.bookings => _bookingsLayout(),
        SkeletonLayout.rewards => _rewardsLayout(),
        SkeletonLayout.inbox => _inboxLayout(),
        SkeletonLayout.cards => _resultCards(itemCount),
      };

  List<Widget> _resultCards(int count) => [
        for (var i = 0; i < count; i++) ...[
          _card(avatar: true, lines: 2, action: true),
          if (i != count - 1) const SizedBox(height: 12),
        ],
      ];

  List<Widget> _formLayout() => [
        const SkeletonBlock(width: 190, height: 22),
        const SizedBox(height: 10),
        const FractionallySizedBox(
          widthFactor: .82,
          alignment: Alignment.centerLeft,
          child: SkeletonBlock(height: 12),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < itemCount; i++) ...[
          const SkeletonBlock(width: 92, height: 12),
          const SizedBox(height: 8),
          const SkeletonBlock(height: 52),
          if (i != itemCount - 1) const SizedBox(height: 18),
        ],
      ];

  List<Widget> _profileLayout() => [
        Row(
          children: const [
            SkeletonBlock(width: 72, height: 72),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    widthFactor: .72,
                    child: SkeletonBlock(height: 18),
                  ),
                  SizedBox(height: 10),
                  FractionallySizedBox(
                    widthFactor: .48,
                    child: SkeletonBlock(height: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _card(lines: 3, action: false),
        const SizedBox(height: 12),
        _card(lines: 2, action: true),
      ];

  List<Widget> _chatLayout() => [
        for (var i = 0; i < itemCount + 1; i++) ...[
          Align(
            alignment: i.isOdd ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: i.isOdd ? .66 : .78,
              child: SkeletonBlock(height: i.isOdd ? 54 : 72),
            ),
          ),
          if (i != itemCount) const SizedBox(height: 14),
        ],
      ];

  List<Widget> _homeLayout() => [
        const SkeletonBlock(width: 180, height: 18),
        const SizedBox(height: 28),
        const SkeletonBlock(width: 250, height: 30),
        const SizedBox(height: 18),
        const SkeletonBlock(height: 56),
        const SizedBox(height: 28),
        _card(avatar: true, lines: 2, action: true),
        const SizedBox(height: 28),
        const SkeletonBlock(width: 170, height: 20),
        const SizedBox(height: 14),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              const Expanded(child: SkeletonBlock(height: 108)),
            ],
          ],
        ),
      ];

  List<Widget> _browseLayout() => [
        const SkeletonBlock(height: 56),
        const SizedBox(height: 12),
        const SkeletonBlock(width: 190, height: 44),
        const SizedBox(height: 18),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              const Expanded(child: SkeletonBlock(height: 86)),
            ],
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: const [
            SkeletonBlock(width: 96, height: 22),
            Spacer(),
            SkeletonBlock(width: 70, height: 14),
          ],
        ),
        const SizedBox(height: 14),
        ..._resultCards(2),
      ];

  List<Widget> _bookingsLayout() => [
        Row(
          children: const [
            Expanded(child: SkeletonBlock(height: 44)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBlock(height: 44)),
          ],
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < itemCount; i++) ...[
          _card(avatar: true, lines: 3, action: true),
          if (i != itemCount - 1) const SizedBox(height: 12),
        ],
      ];

  List<Widget> _rewardsLayout() => [
        const SkeletonBlock(width: 150, height: 24),
        const SizedBox(height: 16),
        const SkeletonBlock(height: 150),
        const SizedBox(height: 16),
        const SkeletonBlock(height: 72),
        const SizedBox(height: 28),
        const SkeletonBlock(width: 180, height: 20),
        const SizedBox(height: 12),
        ..._resultCards(2),
      ];

  List<Widget> _inboxLayout() => [
        Row(
          children: const [
            Expanded(child: SkeletonBlock(height: 44)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBlock(height: 44)),
          ],
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < itemCount + 1; i++) ...[
          Row(
            children: const [
              SkeletonBlock(width: 48, height: 48),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: .62,
                      child: SkeletonBlock(height: 14),
                    ),
                    SizedBox(height: 8),
                    SkeletonBlock(height: 11),
                  ],
                ),
              ),
            ],
          ),
          if (i != itemCount) const SizedBox(height: 20),
        ],
      ];

  Widget _card({
    bool avatar = false,
    int lines = 2,
    bool action = true,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.cardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (avatar)
              Row(
                children: const [
                  SkeletonBlock(width: 44, height: 44),
                  SizedBox(width: 12),
                  Expanded(
                    child: FractionallySizedBox(
                      widthFactor: .62,
                      alignment: Alignment.centerLeft,
                      child: SkeletonBlock(height: 16),
                    ),
                  ),
                ],
              )
            else
              const FractionallySizedBox(
                widthFactor: .55,
                alignment: Alignment.centerLeft,
                child: SkeletonBlock(height: 16),
              ),
            const SizedBox(height: 12),
            for (var i = 0; i < lines; i++) ...[
              FractionallySizedBox(
                widthFactor: i == lines - 1 ? .72 : 1,
                alignment: Alignment.centerLeft,
                child: const SkeletonBlock(height: 12),
              ),
              if (i != lines - 1) const SizedBox(height: 8),
            ],
            if (action) ...[
              const SizedBox(height: 16),
              const SkeletonBlock(width: 112, height: 36),
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
