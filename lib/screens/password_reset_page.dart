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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
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
      Navigator.pop(context);
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
        canPop: !_isLoading && _tabController.index == 0,
        onPopInvoked: (didPop) {
          if (didPop) return;
          if (_isLoading) {
            AppNotification.showInfo(
              context,
              'Please wait while your password request is being completed.',
            );
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
                  'Enter your email address and we’ll send you a secure link carrying your reset token.',
                  style: TwType.bodySm(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                const TwFieldLabel('Email address'),
                TextFormField(
                  controller: _emailController,
                  style: TwType.body(color: AppTheme.navy),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                  decoration: TwInputs.decoration(hint: 'you@example.com'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter your email'
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
                  'Enter the token from your email and choose a new password.',
                  style: TwType.bodySm(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                const TwFieldLabel('Reset token'),
                TextFormField(
                  controller: _tokenController,
                  style: TwType.body(color: AppTheme.navy),
                  enabled: !_isLoading,
                  decoration:
                      TwInputs.decoration(hint: 'Paste token from email link'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter your reset token'
                      : null,
                ),
                const SizedBox(height: 18),
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
