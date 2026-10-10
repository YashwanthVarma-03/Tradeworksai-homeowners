import 'package:flutter/material.dart';

import '../theme.dart';

/// TradeWorks homeowner UI kit — design standard v3.3 (Batch 25).
///
/// Every screen takes its type, spacing, shape and components from here and
/// its colours from [AppTheme]. No screen sets its own font size, radius or
/// padding number. Values are in SPEC.md §1–§4.

// ---------------------------------------------------------------------------
// §1 Screen sizes
// ---------------------------------------------------------------------------

/// Compact < 360 · Regular 360–599 · Wide ≥ 600 (logical width).
enum TwSize { compact, regular, wide }

class TwLayout {
  TwLayout._();

  static TwSize size(BuildContext c) {
    final width = MediaQuery.sizeOf(c).width;
    if (width < 360) return TwSize.compact;
    if (width < 600) return TwSize.regular;
    return TwSize.wide;
  }

  /// Side gutter: 16 Compact, 20 Regular, 24 Wide.
  static double gutter(BuildContext c) => switch (size(c)) {
        TwSize.compact => 16.0,
        TwSize.regular => 20.0,
        TwSize.wide => 24.0,
      };

  /// Content is centred and capped at this width on Wide.
  static const double maxContent = 560;

  static int columns(BuildContext c,
          {int compact = 3, int regular = 4, int wide = 4}) =>
      switch (size(c)) {
        TwSize.compact => compact,
        TwSize.regular => regular,
        TwSize.wide => wide,
      };

  /// Label + value rows stack (label above value) on Compact or when the
  /// phone's text size is above 1.15×.
  static bool stackRows(BuildContext c) =>
      size(c) == TwSize.compact || textScale(c) > 1.15;

  /// The current text scale as a plain factor (1.0 = default).
  static double textScale(BuildContext c) =>
      MediaQuery.textScalerOf(c).scale(16) / 16;
}

/// The one page wrapper (§1.1): gutter on both sides, content centred and
/// capped at 560. Wrap the child of a scroll body with it.
class TwPage extends StatelessWidget {
  const TwPage({
    super.key,
    required this.child,
    this.top = 0,
    this.bottom = 28,
    this.fullBleed = false,
  });

  final Widget child;
  final double top;
  final double bottom;

  /// True for a full-width band (photo, hairline): no gutter, no cap.
  final bool fullBleed;

  @override
  Widget build(BuildContext context) {
    if (fullBleed) {
      return Padding(
        padding: EdgeInsets.only(top: top, bottom: bottom),
        child: child,
      );
    }
    final gutter = TwLayout.gutter(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: TwLayout.maxContent + gutter * 2),
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, top, gutter, bottom),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// §3 Spacing
// ---------------------------------------------------------------------------

/// Spacing scale. Between page sections 28 · heading → content 12 ·
/// inside cards 16 · between cards 12 · label → field 6.
class TwSpace {
  TwSpace._();
  static const s4 = 4.0,
      s8 = 8.0,
      s12 = 12.0,
      s16 = 16.0,
      s20 = 20.0,
      s28 = 28.0,
      s40 = 40.0;
}

// ---------------------------------------------------------------------------
// §2 Type — Outfit for headings and big numbers, Inter for everything else
// ---------------------------------------------------------------------------

class TwType {
  TwType._();

  static const String _outfit = 'Outfit';
  static const String _inter = 'Inter';

  static TextStyle _o(
          double size, double line, FontWeight weight, Color color) =>
      TextStyle(
        fontFamily: _outfit,
        fontSize: size,
        height: line / size,
        fontWeight: weight,
        color: color,
        letterSpacing: 0,
      );

  static TextStyle _i(
          double size, double line, FontWeight weight, Color color) =>
      TextStyle(
        fontFamily: _inter,
        fontSize: size,
        height: line / size,
        fontWeight: weight,
        color: color,
        letterSpacing: 0,
      );

  static bool _compact(BuildContext c) => TwLayout.size(c) == TwSize.compact;

  /// Outfit 32/38 (Compact 28/34) 700 — rewards balance.
  static TextStyle display(BuildContext c, {Color? color}) => _compact(c)
      ? _o(28, 34, FontWeight.w700, color ?? AppTheme.navy)
      : _o(32, 38, FontWeight.w700, color ?? AppTheme.navy);

  /// Outfit 28/34 (Compact 24/30) 700 — page heroes.
  static TextStyle h1(BuildContext c, {Color? color}) => _compact(c)
      ? _o(24, 30, FontWeight.w700, color ?? AppTheme.navy)
      : _o(28, 34, FontWeight.w700, color ?? AppTheme.navy);

  /// Outfit 40/44 (Compact 34/40) 700 — cap amount, big prices.
  static TextStyle number(BuildContext c, {Color? color}) => _compact(c)
      ? _o(34, 40, FontWeight.w700, color ?? AppTheme.navy)
      : _o(40, 44, FontWeight.w700, color ?? AppTheme.navy);

  /// Outfit 20/26 600 — section headings.
  static TextStyle h2({Color? color}) =>
      _o(20, 26, FontWeight.w600, color ?? AppTheme.navy);

  /// Outfit 17/22 600 — card titles.
  static TextStyle h3({Color? color}) =>
      _o(17, 22, FontWeight.w600, color ?? AppTheme.navy);

  /// Outfit 18/24 600 — every app bar title.
  static TextStyle appBarTitle({Color? color}) =>
      _o(18, 24, FontWeight.w600, color ?? AppTheme.navy);

  /// Outfit 20/26 600 — prices on cards and the price card.
  static TextStyle price({Color? color}) =>
      _o(20, 26, FontWeight.w600, color ?? AppTheme.navy);

  /// Inter 16/22 600 ink — row titles, list item names.
  static TextStyle title({Color? color}) =>
      _i(16, 22, FontWeight.w600, color ?? AppTheme.navy);

  /// Inter 16/24 400 body — reading text.
  static TextStyle body({Color? color}) =>
      _i(16, 24, FontWeight.w400, color ?? AppTheme.body);

  /// Inter 15/22 400 body — card descriptions, alert sentences.
  static TextStyle bodySm({Color? color}) =>
      _i(15, 22, FontWeight.w400, color ?? AppTheme.body);

  /// Inter 14/20 600 ink — field labels, detail-row labels.
  static TextStyle label({Color? color}) =>
      _i(14, 20, FontWeight.w600, color ?? AppTheme.navy);

  /// Inter 14/20 400 meta — secondary lines, dates.
  static TextStyle meta({Color? color}) =>
      _i(14, 20, FontWeight.w400, color ?? AppTheme.textSecondary);

  /// Inter 13/18 400 meta — footnotes, counters, helper text.
  static TextStyle caption({Color? color}) =>
      _i(13, 18, FontWeight.w400, color ?? AppTheme.textSecondary);

  /// Inter 15/22 600 blue (14/20 in section headers) — text actions.
  static TextStyle link({Color? color, double size = 15}) =>
      _i(size, size <= 14 ? 20 : 22, FontWeight.w600, color ?? AppTheme.blue);

  /// Inter 16/20 700 — all buttons. Navy on orange, ink on white.
  static TextStyle button({Color? color}) =>
      _i(16, 20, FontWeight.w700, color ?? AppTheme.navy);

  /// Inter 11.5/14 — bottom tab labels (600 selected, 500 not).
  static TextStyle tab({required bool selected}) => _i(
        11.5,
        14,
        selected ? FontWeight.w600 : FontWeight.w500,
        selected ? AppTheme.blue : AppTheme.body,
      );

  /// Inter 15/22 600 ink — the value side of a detail row.
  static TextStyle value({Color? color}) =>
      _i(15, 22, FontWeight.w600, color ?? AppTheme.navy);

  /// Outfit 24/30 700 — `h1` at sheet / gate size, fixed at every width:
  /// booking-sheet step headers (C01–C05), the A05 sign-in gate, the pro
  /// name on B02b.
  static TextStyle h1Sm({Color? color}) =>
      _o(24, 30, FontWeight.w700, color ?? AppTheme.navy);

  /// Outfit 26/32 (Compact 24/30) 700 — the work-order title (D03–D05) and
  /// the big totals in the booking review (C05).
  static TextStyle h1Mid(BuildContext c, {Color? color}) => _compact(c)
      ? _o(24, 30, FontWeight.w700, color ?? AppTheme.navy)
      : _o(26, 32, FontWeight.w700, color ?? AppTheme.navy);

  /// Outfit 22/28 700 — titles of the full-height intake and ZIP sheets
  /// (A06, A07).
  static TextStyle sheetTitle({Color? color}) =>
      _o(22, 28, FontWeight.w700, color ?? AppTheme.navy);
}

// ---------------------------------------------------------------------------
// §4 Elements
// ---------------------------------------------------------------------------

/// App bar for every pushed screen: white, no shadow, 1px hairline at the
/// bottom, 56 high, iOS back chevron in a 44 target, centred Outfit title.
PreferredSizeWidget TwAppBar({
  required String title,
  List<Widget> actions = const [],
  VoidCallback? onBack,
  bool showBack = true,
}) {
  return AppBar(
    backgroundColor: AppTheme.white,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    toolbarHeight: 56,
    centerTitle: true,
    automaticallyImplyLeading: false,
    leadingWidth: 56,
    titleSpacing: 0,
    iconTheme: const IconThemeData(color: AppTheme.navy, size: 22),
    actionsIconTheme: const IconThemeData(color: AppTheme.navy, size: 22),
    leading: showBack
        ? Builder(
            builder: (context) => Center(
              child: IconButton(
                tooltip: 'Back',
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: AppTheme.navy,
                ),
              ),
            ),
          )
        : null,
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TwType.appBarTitle(),
    ),
    actions: [...actions, const SizedBox(width: 6)],
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: SizedBox(
        height: 1,
        width: double.infinity,
        child: ColoredBox(color: AppTheme.cardBorder),
      ),
    ),
  );
}

/// Section heading (`h2`) with an optional blue text action on the right
/// ("See all 22", 14/600) and an optional meta line under the heading.
///
/// [trailing] and [meta] take a `String` (rendered in the kit style) or a
/// ready-made `Widget`.
class TwSectionHeader extends StatelessWidget {
  const TwSectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.onTrailingTap,
    this.meta,
  });

  final String title;
  final Object? trailing;
  final VoidCallback? onTrailingTap;
  final Object? meta;

  @override
  Widget build(BuildContext context) {
    Widget? trailingWidget;
    final t = trailing;
    if (t is Widget) {
      trailingWidget = t;
    } else if (t != null && '$t'.isNotEmpty) {
      trailingWidget = _TwTapTarget(
        onTap: onTrailingTap,
        child: Text('$t', style: TwType.link(size: 14)),
      );
    }
    Widget? metaWidget;
    final m = meta;
    if (m is Widget) {
      metaWidget = m;
    } else if (m != null && '$m'.isNotEmpty) {
      metaWidget = Text('$m', style: TwType.meta());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: TwType.h2()),
              ),
            ),
            if (trailingWidget != null) ...[
              const SizedBox(width: TwSpace.s12),
              trailingWidget,
            ],
          ],
        ),
        if (metaWidget != null) ...[
          const SizedBox(height: TwSpace.s4),
          metaWidget,
        ],
      ],
    );
  }
}

/// A 44-high tap target around inline text (links), with no visible chrome.
class _TwTapTarget extends StatelessWidget {
  const _TwTapTarget({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Align(
          widthFactor: 1,
          heightFactor: 1,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

/// White card, 1px hairline, radius 14, padding 16. Tappable cards get an
/// ink ripple and no shadow.
class TwCard extends StatelessWidget {
  const TwCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Grouped read-only facts: `subtle` fill, no border, radius 12, padding 16.
class TwFactPanel extends StatelessWidget {
  const TwFactPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.subtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

/// Label (`meta`, 96 column) + value (15/600 ink). Stacks — label above
/// value — on Compact or at text scale > 1.15.
class TwDetailRow extends StatelessWidget {
  const TwDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueWidget,
  });

  final String label;
  final String value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final valueChild = valueWidget ?? Text(value, style: TwType.value());
    final labelChild = Text(label, style: TwType.meta());
    if (TwLayout.stackRows(context)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            labelChild,
            const SizedBox(height: 2),
            valueChild,
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: labelChild),
          const SizedBox(width: TwSpace.s12),
          Expanded(child: valueChild),
        ],
      ),
    );
  }
}

Widget? _twIcon(Object? icon, Color color, double size) {
  if (icon == null) return null;
  if (icon is IconData) return Icon(icon, size: size, color: color);
  if (icon is Widget) {
    return IconTheme.merge(
      data: IconThemeData(color: color, size: size),
      child: icon,
    );
  }
  return null;
}

/// Orange fill, navy label, 52 high, radius 12. Full width by default; min
/// width 120 inline. Loading shows a navy spinner. One per screen.
///
/// [icon] takes an `IconData` or a `Widget`.
class TwPrimaryButton extends StatelessWidget {
  const TwPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expand = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;
  final Object? icon;

  @override
  Widget build(BuildContext context) {
    final iconWidget = _twIcon(icon, AppTheme.navy, 20);
    final Widget content = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppTheme.navy,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconWidget != null) ...[
                iconWidget,
                const SizedBox(width: TwSpace.s8),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TwType.button(
                    color: onPressed == null
                        ? AppTheme.navy.withOpacity(0.6)
                        : AppTheme.navy,
                  ),
                ),
              ),
            ],
          );
    final button = ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.orange,
        foregroundColor: AppTheme.navy,
        // While loading the button keeps its full colour; only a truly
        // disabled button fades (orange 40%, navy label 60%).
        disabledBackgroundColor:
            loading ? AppTheme.orange : AppTheme.orange.withOpacity(0.4),
        disabledForegroundColor: AppTheme.navy.withOpacity(0.6),
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: Size(expand ? 64 : 120, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        textStyle: TwType.button(),
      ),
      child: content,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// White, 1px #D0D5DD, ink label, 48 high (pass 52 when paired with a
/// primary), radius 12.
///
/// [icon] takes an `IconData` or a `Widget`.
class TwSecondaryButton extends StatelessWidget {
  const TwSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
    this.icon,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final Object? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final iconWidget = _twIcon(icon, AppTheme.navy, 18);
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.navy,
        disabledForegroundColor: AppTheme.textTertiary,
        side: const BorderSide(color: AppTheme.border),
        elevation: 0,
        minimumSize: Size(44, height),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        textStyle: TwType.button().copyWith(fontWeight: FontWeight.w600),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconWidget != null) ...[
            iconWidget,
            const SizedBox(width: TwSpace.s8),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TwType.button(
                color:
                    onPressed == null ? AppTheme.textTertiary : AppTheme.navy,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Blue text action (`link`), 44-high target, no underline. Destructive
/// actions are red text — never a red-filled button.
class TwTextAction extends StatelessWidget {
  const TwTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null
        ? AppTheme.textTertiary
        : (destructive ? AppTheme.red : AppTheme.blue);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        tapTargetSize: MaterialTapTargetSize.padded,
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: TwType.link(color: color),
      ),
      child: Text(label, style: TwType.link(color: color)),
    );
  }
}

/// Sticky action bar (§1.6): white, `floatShadow`, gutter left/right, 12 top,
/// 12 + bottom safe-area inset. Two buttons sit side by side at Regular/Wide
/// and default text size; on Compact or at text scale > 1.15 they stack
/// full width with the primary on top, whatever order they were passed in
/// (callers pass [secondary, primary], which is the side-by-side order).
///
/// [note] is one centred `caption` line, above the buttons by default
/// (E06 "This will publish as …"); set [noteBelow] where the mockup draws
/// the hint under the button (F03 "Save is enabled once something changes",
/// F09 "We usually reply by email within 1 business day.").
class TwStickyBar extends StatelessWidget {
  const TwStickyBar({
    super.key,
    required this.children,
    this.note,
    this.noteBelow = false,
  });

  final List<Widget> children;
  final String? note;
  final bool noteBelow;

  @override
  Widget build(BuildContext context) {
    final gutter = TwLayout.gutter(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final stacked = children.length > 1 && TwLayout.stackRows(context);

    Widget buttons;
    if (children.isEmpty) {
      buttons = const SizedBox.shrink();
    } else if (children.length == 1) {
      buttons = SizedBox(width: double.infinity, child: children.first);
    } else if (stacked) {
      final ordered = [
        ...children.where((w) => w is TwPrimaryButton),
        ...children.where((w) => w is! TwPrimaryButton),
      ];
      buttons = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < ordered.length; i++) ...[
            if (i > 0) const SizedBox(height: TwSpace.s8),
            ordered[i],
          ],
        ],
      );
    } else {
      buttons = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: TwSpace.s12),
            Expanded(child: children[i]),
          ],
        ],
      );
    }

    final noteText = note?.trim() ?? '';
    final Widget? noteWidget = noteText.isEmpty
        ? null
        : Text(
            noteText,
            textAlign: TextAlign.center,
            style: TwType.caption(),
          );

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        boxShadow: AppTheme.floatShadow,
      ),
      padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 12 + bottomInset),
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: TwLayout.maxContent),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (noteWidget != null && !noteBelow) ...[
                noteWidget,
                const SizedBox(height: TwSpace.s8),
              ],
              buttons,
              if (noteWidget != null && noteBelow) ...[
                const SizedBox(height: TwSpace.s8),
                noteWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Radio card / service tile / response level (§4 Selection). Radius 14,
/// padding 14/16, min height 64. Selected: blue tint, 1.5px blue, blue radio.
///
/// [trailing] takes a `String` (16/700 ink value) or a `Widget`.
class TwSelectTile extends StatelessWidget {
  const TwSelectTile({
    super.key,
    required this.selected,
    required this.onTap,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showRadio = true,
  });

  final bool selected;
  final VoidCallback? onTap;
  final String title;
  final String? subtitle;
  final Object? trailing;
  final bool showRadio;

  @override
  Widget build(BuildContext context) {
    final t = trailing;
    Widget? trailingWidget;
    if (t is Widget) {
      trailingWidget = t;
    } else if (t != null && '$t'.isNotEmpty) {
      trailingWidget = Text(
        '$t',
        textAlign: TextAlign.right,
        style: TwType.title().copyWith(fontWeight: FontWeight.w700),
      );
    }
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: showRadio,
      child: Material(
        color: selected ? AppTheme.blueTint : AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppTheme.blue : AppTheme.cardBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  if (showRadio) ...[
                    _TwRadio(selected: selected),
                    const SizedBox(width: TwSpace.s12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TwType.title(),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: TwType.meta()),
                        ],
                      ],
                    ),
                  ),
                  if (trailingWidget != null) ...[
                    const SizedBox(width: TwSpace.s12),
                    trailingWidget,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TwRadio extends StatelessWidget {
  const _TwRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppTheme.blue : AppTheme.border,
          width: 1.5,
        ),
      ),
      child: selected
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.blue,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

/// Filter chip, quick tag, date pill or time window. 44 high; full radius,
/// or radius 12 with [square] (time windows). Selected: blue tint, 1.5px
/// blue, blue 15/600 text.
class TwPill extends StatelessWidget {
  const TwPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.square = false,
    this.height = 44,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool square;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = square ? AppTheme.radius : height / 2;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppTheme.blueTint : AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: selected ? AppTheme.blue : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height, minWidth: 44),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    height: 20 / 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppTheme.blue : AppTheme.navy,
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

/// Day tile: 92×60 (Compact 80×56), radius 12. Weekday 15/600 ink on top,
/// date 13 meta under. Selected: blue tint + 1.5px blue, ink text.
///
/// Tiles live in a horizontal list, which gives them a fixed height: size
/// that list with [TwDayTile.heightOf] so the two lines never clip at 1.3×.
class TwDayTile extends StatelessWidget {
  const TwDayTile({
    super.key,
    required this.top,
    required this.bottom,
    required this.selected,
    required this.onTap,
  });

  /// 60 (Compact 56), or taller when the phone's text size needs it:
  /// 12 padding + 20 + 2 + 18 line heights, scaled.
  static double heightOf(BuildContext c) {
    final base = TwLayout.size(c) == TwSize.compact ? 56.0 : 60.0;
    final scaler = MediaQuery.textScalerOf(c);
    final content =
        14 + scaler.scale(15) * 20 / 15 + scaler.scale(13) * 18 / 13;
    return content > base ? content.ceilToDouble() : base;
  }

  final String top;
  final String bottom;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final compact = TwLayout.size(context) == TwSize.compact;
    return Semantics(
      selected: selected,
      button: true,
      child: SizedBox(
        width: compact ? 80 : 92,
        child: Material(
          color: selected ? AppTheme.blueTint : AppTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            side: BorderSide(
              color: selected ? AppTheme.blue : AppTheme.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: compact ? 56 : 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      top,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TwType.title().copyWith(
                        fontSize: 15,
                        height: 20 / 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bottom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TwType.caption(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pro avatar: rounded square (radius = size/4: 12 at 48), photo `cover`,
/// fallback navy fill with white Outfit 600 initials at size × 0.36.
class TwAvatar extends StatelessWidget {
  const TwAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 48,
  });

  final String name;
  final String? imageUrl;
  final double size;

  static String initialsOf(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    final first = words.first.substring(0, 1);
    final second = words.length > 1 ? words[1].substring(0, 1) : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size / 4);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppTheme.navy, borderRadius: radius),
      child: Text(
        initialsOf(name),
        maxLines: 1,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: size * 0.36,
          height: 1,
          fontWeight: FontWeight.w600,
          color: AppTheme.white,
        ),
      ),
    );
    final url = imageUrl?.trim() ?? '';
    return Semantics(
      label: name,
      image: true,
      excludeSemantics: true,
      child: url.isEmpty
          ? fallback
          : ClipRRect(
              borderRadius: radius,
              child: Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
            ),
    );
  }
}

/// Round icon well: 36 (18 icon) by default; 56 (24 icon) in empty states.
class TwIconWell extends StatelessWidget {
  const TwIconWell(
    this.icon, {
    super.key,
    this.size = 36,
    this.background = AppTheme.subtle,
    this.color = AppTheme.navy,
  });

  final IconData icon;
  final double size;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final iconSize = (size * 0.5).clamp(16.0, 24.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

/// Field label above the field (`label`), 6 below. "(optional)" in meta.
class TwFieldLabel extends StatelessWidget {
  const TwFieldLabel(this.text, {super.key, this.optional = false});

  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          text: text,
          style: TwType.label(),
          children: [
            if (optional)
              TextSpan(
                text: ' (optional)',
                style: TwType.meta(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Input decoration (§4 Inputs): `subtle` fill, 1px hairline, radius 12,
/// 16px horizontal and 12px vertical padding for the mockups' 48px fields.
/// Focus: 1.5px blue, white fill. Error:
/// 1.5px red + red caption.
class TwInputs {
  TwInputs._();

  static OutlineInputBorder _border(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        borderSide: BorderSide(color: color, width: width),
      );

  static InputDecoration decoration({
    String? hint,
    String? counterText,
    Widget? suffix,
    Widget? prefix,
    BoxConstraints? prefixConstraints,
    String? errorText,
    Color restBorder = AppTheme.cardBorder,
    Color? fillColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TwType.body(color: AppTheme.textTertiary),
      hintMaxLines: 3,
      counterText: counterText,
      counterStyle: TwType.caption(),
      suffixIcon: suffix,
      prefixIcon: prefix,
      prefixIconConstraints: prefix == null
          ? null
          : prefixConstraints ??
              const BoxConstraints(minWidth: 44, minHeight: 44),
      errorText: errorText,
      errorStyle: TwType.caption(color: AppTheme.red),
      errorMaxLines: 3,
      isDense: false,
      filled: true,
      fillColor: fillColor ??
          WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? AppTheme.white
                : AppTheme.subtle,
          ),
      contentPadding: EdgeInsets.symmetric(
          horizontal: 16, vertical: prefix == null ? 12 : 0),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      border: _border(restBorder, 1),
      enabledBorder: _border(restBorder, 1),
      disabledBorder: _border(restBorder, 1),
      focusedBorder: _border(AppTheme.blue, 1.5),
      errorBorder: _border(AppTheme.red, 1.5),
      focusedErrorBorder: _border(AppTheme.red, 1.5),
    );
  }

  /// Editable content inside a separately bordered search or voice surface.
  /// Every state stays borderless so the parent draws exactly one outline.
  static InputDecoration borderless({
    String? hint,
    Widget? prefix,
    BoxConstraints? prefixConstraints,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TwType.body(color: AppTheme.textTertiary),
        prefixIcon: prefix,
        prefixIconConstraints: prefixConstraints,
        isDense: true,
        filled: false,
        contentPadding: padding,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
      );

  /// Counter text "0 / 2,000" with thousands separators.
  static String count(int length, int max) =>
      '${_thousands(length)} / ${_thousands(max)}';

  static String _thousands(int n) {
    final s = n.abs().toString();
    final b = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}

/// Bottom sheet (§1.5): top radius 20, grabber 36×4, max width 560 centred,
/// max height 92% of the screen. The builder's content should scroll
/// inside and keep its action bar pinned.
class TwSheet {
  TwSheet._();

  static Future<T?> show<T>(
    BuildContext c, {
    required WidgetBuilder builder,
    bool scrollControlled = true,
  }) {
    final height = MediaQuery.sizeOf(c).height;
    return showModalBottomSheet<T>(
      context: c,
      isScrollControlled: scrollControlled,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: AppTheme.white,
      elevation: 0,
      barrierColor: const Color(0x73101828),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(
        maxWidth: TwLayout.maxContent,
        maxHeight: height * 0.92,
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TwSheetGrabber(),
          Flexible(child: builder(context)),
        ],
      ),
    );
  }
}

/// The 36×4 sheet grabber, 10 from the top.
class TwSheetGrabber extends StatelessWidget {
  const TwSheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Underline tabs (Bookings, Inbox, Reset): 48 high, 15/600 labels, the
/// selected one blue with a 2px underline, optional counts in a blue-tint
/// pill, hairline under the whole bar. [counts] maps tab index → count.
class TwUnderlineTabs extends StatelessWidget {
  const TwUnderlineTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.counts = const {},
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final Map<int, int> counts;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == index,
                button: true,
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color:
                              i == index ? AppTheme.blue : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              height: 20 / 15,
                              fontWeight: i == index
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: i == index ? AppTheme.blue : AppTheme.body,
                            ),
                          ),
                        ),
                        if ((counts[i] ?? 0) > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppTheme.blueTint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${counts[i]}',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                height: 1,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.blue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Empty state: 56 icon well (`subtle`, 24 ink icon), `h3` title, one
/// `bodySm` meta sentence, optional single (secondary) action. Centred,
/// max width 320.
class TwEmptyState extends StatelessWidget {
  const TwEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: TwLayout.gutter(context),
          vertical: TwSpace.s28,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TwIconWell(icon, size: 56),
              const SizedBox(height: TwSpace.s16),
              Text(title, textAlign: TextAlign.center, style: TwType.h3()),
              if (message != null && message!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TwType.bodySm(color: AppTheme.textSecondary),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: TwSpace.s20),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
