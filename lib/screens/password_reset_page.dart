import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../ui/tw.dart';
import '../widgets/app_notification.dart';

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _requestFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController.text =
        AuthService.instance.pendingPasswordResetEmail ?? '';
    _tabController = TabController(
        length: 2,
        vsync: this,
        initialIndex: AuthService.instance.isPasswordRecovery ? 1 : 0)
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (_isLoading || !_requestFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final message = await AuthService.instance.requestPasswordReset(
        _emailController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.green),
      );
      _tabController.animateTo(1);
    } catch (error) {
      if (mounted) {
        AppNotification.showError(
          context,
          error,
          fallback: 'We couldn\'t send a reset link. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitReset() async {
    if (_isLoading || !_resetFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final message = await AuthService.instance.performPasswordReset(
        token: _tokenController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.green),
      );
      if (Navigator.canPop(context)) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        AppNotification.showError(
          context,
          error,
          fallback: 'We couldn\'t reset your password. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_isLoading &&
            _tabController.index == 0 &&
            !AuthService.instance.showPasswordRecovery,
        onPopInvoked: (didPop) {
          if (didPop) return;
          if (_isLoading) {
            AppNotification.showInfo(
              context,
              'Please wait while your password request is being completed.',
            );
          } else if (AuthService.instance.showPasswordRecovery) {
            AuthService.instance.logout();
          } else {
            _tabController.animateTo(0);
          }
        },
        child: Scaffold(
          backgroundColor: AppTheme.pageBackground,
          // maybePop so the PopScope above still decides (Set password goes
          // back to Request link; nothing happens while a request runs).
          appBar: TwAppBar(
            title: 'Reset password',
            onBack: () => Navigator.maybePop(context),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TwUnderlineTabs(
                  labels: const ['Request link', 'Set password'],
                  index: _tabController.index,
                  onChanged: (index) => _tabController.animateTo(index),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _requestPanel(),
                      _resetPanel(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _requestPanel() => SingleChildScrollView(
        child: TwPage(
          top: 24,
          child: Form(
            key: _requestFormKey,
            child: _Panel(
              children: [
                Text('Request reset link', style: TwType.h2()),
                const SizedBox(height: 6),
                Text(
                  'Enter your email address. Open the reset link on this device to choose a new password.',
                  style: TwType.bodySm(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                if (AuthService.instance.passwordRecoveryError != null) ...[
                  Text(AuthService.instance.passwordRecoveryError!,
                      style: TwType.bodySm(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                ],
                const TwFieldLabel('Email address'),
                TextFormField(
                  controller: _emailController,
                  style: TwType.body(color: AppTheme.navy),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                  decoration: TwInputs.decoration(hint: 'you@example.com'),
                  validator: (value) => !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(value?.trim() ?? '')
                      ? 'Please enter a valid email address'
                      : null,
                ),
                const SizedBox(height: TwSpace.s28),
                TwPrimaryButton(
                  label: 'Send reset link',
                  onPressed: _submitRequest,
                  loading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _resetPanel() => SingleChildScrollView(
        child: TwPage(
          top: 24,
          child: Form(
            key: _resetFormKey,
            child: _Panel(
              children: [
                Text('Set new password', style: TwType.h2()),
                const SizedBox(height: 6),
                Text(
                  AuthService.instance.isPasswordRecovery
                      ? 'Your reset link is verified. Choose a new password for your account.'
                      : 'Open the reset link on this device. If your email includes a verification code, you can enter that code below instead.',
                  style: TwType.bodySm(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                if (!AuthService.instance.isPasswordRecovery) ...[
                  const TwFieldLabel('Email verification code'),
                  TextFormField(
                    controller: _tokenController,
                    style: TwType.body(color: AppTheme.navy),
                    enabled: !_isLoading,
                    keyboardType: TextInputType.number,
                    decoration: TwInputs.decoration(
                        hint: 'Code from your email, if provided'),
                    validator: (value) => !RegExp(r'^\d{6,10}$')
                            .hasMatch(value?.trim() ?? '')
                        ? 'Open your reset link, or enter the email verification code'
                        : null,
                  ),
                  const SizedBox(height: 18),
                ],
                const TwFieldLabel('New password'),
                TextFormField(
                  controller: _passwordController,
                  style: TwType.body(color: AppTheme.navy),
                  obscureText: true,
                  enabled: !_isLoading,
                  decoration:
                      TwInputs.decoration(hint: 'At least 8 characters'),
                  validator: (value) => value == null || value.length < 8
                      ? 'Password must be at least 8 characters'
                      : null,
                ),
                const SizedBox(height: TwSpace.s28),
                const TwFieldLabel('Confirm new password'),
                TextFormField(
                  controller: _confirmController,
                  style: TwType.body(color: AppTheme.navy),
                  obscureText: true,
                  enabled: !_isLoading,
                  decoration:
                      TwInputs.decoration(hint: 'Enter the new password again'),
                  validator: (value) => value != _passwordController.text
                      ? 'Passwords do not match'
                      : null,
                ),
                const SizedBox(height: TwSpace.s28),
                TwPrimaryButton(
                  label: 'Update password',
                  onPressed: _submitReset,
                  loading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  // B07: hairline card, radius 14, padding 24 × 20.
  @override
  Widget build(BuildContext context) => TwCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
}
