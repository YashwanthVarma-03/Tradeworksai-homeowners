import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

/// The shared service search control used throughout the homeowner app.
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
    this.borderColor = const Color(0xFFD9E2EC),
    this.showShadow = false,
    this.textColor = AppTheme.navy700,
  }) : assert(hint == null || emptyOverlay == null);

  static const double height = 56;
  static const double _leftInset = 48;

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
  final Color borderColor;
  final bool showShadow;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final isEmpty = controller.text.trim().isEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final iconButtonWidth = compact ? 32.0 : 36.0;
        final submitSize = compact ? 36.0 : 40.0;
        final actionPadding = compact ? 6.0 : 8.0;

        return Container(
          width: double.infinity,
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: borderColor),
            boxShadow: showShadow
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
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
                      onTapOutside: onTapOutside,
                      onChanged: onChanged,
                      onSubmitted: (_) => onSubmit(),
                      cursorColor: AppTheme.navy700,
                      cursorHeight: 16,
                      maxLines: 1,
                      textAlignVertical: const TextAlignVertical(y: -0.08),
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(left: 14),
                          child: Icon(
                            Icons.search_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                        ),
                        prefixIconConstraints:
                            BoxConstraints(minWidth: _leftInset),
                      ),
                    ),
                    if (isEmpty && (hint != null || emptyOverlay != null))
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
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF64748B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    height: 1,
                                  ),
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _ActionButton(
                width: iconButtonWidth,
                tooltip: 'Describe with a photo',
                icon: Icons.camera_alt_outlined,
                onPressed: onPhotoTap,
              ),
              _ActionButton(
                width: iconButtonWidth,
                tooltip: 'Describe with voice',
                icon: Icons.mic_none_rounded,
                onPressed: onVoiceTap,
              ),
              Container(
                height: 20,
                width: 1,
                margin: EdgeInsets.symmetric(horizontal: compact ? 3 : 5),
                color: const Color(0xFFCBD5E1),
              ),
              Padding(
                padding: EdgeInsets.only(right: actionPadding),
                child: Semantics(
                  button: true,
                  label: 'Search',
                  child: Material(
                    color: AppTheme.orange500,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onSubmit,
                      child: SizedBox(
                        width: submitSize,
                        height: submitSize,
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
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
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.width,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final double width;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: ServiceSearchBar.height,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      ),
    );
  }
}
