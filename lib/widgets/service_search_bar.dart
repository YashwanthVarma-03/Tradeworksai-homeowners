import 'package:flutter/material.dart';

import '../theme.dart';
import '../ui/tw.dart';

/// The shared service search control used throughout the homeowner app.
///
/// v3.3 §4 (A01/B01): 56 high, full radius, white, 1px #D0D5DD, no shadow.
/// Search icon 20 ink; placeholder 15 in `body`; typed text 15/600 ink.
/// Camera and mic are outline icons 20 ink in 40×44 targets, then a 1×20
/// hairline and a 44 orange go button with a navy arrow. On Compact the
/// camera button hides (the mic stays).
///
/// The action cluster is deliberately a sibling of the editable field rather
/// than a TextField suffix. That keeps the submit button inside the rounded
/// surface at every supported phone width.
class ServiceSearchBar extends StatelessWidget {
  const ServiceSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onPhotoTap,
    required this.onVoiceTap,
    this.onChanged,
    this.onTap,
    this.onTapOutside,
    this.hint,
    this.emptyOverlay,
    this.borderColor = AppTheme.border,
    this.showShadow = false,
    this.textColor = AppTheme.navy,
  }) : assert(hint == null || emptyOverlay == null);

  static const double height = 56;
  static const double _leftInset = 46;

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final VoidCallback onPhotoTap;
  final VoidCallback onVoiceTap;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final TapRegionCallback? onTapOutside;
  final String? hint;
  final Widget? emptyOverlay;

  /// Rest border. The hairline (#E6E8EC) older callers pass is read as the
  /// v3.3 rest border #D0D5DD; blue (focus) draws 1.5px.
  final Color borderColor;

  /// Retained for API compatibility. v3.3 search bars have no shadow, so it
  /// is ignored.
  final bool showShadow;
  final Color textColor;

  /// Placeholder style for callers that build their own [emptyOverlay].
  static TextStyle get placeholderStyle => TwType.bodySm();

  @override
  Widget build(BuildContext context) {
    final isEmpty = controller.text.trim().isEmpty;
    final compact = TwLayout.size(context) == TwSize.compact;
    final focused = borderColor == AppTheme.blue;
    final restBorder =
        borderColor == AppTheme.cardBorder ? AppTheme.border : borderColor;

    return Container(
      width: double.infinity,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: restBorder, width: focused ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.search,
                  onTap: onTap,
                  onTapOutside: onTapOutside ?? (_) => focusNode.unfocus(),
                  onChanged: onChanged,
                  onSubmitted: (_) => onSubmit(),
                  showCursor: focusNode.hasFocus,
                  cursorColor: AppTheme.navy,
                  cursorHeight: 18,
                  cursorWidth: 1.5,
                  cursorRadius: const Radius.circular(0.75),
                  maxLines: 1,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontInter,
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  decoration: TwInputs.borderless(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 16, right: 10),
                      child: Icon(
                        Icons.search_rounded,
                        color: AppTheme.navy,
                        size: 20,
                      ),
                    ),
                    prefixConstraints: const BoxConstraints(
                        minWidth: _leftInset, minHeight: 44),
                  ),
                ),
                if (isEmpty &&
                    !focusNode.hasFocus &&
                    (hint != null || emptyOverlay != null))
                  Positioned(
                    left: _leftInset,
                    right: 4,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: emptyOverlay ??
                            Text(
                              hint!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TwType.bodySm().copyWith(height: 1.2),
                            ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!compact)
            _ActionButton(
              tooltip: 'Describe with a photo',
              icon: Icons.photo_camera_outlined,
              onPressed: onPhotoTap,
            ),
          _ActionButton(
            tooltip: 'Describe with voice',
            icon: Icons.mic_none_rounded,
            onPressed: onVoiceTap,
          ),
          Container(
            height: 20,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: AppTheme.cardBorder,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 5),
            child: Semantics(
              button: true,
              label: 'Search',
              child: Material(
                color: AppTheme.orange,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSubmit,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: AppTheme.onOrange,
                      size: 22,
                    ),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 44,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 40, height: 44),
        icon: Icon(icon, color: AppTheme.navy, size: 20),
      ),
    );
  }
}
