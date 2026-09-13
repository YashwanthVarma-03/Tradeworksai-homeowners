import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/app_notification.dart';
import 'dashboard_shell.dart';
import 'password_reset_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false, _obscure = true;
  bool _googleOAuthPending = false;

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_completeGoogleOAuthIfReady);
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_completeGoogleOAuthIfReady);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _completeGoogleOAuthIfReady() {
    if (!mounted || !_googleOAuthPending || !AuthService.instance.isAuthenticated) {
      return;
    }
    _googleOAuthPending = false;
    if (_loading) setState(() => _loading = false);
    _openDashboard();
  }

  void _openDashboard() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
        context, createPremiumRoute(const DashboardShell()), (_) => false);
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance
          .login(email: _email.text.trim(), password: _password.text);
      _openDashboard();
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    if (_loading) return;
    setState(() => _loading = true);
    _googleOAuthPending = true;
    try {
      await AuthService.instance.signInWithGoogleInteractive();
      // On mobile, the OAuth callback arrives after the external browser
      // redirects to the app. Navigate only after Supabase creates a session.
      _completeGoogleOAuthIfReady();
    } catch (e) {
      _googleOAuthPending = false;
      if (mounted) _showError(e);
    } finally {
      if (mounted && !AuthService.instance.isAuthenticated) {
        setState(() => _loading = false);
      }
    }
  }

  void _showError(Object e) => AppNotification.showError(
        context,
        e,
        fallback: 'We couldn\'t sign you in. Check your details and try again.',
      );

  InputDecoration _field(String hint, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD9E2EC))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD9E2EC))),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Form(
              key: _formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Welcome back',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.navy700,
                            fontWeight: FontWeight.w900,
                            fontSize: 30)),
                    const SizedBox(height: 6),
                    const Text('Log in to manage your home and bookings.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Color(0xFF64748B), fontSize: 15)),
                    const SizedBox(height: 34),
                    const Text('Email address',
                        style: TextStyle(color: AppTheme.ink, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_loading,
                        decoration: _field('you@example.com'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Please enter your email'
                            : null),
                    const SizedBox(height: 18),
                    const Text('Password',
                        style: TextStyle(color: AppTheme.ink, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        enabled: !_loading,
                        decoration: _field('••••••••',
                            suffix: IconButton(
                                icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: const Color(0xFF64748B)),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure))),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please enter your password'
                            : null),
                    Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const PasswordResetPage())),
                            child: const Text('Forgot password?',
                                style: TextStyle(color: AppTheme.orange500)))),
                    const SizedBox(height: 4),
                    SizedBox(
                        height: 54,
                        child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.orange500,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14))),
                            child: _loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('Log in',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15)))),
                    const SizedBox(height: 22),
                    const Row(children: [
                      Expanded(child: Divider()),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('or',
                              style: TextStyle(color: Color(0xFF64748B)))),
                      Expanded(child: Divider())
                    ]),
                    const SizedBox(height: 22),
                    SizedBox(
                        height: 54,
                        child: OutlinedButton.icon(
                            onPressed: _loading ? null : _google,
                            icon: const Text('G',
                                style: TextStyle(
                                    color: AppTheme.teal500,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900)),
                            label: const Text('Continue with Google',
                                style: TextStyle(
                                    color: AppTheme.navy700,
                                    fontWeight: FontWeight.w800)),
                            style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                side: const BorderSide(
                                    color: Color(0xFFD9E2EC))))),
                    const SizedBox(height: 80),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('Don’t have an account? ',
                          style: TextStyle(color: Color(0xFF64748B))),
                      InkWell(
                          onTap: _loading
                              ? null
                              : () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const SignupPage())),
                          child: const Text('Sign up',
                              style: TextStyle(
                                  color: AppTheme.orange500,
                                  fontWeight: FontWeight.w900)))
                    ]),
                  ])),
        ))),
      );
}
