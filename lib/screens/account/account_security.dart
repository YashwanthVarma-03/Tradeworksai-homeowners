import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/homeowner_service.dart';
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
                title: const Text('Delete account'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                      'Available credits: ${preflight['serviceCredits'] ?? 0}. Remaining credits will be forfeited. Reviews will be anonymized. Download your invoices and documents before continuing.'),
                  const SizedBox(height: 16),
                  TextField(
                      controller: confirmation,
                      decoration: const InputDecoration(
                          labelText: 'Type CLOSE to confirm')),
                  TextField(
                      controller: password,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                          labelText: 'Current password (password accounts)')),
                  const Text(
                      'Apple and Google accounts may need a recent sign-in.'),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep account')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
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
                title: const Text('Deletion requested'),
                content: Text(
                    'Reference: ${closure['requestReference'] ?? closure['request_reference'] ?? 'Received'}. Your request is pending processing; your account has not yet been deleted.'),
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
        appBar: AppBar(title: const Text('Account security')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Change password',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('For accounts that sign in with a password.'),
          for (final field in [
            (_current, 'Current password'),
            (_password, 'New password'),
            (_confirm, 'Confirm new password')
          ])
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextField(
                    controller: field.$1,
                    enabled: !_busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(labelText: field.$2))),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _busy ? null : _changePassword,
              child: const Text('Change password')),
          const SizedBox(height: 40),
          const Text('Delete account',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text(
              'Review active bookings, credits and documents before requesting deletion.'),
          OutlinedButton(
              onPressed: _busy ? null : _closeAccount,
              child: const Text('Review account deletion')),
          if (_busy) const Center(child: CircularProgressIndicator()),
        ]),
      ));
}
