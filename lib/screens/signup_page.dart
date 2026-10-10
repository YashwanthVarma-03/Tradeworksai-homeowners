import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../ui/tw.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/app_notification.dart';
import '../widgets/transaction_guard.dart';
import 'dashboard_shell.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  final bool returnToPreviousPage;

  const SignupPage({
    super.key,
    this.returnToPreviousPage = false,
  });
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false, _obscure = true;
  bool _socialOAuthPending = false;

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_completeSocialOAuthIfReady);
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_completeSocialOAuthIfReady);
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _completeSocialOAuthIfReady() {
    if (!mounted ||
        !_socialOAuthPending ||
        !AuthService.instance.isAuthenticated) {
      return;
    }
    _socialOAuthPending = false;
    if (_loading) setState(() => _loading = false);
    _completeSignupNavigation();
  }

  void _completeSignupNavigation() {
    if (!mounted) return;
    if (widget.returnToPreviousPage) {
      if (_loading) setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
      return;
    }
    Navigator.pushAndRemoveUntil(
        context, createPremiumRoute(const DashboardShell()), (_) => false);
  }

  void _openLogin() {
    if (widget.returnToPreviousPage) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    try {
      final opened = await launchUrl(
        Uri.parse('https://www.tradeworksai.com/privacy-policy/'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Could not open the Privacy Policy.');
    } catch (error) {
      if (mounted) AppNotification.showError(context, error);
    }
  }

  Future<void> _openTermsOfService() async {
    try {
      final opened = await launchUrl(
        Uri.parse('https://www.tradeworksai.com/terms/'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Could not open the Terms of Service.');
    } catch (error) {
      if (mounted) AppNotification.showError(context, error);
    }
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.signUp(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text);
      // The old required onboarding/profile setup is intentionally removed.
      _completeSignupNavigation();
    } on SignUpConfirmationRequired {
      if (mounted) {
        AppNotification.showInfo(
          context,
          'Account created — check your email to confirm before signing in.',
        );
      }
    } catch (e) {
      if (mounted) _error(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    if (_loading) return;
    setState(() => _loading = true);
    _socialOAuthPending = true;
    try {
      await AuthService.instance.signInWithGoogleInteractive();
      _completeSocialOAuthIfReady();
    } catch (e) {
      _socialOAuthPending = false;
      if (mounted) _error(e);
    } finally {
      if (mounted && !AuthService.instance.isAuthenticated) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _apple() async {
    if (_loading) return;
    setState(() => _loading = true);
    _socialOAuthPending = true;
    try {
      await AuthService.instance.signInWithAppleInteractive();
      _completeSocialOAuthIfReady();
    } catch (e) {
      _socialOAuthPending = false;
      if (mounted) _error(e);
    } finally {
      if (mounted && !AuthService.instance.isAuthenticated) {
        setState(() => _loading = false);
      }
    }
  }

  void _error(Object e) => AppNotification.showError(
        context,
        e,
        fallback: 'We couldn\'t create your account. Please try again.',
      );
  @override
  Widget build(BuildContext context) => TransactionGuard(
      isProcessing: _loading,
      blockedMessage: 'Please wait while your account is being created.',
      child: Scaffold(
          backgroundColor: AppTheme.pageBackground,
          appBar: authBackBar(context),
          body: SafeArea(
              child: SingleChildScrollView(
                  child: TwPage(
                      top: TwSpace.s8,
                      child: Form(
                          key: _formKey,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Create your account',
                                    textAlign: TextAlign.center,
                                    style: TwType.h1(context)),
                                const SizedBox(height: 6),
                                Text(
                                    'Book trusted local pros and keep every job in one place.',
                                    textAlign: TextAlign.center,
                                    style: TwType.body(
                                        color: AppTheme.textSecondary)),
                                const SizedBox(height: 24),
                                const TwFieldLabel('Full name'),
                                TextFormField(
                                    controller: _name,
                                    style: TwType.body(color: AppTheme.navy),
                                    enabled: !_loading,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration:
                                        TwInputs.decoration(hint: 'Your name'),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                            ? 'Please enter your name'
                                            : null),
                                const SizedBox(height: TwSpace.s16),
                                const TwFieldLabel('Email address'),
                                TextFormField(
                                    controller: _email,
                                    style: TwType.body(color: AppTheme.navy),
                                    enabled: !_loading,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: TwInputs.decoration(
                                        hint: 'you@example.com'),
                                    validator: (v) => v == null ||
                                            !RegExp(r'^[\w.+-]+@([\w-]+\.)+[a-zA-Z]{2,}$')
                                                .hasMatch(v.trim())
                                        ? 'Please enter a valid email'
                                        : null),
                                const SizedBox(height: TwSpace.s16),
                                const TwFieldLabel('Password'),
                                TextFormField(
                                    controller: _password,
                                    style: TwType.body(color: AppTheme.navy),
                                    enabled: !_loading,
                                    obscureText: _obscure,
                                    decoration: TwInputs.decoration(
                                        hint: '8+ characters',
                                        suffix: IconButton(
                                            tooltip: _obscure
                                                ? 'Show password'
                                                : 'Hide password',
                                            icon: Icon(
                                                _obscure
                                                    ? Icons
                                                        .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                size: 20,
                                                color: AppTheme.textSecondary),
                                            onPressed: () => setState(
                                                () => _obscure = !_obscure))),
                                    validator: (v) => v == null || v.length < 8
                                        ? 'Password must be at least 8 characters'
                                        : null),
                                const SizedBox(height: TwSpace.s8),
                                // Wraps onto two lines on Compact or at large
                                // text sizes (was a FittedBox that shrank it).
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: TwSpace.s8,
                                  children: [
                                    TwTextAction(
                                      label: 'Terms of Service',
                                      onPressed: () {
                                        if (!_loading) _openTermsOfService();
                                      },
                                    ),
                                    Text('·', style: TwType.meta()),
                                    TwTextAction(
                                      label: 'Read our Privacy Policy',
                                      onPressed: () {
                                        if (!_loading) _openPrivacyPolicy();
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: TwSpace.s8),
                                TwPrimaryButton(
                                  label: 'Create account',
                                  onPressed: _submit,
                                  loading: _loading,
                                ),
                                const SizedBox(height: TwSpace.s20),
                                const AuthOrDivider(),
                                const SizedBox(height: TwSpace.s20),
                                AuthSocialButton(
                                  label: 'Continue with Apple',
                                  icon: const Icon(Icons.apple,
                                      color: AppTheme.navy, size: 22),
                                  onPressed: _loading ? null : _apple,
                                ),
                                const SizedBox(height: TwSpace.s12),
                                AuthSocialButton(
                                  label: 'Continue with Google',
                                  icon: const GoogleMark(),
                                  onPressed: _loading ? null : _google,
                                ),
                                const SizedBox(height: TwSpace.s28),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text('Already have an account? ',
                                        style: TwType.bodySm(
                                            color: AppTheme.textSecondary)),
                                    TwTextAction(
                                      label: 'Log in',
                                      onPressed: () {
                                        if (!_loading) _openLogin();
                                      },
                                    ),
                                  ],
                                ),
                              ])))))));
}
