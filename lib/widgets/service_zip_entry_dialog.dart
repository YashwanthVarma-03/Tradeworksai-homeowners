import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../ui/tw.dart';

/// The single ZIP-entry surface used wherever a homeowner changes the service
/// area. Keeping validation and visual treatment here prevents Home and Browse
/// from drifting into different location flows.
///
/// v3.3 (A07): a centred card, radius 20, 24 from the screen edges, Outfit
/// 22/700 title, a 48-high white field with an outline pin, a 13px helper
/// line, then Cancel (secondary) and Save (orange, navy label) side by side.
Future<String?> showServiceZipEntryDialog(
  BuildContext context, {
  required String initialZip,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: AppTheme.scrim,
    builder: (_) => _ServiceZipEntryDialog(initialZip: initialZip),
  );
}

class _ServiceZipEntryDialog extends StatefulWidget {
  const _ServiceZipEntryDialog({required this.initialZip});

  final String initialZip;

  @override
  State<_ServiceZipEntryDialog> createState() => _ServiceZipEntryDialogState();
}

class _ServiceZipEntryDialogState extends State<_ServiceZipEntryDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialZip);
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final digits = _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 5) {
      setState(() => _errorText = 'Enter a valid 5-digit ZIP code');
      return;
    }
    Navigator.of(context).pop(digits);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter ZIP code',
                style: TwType.sheetTitle(),
              ),
              const SizedBox(height: TwSpace.s16),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [LengthLimitingTextInputFormatter(5)],
                style: TwType.body(color: AppTheme.navy),
                cursorColor: AppTheme.navy,
                decoration: TwInputs.decoration(
                  hint: '5-digit ZIP code',
                  errorText: _errorText,
                  restBorder: AppTheme.border,
                  fillColor: AppTheme.white,
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 10),
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: AppTheme.navy,
                    ),
                  ),
                  prefixConstraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                },
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: TwSpace.s8),
              Text(
                'This ZIP is used only for your current browsing session.',
                style: TwType.caption().copyWith(height: 19 / 13),
              ),
              const SizedBox(height: TwSpace.s20),
              Row(
                children: [
                  Expanded(
                    child: TwSecondaryButton(
                      label: 'Cancel',
                      height: 52,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: TwSpace.s12),
                  Expanded(
                    child: TwPrimaryButton(
                      label: 'Save',
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
