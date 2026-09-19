import 'package:flutter/material.dart';

import '../theme.dart';

/// The single ZIP-entry surface used wherever a homeowner changes the service
/// area. Keeping validation and visual treatment here prevents Home and Browse
/// from drifting into different location flows.
Future<String?> showServiceZipEntryDialog(
  BuildContext context, {
  required String initialZip,
}) {
  return showDialog<String>(
    context: context,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter ZIP code',
              style: TextStyle(
                color: AppTheme.navy700,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              maxLength: 5,
              decoration: InputDecoration(
                hintText: '5-digit ZIP code',
                prefixIcon: const Icon(
                  Icons.location_on_outlined,
                  color: AppTheme.orange500,
                ),
                errorText: _errorText,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE6E8EC)),
                ),
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            const Text(
              'This ZIP is used only for your current browsing session.',
              style: TextStyle(
                color: AppTheme.gray,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.orange500,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
