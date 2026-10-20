/// US account phone numbers are stored in E.164; formatting is display-only.
String? usPhoneE164(String input) {
  final text = input.trim();
  if (RegExp(r'[^0-9+().\s-]').hasMatch(text)) return null;
  var digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('1'))
    digits = digits.substring(1);
  if (text.startsWith('+') && !text.startsWith('+1')) return null;
  if (!RegExp(r'^[2-9]\d{2}[2-9]\d{6}$').hasMatch(digits)) return null;
  return '+1$digits';
}

String formatUsPhone(String input) {
  final number = usPhoneE164(input);
  if (number == null) return input;
  final digits = number.substring(2);
  return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
}
