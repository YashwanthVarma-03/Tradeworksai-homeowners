import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../ui/tw.dart';
import '../../widgets/app_notification.dart';
import '../../widgets/transaction_guard.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});
  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_busy) return;
    if (_current.text.isEmpty ||
        _password.text.length < 8 ||
        _password.text != _confirm.text) {
      AppNotification.showInfo(context,
          'Enter your current password and matching new passwords of at least 8 characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await HomeownerService.instance
          .changeAccountPassword(_current.text, _password.text);
      _current.clear();
      _password.clear();
      _confirm.clear();
      if (mounted)
        AppNotification.showInfo(
            context,
            result['otherSessionsSignedOut'] == true
                ? 'Password changed. Other sessions have been signed out.'
                : 'Password changed, but other sessions could not be signed out. Contact support.');
    } catch (e) {
      if (mounted) AppNotification.showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closeAccount() async {
    if (_busy) return;
    setState(() => _busy = true);
    final confirmation = TextEditingController();
    final password = TextEditingController();
    try {
      final data = await HomeownerService.instance.accountClosurePreflight();
      final preflight = data['preflight'] as Map;
      if (!mounted) return;
      if (preflight['canClose'] != true) {
        AppNotification.showInfo(context,
            'Finish or cancel your ${preflight['activeJobCount']} active bookings before closing your account.');
        return;
      }
      final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text('Delete account', style: TwType.h3()),
                content: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Text(
                          'Available credits: ${preflight['serviceCredits'] ?? 0}. Remaining credits will be forfeited. Reviews will be anonymized. Download your invoices and documents before continuing.',
                          style: TwType.bodySm()),
                      const SizedBox(height: TwSpace.s16),
                      const TwFieldLabel('Type CLOSE to confirm'),
                      TextField(
                          controller: confirmation,
                          style: TwType.body(color: AppTheme.navy),
                          decoration: TwInputs.decoration()),
                      const SizedBox(height: TwSpace.s16),
                      const TwFieldLabel('Current password (password accounts)'),
                      TextField(
                          controller: password,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: TwType.body(color: AppTheme.navy),
                          decoration: TwInputs.decoration()),
                      const SizedBox(height: TwSpace.s8),
                      Text(
                          'Apple and Google accounts may need a recent sign-in.',
                          style: TwType.caption()),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.navy),
                      child: const Text('Keep account')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.red),
                      child: const Text('Request deletion'))
                ],
              ));
      if (approved != true) return;
      if (confirmation.text != 'CLOSE')
        throw Exception('Type CLOSE exactly to request account closure.');
      final result = await HomeownerService.instance
          .requestAccountClosure(confirmation.text, password.text);
      final closure = result['closure'] as Map?;
      if (closure == null)
        throw Exception('The closure request was not confirmed.');
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
                title: Text('Deletion requested', style: TwType.h3()),
                content: Text(
                    'Reference: ${closure['requestReference'] ?? closure['request_reference'] ?? 'Received'}. Your request is pending processing; your account has not yet been deleted.',
                    style: TwType.bodySm()),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Sign out'))
                ],
              ));
      await AuthService.instance.logout();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) AppNotification.showError(context, e);
    } finally {
      // Dialog route animations can still reference these controllers briefly.
      Future.delayed(const Duration(seconds: 1), () {
        confirmation.dispose();
        password.dispose();
      });
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TransactionGuard(
      isProcessing: _busy,
      child: Scaffold(
        backgroundColor: AppTheme.white,
        appBar: TwAppBar(title: 'Account security'),
        body: ListView(padding: EdgeInsets.zero, children: [
          TwPage(
            top: TwSpace.s20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Change password', style: TwType.h2()),
                const SizedBox(height: TwSpace.s4),
                Text(
                  'For accounts that sign in with a password. Changing it signs '
                  'you out on your other devices.',
                  style: TwType.bodySm(),
                ),
                for (final field in [
                  (_current, 'Current password', null),
                  (_password, 'New password', 'At least 8 characters'),
                  (_confirm, 'Confirm new password', null),
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: TwSpace.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TwFieldLabel(field.$2),
                        TextField(
                            controller: field.$1,
                            enabled: !_busy,
                            obscureText: true,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: TwType.body(color: AppTheme.navy),
                            decoration: TwInputs.decoration()),
                        if (field.$3 != null) ...[
                          const SizedBox(height: TwSpace.s8),
                          Text(field.$3!, style: TwType.caption()),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: TwSpace.s20),
                TwPrimaryButton(
                  label: 'Change password',
                  onPressed: _busy ? null : _changePassword,
                ),
                const SizedBox(height: TwSpace.s28),
                const Divider(height: 1, color: AppTheme.cardBorder),
                const SizedBox(height: TwSpace.s28),
                Text('Delete account', style: TwType.h2()),
                const SizedBox(height: TwSpace.s4),
                Text(
                    'Review active bookings, credits and documents before requesting deletion.',
                    style: TwType.bodySm()),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _closeAccount,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Review account deletion'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.red,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      textStyle: TwType.link(),
                    ),
                  ),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: TwSpace.s16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.navy),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ));
}
