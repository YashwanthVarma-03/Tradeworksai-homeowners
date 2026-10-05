import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
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

  InputDecoration _field(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppTheme.subtle,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      );

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
          appBar: AppBar(
            title: const Text(
              'Reset password',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            centerTitle: true,
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppTheme.blue,
              unselectedLabelColor: AppTheme.body,
              indicatorColor: AppTheme.blue,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(text: 'Request link'),
                Tab(text: 'Set password'),
              ],
            ),
          ),
          body: SafeArea(
            child: TabBarView(
              controller: _tabController,
              children: [
                _requestPanel(),
                _resetPanel(),
              ],
            ),
          ),
        ),
      );

  Widget _requestPanel() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Form(
          key: _requestFormKey,
          child: _Panel(
            children: [
              Text('Request reset link',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                'Enter your email address and we’ll send you a secure link carrying your reset token.',
                style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
              ),
              const SizedBox(height: 26),
              const _FieldLabel('Email address'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
                decoration: _field('you@example.com'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter your email'
                    : null,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send reset link'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _resetPanel() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Form(
          key: _resetFormKey,
          child: _Panel(
            children: [
              Text('Set new password',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                'Enter the token from your email and choose a new password.',
                style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
              ),
              const SizedBox(height: 26),
              const _FieldLabel('Reset token'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tokenController,
                enabled: !_isLoading,
                decoration: _field('Paste token from email link'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter your reset token'
                    : null,
              ),
              const SizedBox(height: 18),
              const _FieldLabel('New password'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                enabled: !_isLoading,
                decoration: _field('At least 8 characters'),
                validator: (value) => value == null || value.length < 8
                    ? 'Password must be at least 8 characters'
                    : null,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitReset,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update password'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppTheme.navy,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      );
}
